/**
 * Conservative integrity checks for ledgers that influence host mutation
 * authority. This is intentionally narrower than workflow-event's complete
 * schema validator: a guard must fail closed before it decides whether a
 * ledger can be ignored or selected as active.
 */
import { lstatSync, readdirSync, readFileSync, statSync } from "node:fs";
import { isObject, isNonEmptyString, isStringArray } from "./predicates.mjs";
import { basename, join, relative, resolve, sep } from "node:path";
import { WORKFLOW_EVENTS } from "./workflow-events.mjs";

export const ACTIVE_RUN_POINTER = "active-run.json";

/**
 * Stat-keyed caches. selectActiveLedger runs on every tool_result and the
 * ledger set is almost always unchanged between consecutive calls, so
 * re-reading and re-parsing every journal is wasted work. Results are keyed
 * by file identity + size + mtimeNs + ctimeNs (bigint stats): any append,
 * rewrite, chmod, or replacement yields a new key and forces a fresh parse.
 * Event watchers cannot replace this revalidation: the API is synchronous, so
 * a watch event that has not been delivered yet must never mask a change that
 * is already visible on disk.
 */
const CACHE_LIMIT = 4096;
const ROOT_CACHE_LIMIT = 256;
const ledgerCache = new Map(); // ledger path -> { fp, value } (parsed ledger result)
const scanCache = new Map(); // workflow root -> Map<run name, { fp, path, record }>

/** File fingerprint: identity + size + mtime + ctime (ns, bigint stats). */
function fingerprint(stat) {
  return {
    dev: stat.dev,
    ino: stat.ino,
    size: stat.size,
    mtimeNs: stat.mtimeNs,
    ctimeNs: stat.ctimeNs,
  };
}

function sameFingerprint(a, b) {
  return (
    a.dev === b.dev &&
    a.ino === b.ino &&
    a.size === b.size &&
    a.mtimeNs === b.mtimeNs &&
    a.ctimeNs === b.ctimeNs
  );
}

function cacheLookup(cache, path, fp) {
  const cached = cache.get(path);
  return cached !== undefined && sameFingerprint(cached.fp, fp)
    ? cached.value
    : undefined;
}

function cacheStore(cache, path, fp, value) {
  if (cache.size >= CACHE_LIMIT) cache.clear();
  cache.set(path, { fp, value });
}

const TERMINAL_EVENTS = new Set(["completed", "blocked"]);
const RUN_SLUG_PATTERN = /^[a-z0-9][a-z0-9_-]*$/;
const KNOWN_EVENTS = new Set(WORKFLOW_EVENTS);

function isIsoTimestamp(value) {
  return (
    typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value)
  );
}

function isValidRunSlug(value) {
  return typeof value === "string" && RUN_SLUG_PATTERN.test(value);
}

function isContainedPath(root, candidate) {
  const relativePath = relative(resolve(root), resolve(candidate));
  return (
    relativePath !== "" &&
    relativePath !== ".." &&
    !relativePath.startsWith(`..${sep}`) &&
    !relativePath.startsWith(sep)
  );
}

/**
 * Validate the event details that can change host authority. The full schema
 * remains owned by workflow-event; these fields prevent a malformed v2
 * terminal, failure, or reset event from reopening a stopped run.
 */
function hasAuthorityDetailShape(event) {
  const detail = event.detail;
  if (event.event === "completed") return isNonEmptyString(detail.summary);
  if (event.event === "blocked") {
    return (
      isNonEmptyString(detail.reason) && isNonEmptyString(detail.needed_input)
    );
  }
  if (event.event === "no_progress") {
    return (
      isNonEmptyString(detail.check_or_hypothesis) &&
      isNonEmptyString(detail.command) &&
      Number.isInteger(detail.attempts) &&
      detail.attempts > 0 &&
      isStringArray(detail.eliminated)
    );
  }
  if (event.event === "validation_failed") {
    return (
      isNonEmptyString(detail.command) &&
      isNonEmptyString(detail.failure) &&
      Number.isInteger(detail.exit) &&
      detail.exit > 0
    );
  }
  if (event.event === "file_changed") {
    return isNonEmptyString(detail.path) && isNonEmptyString(detail.change);
  }
  return true;
}

function invalid(reason, events = [], extra = {}) {
  return { valid: false, reason, events, terminal: false, ...extra };
}

/**
 * Sequential scan state for one ledger. The per-line rules are order-
 * dependent (timestamp monotonicity, terminal finality), so an append-only
 * growth of the file can resume from a cached state instead of re-parsing
 * the whole journal: after every workflow-event append, selectActiveLedger
 * re-inspects the pointed ledger, and the prefix is provably unchanged
 * (byte compare) while only the tail is new.
 */
function freshScanState() {
  return {
    events: [],
    lineCount: 0,
    previousTimestamp: "",
    terminalIndex: -1,
    terminalWasV2: false,
    legacyPostTerminal: false,
    error: null,
  };
}

/** Scan one chunk of jsonl text into the state (first failure sticks). */
function scanLedgerChunk(state, chunk, expectedRun) {
  const lines = chunk.split("\n").filter((line) => line.trim() !== "");
  for (const [index, line] of lines.entries()) {
    const lineNumber = state.lineCount + index + 1;
    let event;
    try {
      event = JSON.parse(line);
    } catch {
      state.error = invalid("invalid_json", state.events, { line: lineNumber });
      return;
    }
    if (!isObject(event)) {
      state.error = invalid("invalid_event_object", state.events, {
        line: lineNumber,
      });
      return;
    }
    if (!isNonEmptyString(event.event) || !KNOWN_EVENTS.has(event.event)) {
      state.error = invalid("unknown_event", state.events, {
        line: lineNumber,
      });
      return;
    }
    if (!isObject(event.detail)) {
      state.error = invalid("invalid_event_detail", state.events, {
        line: lineNumber,
      });
      return;
    }

    const isV2 = event.schema_version === 2;
    if (isV2 && !hasAuthorityDetailShape(event)) {
      state.error = invalid("invalid_authority_detail", state.events, {
        line: lineNumber,
      });
      return;
    }
    if (
      event.schema_version !== undefined &&
      event.schema_version !== 1 &&
      !isV2
    ) {
      state.error = invalid("unsupported_schema_version", state.events, {
        line: lineNumber,
      });
      return;
    }
    if (isNonEmptyString(event.run) && event.run !== expectedRun) {
      state.error = invalid("run_mismatch", state.events, { line: lineNumber });
      return;
    }
    if (isV2) {
      if (event.run !== expectedRun) {
        state.error = invalid("missing_or_misbound_run", state.events, {
          line: lineNumber,
        });
        return;
      }
      if (!isIsoTimestamp(event.ts)) {
        state.error = invalid("invalid_timestamp", state.events, {
          line: lineNumber,
        });
        return;
      }
      if (
        state.previousTimestamp !== "" &&
        event.ts < state.previousTimestamp
      ) {
        state.error = invalid("timestamp_moved_backwards", state.events, {
          line: lineNumber,
        });
        return;
      }
      state.previousTimestamp = event.ts;
    }

    if (state.terminalIndex !== -1) {
      if (isV2 || state.terminalWasV2) {
        state.error = invalid("terminal_not_final", state.events, {
          line: lineNumber,
          terminalLine: state.terminalIndex + 1,
        });
        return;
      }
      state.legacyPostTerminal = true;
    }

    state.events.push(event);
    if (TERMINAL_EVENTS.has(event.event)) {
      state.terminalIndex = state.events.length - 1;
      state.terminalWasV2 = isV2;
    }
  }
  state.lineCount += lines.length;
}

function scanResult(state) {
  if (state.error !== null) return state.error;
  return {
    valid: true,
    reason: null,
    events: state.events,
    terminal: state.terminalIndex !== -1,
    terminalEvent:
      state.terminalIndex === -1
        ? null
        : state.events[state.terminalIndex].event,
    legacy: state.events.some((event) => event.schema_version !== 2),
    legacyPostTerminal: state.legacyPostTerminal,
  };
}

/** @param {string} ledgerPath @param {string} [expectedRun] */
export function inspectLedgerFile(
  ledgerPath,
  expectedRun = basename(join(ledgerPath, "..")),
) {
  if (!ledgerPath) return invalid("missing_ledger");
  let stat;
  try {
    stat = lstatSync(ledgerPath, { bigint: true, throwIfNoEntry: false });
  } catch {
    return invalid("missing_ledger");
  }
  if (stat === undefined) return invalid("missing_ledger");
  if (stat.isSymbolicLink()) return invalid("symlinked_ledger");
  try {
    const parent = lstatSync(join(ledgerPath, ".."), {
      bigint: true,
      throwIfNoEntry: false,
    });
    if (parent === undefined) return invalid("unreadable_ledger");
    if (parent.isSymbolicLink()) return invalid("symlinked_ledger");
  } catch {
    return invalid("unreadable_ledger");
  }
  return inspectLedgerStat(ledgerPath, expectedRun, stat);
}

/**
 * Append-resumable inspection shared by inspectLedgerFile and the root scan.
 * parseStates remembers the scan state of a fully line-terminated ledger
 * text; when the same file identity later grew and the previous text is a
 * byte-exact prefix of the new text, only the appended tail is parsed. Any
 * other change (shrink, rewrite, mid-line tail, different expectedRun, a
 * previous scan error) falls back to a full scan, so the result is always
 * identical to parsing the whole file. Guarded by the same cache limits as
 * the other caches; oversized journals simply always take the full path.
 */
const PARSE_STATE_CACHE_LIMIT = 2048;
const PARSE_STATE_MAX_BYTES = 1_000_000;
const parseStates = new Map(); // ledger path -> { dev, ino, expectedRun, text, state }

function inspectLedgerStat(ledgerPath, expectedRun, stat) {
  const key = fingerprint(stat);
  // Keyed by expectedRun too: the same path inspected under a different run
  // binding must never reuse a cached verdict (e.g. a pointer whose run
  // differs from the directory slug).
  const cacheKey = `${ledgerPath}\0${expectedRun}`;
  const cached = cacheLookup(ledgerCache, cacheKey, key);
  if (cached !== undefined) return cached;
  let text;
  try {
    text = readFileSync(ledgerPath, "utf8");
  } catch {
    return invalid("unreadable_ledger");
  }
  if (text.trim() === "") {
    parseStates.delete(ledgerPath);
    const empty = invalid("empty_ledger");
    cacheStore(ledgerCache, cacheKey, key, empty);
    return empty;
  }
  let result;
  const previous = parseStates.get(ledgerPath);
  const resumable =
    previous !== undefined &&
    previous.expectedRun === expectedRun &&
    previous.dev === stat.dev &&
    previous.ino === stat.ino &&
    text.length >= previous.text.length &&
    text.startsWith(previous.text);
  if (resumable) {
    // Scan a clone: the cached entry stays valid at its last line boundary.
    // A poisoned tail (parse error, or a not-yet-terminated final line) then
    // only affects this call's result, never a future resume.
    const state = { ...previous.state, events: previous.state.events.slice() };
    scanLedgerChunk(state, text.slice(previous.text.length), expectedRun);
    result = scanResult(state);
    if (state.error !== null) {
      parseStates.delete(ledgerPath);
    } else if (text.endsWith("\n") && text.length <= PARSE_STATE_MAX_BYTES) {
      previous.text = text;
      previous.state = state;
    }
  } else {
    const state = freshScanState();
    scanLedgerChunk(state, text, expectedRun);
    result = scanResult(state);
    if (
      result.valid &&
      text.endsWith("\n") &&
      text.length <= PARSE_STATE_MAX_BYTES
    ) {
      if (parseStates.size >= PARSE_STATE_CACHE_LIMIT) parseStates.clear();
      parseStates.set(ledgerPath, {
        dev: stat.dev,
        ino: stat.ino,
        expectedRun,
        text,
        state,
      });
    } else if (!result.valid) {
      parseStates.delete(ledgerPath);
    }
  }
  cacheStore(ledgerCache, cacheKey, key, result);
  return result;
}

function readPointer(root, absentFromEntries = false) {
  const pointerPath = join(root, ACTIVE_RUN_POINTER);
  if (absentFromEntries) return { state: "absent", path: pointerPath };
  let stat;
  try {
    stat = statSync(pointerPath, { bigint: true, throwIfNoEntry: false });
  } catch {
    return { state: "absent", path: pointerPath };
  }
  if (stat === undefined) return { state: "absent", path: pointerPath };
  // No fingerprint cache here: the pointer is tiny (~40B) and a deny/allow
  // decision must reflect the bytes on disk, not a stat that may lag a write.
  try {
    const parsed = JSON.parse(readFileSync(pointerPath, "utf8"));
    if (
      !isObject(parsed) ||
      parsed.schema_version !== 1 ||
      !isValidRunSlug(parsed.run)
    ) {
      return {
        state: "invalid",
        path: pointerPath,
        reason: "invalid_active_run_pointer",
      };
    }
    return { state: "present", path: pointerPath, run: parsed.run };
  } catch {
    return {
      state: "invalid",
      path: pointerPath,
      reason: "invalid_active_run_pointer",
    };
  }
}

export function getActiveRunPointer(cwd) {
  const root = join(cwd || process.cwd(), ".workflow");
  return readPointer(root);
}

/**
 * Collect all root ledgers with their integrity status. Invalid records are
 * deliberately retained so callers can fail closed instead of ignoring them.
 */
/**
 * Shared scan over a readdir result. Returns the records plus whether an
 * active-run.json entry exists (so callers can skip a pointer stat probe).
 * readdir Dirents prove each run directory is a real directory (symlinks
 * report as symlinks), so the parent-symlink lstat from inspectLedgerFile is
 * redundant on this path.
 */
function scanRootEntries(root, entries) {
  let scanRecords = scanCache.get(root);
  if (scanRecords === undefined) {
    if (scanCache.size >= ROOT_CACHE_LIMIT) scanCache.clear();
    scanRecords = new Map();
    scanCache.set(root, scanRecords);
  }

  const records = [];
  let pointerInEntries = false;
  for (const entry of entries) {
    if (entry.name === ACTIVE_RUN_POINTER) pointerInEntries = true;
    if (!entry.isDirectory() || entry.name.startsWith(".")) continue;
    const cached = scanRecords.get(entry.name);
    const path =
      cached === undefined
        ? join(root, entry.name, "events.jsonl")
        : cached.path;
    let stat;
    try {
      stat = lstatSync(path, { bigint: true, throwIfNoEntry: false });
    } catch {
      scanRecords.delete(entry.name);
      continue;
    }
    if (stat === undefined) {
      scanRecords.delete(entry.name);
      continue;
    }
    if (stat.isSymbolicLink()) {
      // A symlinked journal only counts as a record when its target exists
      // (matching existsSync semantics); it is retained as invalid so callers
      // fail closed instead of silently ignoring it.
      let resolves;
      try {
        resolves = statSync(path, { throwIfNoEntry: false }) !== undefined;
      } catch {
        resolves = false;
      }
      scanRecords.delete(entry.name);
      if (resolves) {
        records.push({ path, run: entry.name, ...invalid("symlinked_ledger") });
      }
      continue;
    }
    if (
      cached !== undefined &&
      cached.dev === stat.dev &&
      cached.ino === stat.ino &&
      cached.size === stat.size &&
      cached.mtimeNs === stat.mtimeNs &&
      cached.ctimeNs === stat.ctimeNs
    ) {
      records.push(cached.record);
      continue;
    }
    const result = inspectLedgerStat(path, entry.name, stat);
    const record = { path, run: entry.name, ...result };
    scanRecords.set(entry.name, {
      dev: stat.dev,
      ino: stat.ino,
      size: stat.size,
      mtimeNs: stat.mtimeNs,
      ctimeNs: stat.ctimeNs,
      path,
      record,
    });
    records.push(record);
  }
  return { records, pointerInEntries };
}

function inspectLedgerRoot(cwd) {
  const root = join(cwd || process.cwd(), ".workflow");
  let entries;
  try {
    entries = readdirSync(root, { withFileTypes: true });
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return {
        root,
        pointer: { state: "absent", path: join(root, ACTIVE_RUN_POINTER) },
        records: [],
      };
    }
    return {
      root,
      pointer: {
        state: "invalid",
        path: join(root, ACTIVE_RUN_POINTER),
        reason: "unreadable_workflow_root",
      },
      records: [],
    };
  }

  const { records, pointerInEntries } = scanRootEntries(root, entries);
  return { root, pointer: readPointer(root, !pointerInEntries), records };
}

/**
 * Select an active ledger deterministically. Any malformed record or stale /
 * ambiguous pointer is returned as a reason rather than silently resolved by
 * modification time.
 */
export function selectActiveLedger(cwd) {
  const root = join(cwd || process.cwd(), ".workflow");
  const pointer = readPointer(root);
  if (pointer.state === "invalid") {
    return {
      ledger: null,
      reason: pointer.reason,
      inspection: { root, pointer, records: [] },
    };
  }
  if (pointer.state === "present") {
    const path = join(root, pointer.run, "events.jsonl");
    if (!isContainedPath(root, path)) {
      return {
        ledger: null,
        reason: "invalid_active_run_pointer",
        inspection: { root, pointer, records: [] },
      };
    }
    const record = {
      path,
      run: pointer.run,
      ...inspectLedgerFile(path, pointer.run),
    };
    const inspection = { root, pointer, records: [record] };
    if (!record.valid) {
      return {
        ledger: null,
        reason: "invalid_active_ledger",
        inspection,
        invalid: [record],
      };
    }
    if (record.terminal) {
      return { ledger: null, reason: "stale_active_run_pointer", inspection };
    }
    return { ledger: record, reason: null, inspection };
  }

  const inspection = inspectLedgerRoot(cwd);
  if (inspection.pointer.state === "invalid") {
    return { ledger: null, reason: inspection.pointer.reason, inspection };
  }

  // Without an explicit pointer, orphan invalid/corrupt ledgers do not hold
  // mutation authority. Only valid non-terminal runs can lock the host; junk
  // left from prior sessions must not brick ordinary work.
  const active = inspection.records.filter(
    (record) => record.valid && !record.terminal,
  );
  if (active.length === 0) {
    if (inspection.pointer.state === "present") {
      return { ledger: null, reason: "stale_active_run_pointer", inspection };
    }
    return { ledger: null, reason: null, inspection };
  }

  if (active.length !== 1) {
    return {
      ledger: null,
      reason: "ambiguous_active_ledgers",
      inspection,
      active,
    };
  }
  return { ledger: active[0], reason: null, inspection };
}
