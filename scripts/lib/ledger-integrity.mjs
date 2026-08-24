/**
 * Conservative integrity checks for ledgers that influence host mutation
 * authority. This is intentionally narrower than workflow-event's complete
 * schema validator: a guard must fail closed before it decides whether a
 * ledger can be ignored or selected as active.
 */
import { lstatSync, readdirSync, readFileSync, statSync } from "node:fs";
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
const pointerCache = new Map(); // pointer path -> { fp, value }
const scanCache = new Map(); // workflow root -> Map<run name, { fp, path, record }>

/** File fingerprint: identity + size + mtime + ctime (ns, bigint stats). */
function fingerprint(stat) {
  return { dev: stat.dev, ino: stat.ino, size: stat.size, mtimeNs: stat.mtimeNs, ctimeNs: stat.ctimeNs };
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
  return cached !== undefined && sameFingerprint(cached.fp, fp) ? cached.value : undefined;
}

function cacheStore(cache, path, fp, value) {
  if (cache.size >= CACHE_LIMIT) cache.clear();
  cache.set(path, { fp, value });
}

const TERMINAL_EVENTS = new Set(["completed", "blocked"]);
const RUN_SLUG_PATTERN = /^[a-z0-9][a-z0-9_-]*$/;
const KNOWN_EVENTS = new Set(WORKFLOW_EVENTS);

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim() !== "";
}

function isIsoTimestamp(value) {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value);
}

function isStringArray(value) {
  return Array.isArray(value) && value.length > 0 && value.every(isNonEmptyString);
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
    return isNonEmptyString(detail.reason) && isNonEmptyString(detail.needed_input);
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
 * Inspect an events.jsonl payload without silently dropping malformed data.
 * Schema v2 must bind every event to its directory slug and have an ordered,
 * final terminal. Pre-v2 ledgers remain readable for compatibility; an
 * explicit legacy terminal still closes them, but they cannot make v2 data
 * after a terminal appear active.
 */
export function inspectLedgerText(text, expectedRun) {
  if (typeof text !== "string" || text.trim() === "") {
    return invalid("empty_ledger");
  }

  const lines = text.split("\n").filter((line) => line.trim() !== "");
  const events = [];
  let previousTimestamp = "";
  let terminalIndex = -1;
  let terminalWasV2 = false;
  let legacyPostTerminal = false;

  for (const [index, line] of lines.entries()) {
    let event;
    try {
      event = JSON.parse(line);
    } catch {
      return invalid("invalid_json", events, { line: index + 1 });
    }
    if (!isObject(event)) return invalid("invalid_event_object", events, { line: index + 1 });
    if (!isNonEmptyString(event.event) || !KNOWN_EVENTS.has(event.event)) {
      return invalid("unknown_event", events, { line: index + 1 });
    }
    if (!isObject(event.detail)) return invalid("invalid_event_detail", events, { line: index + 1 });

    const isV2 = event.schema_version === 2;
    if (isV2 && !hasAuthorityDetailShape(event)) {
      return invalid("invalid_authority_detail", events, { line: index + 1 });
    }
    if (event.schema_version !== undefined && event.schema_version !== 1 && !isV2) {
      return invalid("unsupported_schema_version", events, { line: index + 1 });
    }
    if (isNonEmptyString(event.run) && event.run !== expectedRun) {
      return invalid("run_mismatch", events, { line: index + 1 });
    }
    if (isV2) {
      if (event.run !== expectedRun) return invalid("missing_or_misbound_run", events, { line: index + 1 });
      if (!isIsoTimestamp(event.ts)) return invalid("invalid_timestamp", events, { line: index + 1 });
      if (previousTimestamp !== "" && event.ts < previousTimestamp) {
        return invalid("timestamp_moved_backwards", events, { line: index + 1 });
      }
      previousTimestamp = event.ts;
    }

    if (terminalIndex !== -1) {
      if (isV2 || terminalWasV2) {
        return invalid("terminal_not_final", events, {
          line: index + 1,
          terminalLine: terminalIndex + 1,
        });
      }
      legacyPostTerminal = true;
    }

    events.push(event);
    if (TERMINAL_EVENTS.has(event.event)) {
      terminalIndex = index;
      terminalWasV2 = isV2;
    }
  }

  return {
    valid: true,
    reason: null,
    events,
    terminal: terminalIndex !== -1,
    terminalEvent: terminalIndex === -1 ? null : events[terminalIndex].event,
    legacy: events.some((event) => event.schema_version !== 2),
    legacyPostTerminal,
  };
}

/** @param {string} ledgerPath @param {string} [expectedRun] */
export function inspectLedgerFile(ledgerPath, expectedRun = basename(join(ledgerPath, ".."))) {
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
    const parent = lstatSync(join(ledgerPath, ".."), { bigint: true, throwIfNoEntry: false });
    if (parent === undefined) return invalid("unreadable_ledger");
    if (parent.isSymbolicLink()) return invalid("symlinked_ledger");
  } catch {
    return invalid("unreadable_ledger");
  }
  const key = fingerprint(stat);
  const cached = cacheLookup(ledgerCache, ledgerPath, key);
  if (cached !== undefined) return cached;
  let result;
  try {
    result = inspectLedgerText(readFileSync(ledgerPath, "utf8"), expectedRun);
  } catch {
    result = invalid("unreadable_ledger");
  }
  cacheStore(ledgerCache, ledgerPath, key, result);
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
  const key = fingerprint(stat);
  const cached = cacheLookup(pointerCache, pointerPath, key);
  if (cached !== undefined) return cached;
  let result;
  try {
    const parsed = JSON.parse(readFileSync(pointerPath, "utf8"));
    if (!isObject(parsed) || parsed.schema_version !== 1 || !isValidRunSlug(parsed.run)) {
      result = { state: "invalid", path: pointerPath, reason: "invalid_active_run_pointer" };
    } else {
      result = { state: "present", path: pointerPath, run: parsed.run };
    }
  } catch {
    result = { state: "invalid", path: pointerPath, reason: "invalid_active_run_pointer" };
  }
  cacheStore(pointerCache, pointerPath, key, result);
  return result;
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
    const path = cached !== undefined ? cached.path : join(root, entry.name, "events.jsonl");
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
    let result;
    try {
      result = inspectLedgerText(readFileSync(path, "utf8"), entry.name);
    } catch {
      result = invalid("unreadable_ledger");
    }
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

export function inspectLedgerRoot(cwd) {
  const root = join(cwd || process.cwd(), ".workflow");
  let entries;
  try {
    entries = readdirSync(root, { withFileTypes: true });
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return { root, pointer: { state: "absent", path: join(root, ACTIVE_RUN_POINTER) }, records: [] };
    }
    return {
      root,
      pointer: { state: "invalid", path: join(root, ACTIVE_RUN_POINTER), reason: "unreadable_workflow_root" },
      records: [],
    };
  }

  const { records, pointerInEntries } = scanRootEntries(root, entries);
  return { root, pointer: readPointer(root, !pointerInEntries), records };
}

/**
 * Backward-compatible helper for consumers that only need valid non-terminal
 * entries. Security-sensitive code should use selectActiveLedger instead.
 */
export function findValidActiveLedgers(cwd) {
  return inspectLedgerRoot(cwd).records.filter((record) => record.valid && !record.terminal);
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
			return { ledger: null, reason: "invalid_active_ledger", inspection, invalid: [record] };
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
  const active = inspection.records.filter((record) => record.valid && !record.terminal);
  if (active.length === 0) {
    if (inspection.pointer.state === "present") {
      return { ledger: null, reason: "stale_active_run_pointer", inspection };
    }
    return { ledger: null, reason: null, inspection };
  }

  if (active.length !== 1) {
    return { ledger: null, reason: "ambiguous_active_ledgers", inspection, active };
  }
  return { ledger: active[0], reason: null, inspection };
}
