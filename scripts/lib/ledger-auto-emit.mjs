/**
 * Ledger-scoped auto-emit of validation_failed / no_progress.
 * Only when an active non-terminal .workflow ledger exists.
 * Does not invent slugs when no ledger is present.
 */
import { appendFileSync, existsSync, statSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import {
  evaluateNoProgressStop,
  findActiveLedgers,
  loadLedgerEvents,
} from "./no-progress-guard.mjs";

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim() !== "";
}

function isoTs() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

/**
 * Pick primary active ledger: most recently modified events.jsonl.
 * @param {string} cwd
 */
export function pickPrimaryActiveLedger(cwd) {
  const active = findActiveLedgers(cwd);
  if (active.length === 0) return null;
  let best = active[0];
  let bestMtime = 0;
  for (const entry of active) {
    try {
      const m = statSync(entry.path).mtimeMs;
      if (m >= bestMtime) {
        bestMtime = m;
        best = entry;
      }
    } catch {
      // keep best
    }
  }
  return best;
}

/**
 * @param {string} ledgerPath
 * @param {string} event
 * @param {Record<string, unknown>} detail
 * @param {string} [runSlug]
 */
export function appendLedgerEvent(ledgerPath, event, detail, runSlug) {
  const slug = runSlug || basename(dirname(ledgerPath));
  const line = JSON.stringify({
    schema_version: 2,
    ts: isoTs(),
    event,
    run: slug,
    detail,
  });
  appendFileSync(ledgerPath, `${line}\n`, "utf8");
  return line;
}

function recentDuplicateValidation(events, command, failure) {
  // Dedupe: same command+failure after last file_changed already recorded once in last 3 matching fails
  const latestDiff = events.reduce(
    (last, event, index) => (event.event === "file_changed" ? index : last),
    -1,
  );
  const slice = events.slice(latestDiff + 1);
  let count = 0;
  for (const event of slice) {
    if (
      event.event === "validation_failed" &&
      event.detail?.command === command &&
      event.detail?.failure === failure
    ) {
      count += 1;
    }
  }
  // Cap unbounded spam: after 8 identical fails, stop auto-appending more
  return count >= 8;
}

/**
 * Record a bash failure into the primary active ledger and optionally no_progress.
 *
 * @param {string} cwd
 * @param {{ command: string, exit: number, failure?: string, head_sha?: string }} input
 * @returns {{ emitted: boolean, reason: string, ledger?: string, events?: string[] }}
 */
export function recordBashValidationFailure(cwd, input) {
  const command = String(input?.command || "").trim();
  const exitCode = Number(input?.exit);
  const failure = isNonEmptyString(input?.failure)
    ? String(input.failure).slice(0, 500)
    : `exit ${exitCode}`;

  if (!command) {
    return { emitted: false, reason: "empty_command" };
  }
  if (!Number.isInteger(exitCode) || exitCode < 1) {
    return { emitted: false, reason: "non_positive_exit" };
  }

  const primary = pickPrimaryActiveLedger(cwd);
  if (!primary) {
    return { emitted: false, reason: "no_active_ledger" };
  }

  let events = loadLedgerEvents(primary.path);
  if (recentDuplicateValidation(events, command, failure)) {
    return {
      emitted: false,
      reason: "duplicate_cap",
      ledger: primary.path,
    };
  }

  const emitted = [];
  const vfDetail = {
    command,
    exit: exitCode,
    failure,
  };
  appendLedgerEvent(primary.path, "validation_failed", vfDetail, basename(dirname(primary.path)));
  emitted.push("validation_failed");

  events = loadLedgerEvents(primary.path);
  const stop = evaluateNoProgressStop(events);
  const hasExplicit = events.some((e) => e.event === "no_progress");
  if (stop && !hasExplicit) {
    const headSha =
      (isNonEmptyString(input?.head_sha) && String(input.head_sha)) || "unknown";
    const np = stop.detail || {};
    appendLedgerEvent(
      primary.path,
      "no_progress",
      {
        check_or_hypothesis: String(np.check_or_hypothesis || failure),
        command: String(np.command || command),
        attempts: Number(np.attempts) > 0 ? Number(np.attempts) : 1,
        head_sha: headSha,
        eliminated: Array.isArray(np.eliminated)
          ? np.eliminated.map(String)
          : [failure],
      },
      basename(dirname(primary.path)),
    );
    emitted.push("no_progress");
  }

  return {
    emitted: true,
    reason: "appended",
    ledger: primary.path,
    events: emitted,
  };
}

/**
 * Best-effort parse of bash tool_result content for exit status.
 * @param {unknown} content
 * @param {boolean} [isError]
 */
export function inferBashFailureFromToolResult(content, isError) {
  const text =
    typeof content === "string"
      ? content
      : Array.isArray(content)
        ? content.map((c) => (typeof c === "string" ? c : c?.text || "")).join("\n")
        : content && typeof content === "object" && "text" in content
          ? String(content.text)
          : "";

  const exitMatch = text.match(/exit(?:\s+code)?[=:\s]+(-?\d+)/i);
  if (exitMatch) {
    const code = Number(exitMatch[1]);
    if (Number.isInteger(code) && code !== 0) {
      return { failed: true, exit: Math.abs(code) || 1, failure: text.slice(0, 200) || `exit ${code}` };
    }
    if (code === 0) return { failed: false };
  }

  if (isError) {
    return {
      failed: true,
      exit: 1,
      failure: text.slice(0, 200) || "bash tool error",
    };
  }
  return { failed: false };
}

export function isBashToolName(name) {
  const n = String(name || "").toLowerCase();
  return n === "bash" || n === "shell" || n === "run_terminal_command";
}
