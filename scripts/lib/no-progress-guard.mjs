/**
 * Ledger-backed no_progress evaluation for host mutation deny.
 *
 * Pure thresholds align with project-autonomy stop_conditions defaults.
 * Does not auto-emit events — only reads existing ledger evidence.
 */
import { inspectLedgerFile, selectActiveLedger } from "./ledger-integrity.mjs";
import { isNarrowPlanCleanupCommand } from "./plan-cleanup-command.mjs";

export const DEFAULT_NO_PROGRESS_THRESHOLDS = Object.freeze({
  same_hypothesis_failures: 2,
  red_checks_without_diff: 3,
});

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim() !== "";
}

/**
 * Load an integrity-valid ledger path. Missing or malformed data → [].
 * @param {string} ledgerPath
 */
export function loadLedgerEvents(ledgerPath) {
  const inspection = inspectLedgerFile(ledgerPath);
  return inspection.valid ? inspection.events : [];
}

/**
 * Derived no-progress from validation_failed after last file_changed.
 * Same algorithm as project-autonomy derivedNoProgress.
 * @param {Array<{event?: string, detail?: Record<string, unknown>}>} events
 * @param {{same_hypothesis_failures: number, red_checks_without_diff: number}} stopConditions
 * @returns {null | {reason: string, no_progress: object}}
 */
export function derivedNoProgress(
  events,
  stopConditions = DEFAULT_NO_PROGRESS_THRESHOLDS,
) {
  const latestDiff = events.reduce(
    (last, event, index) => (event.event === "file_changed" ? index : last),
    -1,
  );
  const failures = events
    .slice(latestDiff + 1)
    .filter(
      (event) =>
        event.event === "validation_failed" &&
        isNonEmptyString(event.detail?.failure) &&
        isNonEmptyString(event.detail?.command),
    );
  const byFailure = new Map();
  const byCommand = new Map();
  for (const failure of failures) {
    const hypothesis = `${failure.detail.command}\u0000${failure.detail.failure}`;
    byFailure.set(hypothesis, (byFailure.get(hypothesis) || 0) + 1);
    byCommand.set(
      failure.detail.command,
      (byCommand.get(failure.detail.command) || 0) + 1,
    );
  }
  for (const [hypothesis, attempts] of byFailure) {
    if (attempts >= stopConditions.same_hypothesis_failures) {
      const matching = failures.find(
        (event) =>
          `${event.detail.command}\u0000${event.detail.failure}` === hypothesis,
      );
      return {
        reason: "same_hypothesis_failure_limit",
        no_progress: {
          check_or_hypothesis: matching.detail.failure,
          command: matching.detail.command,
          attempts,
          eliminated: [matching.detail.failure],
        },
      };
    }
  }
  for (const [command, attempts] of byCommand) {
    if (attempts >= stopConditions.red_checks_without_diff) {
      return {
        reason: "red_check_without_diff_limit",
        no_progress: {
          check_or_hypothesis: command,
          command,
          attempts,
          eliminated: [`repeat ${command} only after a new diff`],
        },
      };
    }
  }
  return null;
}

/**
 * Explicit no_progress event or derived thresholds.
 * @returns {null | {reason: string, detail: object}}
 */
export function evaluateNoProgressStop(
  events,
  thresholds = DEFAULT_NO_PROGRESS_THRESHOLDS,
) {
  const explicit = events.find((event) => event.event === "no_progress");
  if (explicit) {
    return {
      reason: "no_progress",
      detail:
        explicit.detail && typeof explicit.detail === "object"
          ? explicit.detail
          : {},
    };
  }
  const derived = derivedNoProgress(events, thresholds);
  if (derived) {
    return {
      reason: derived.reason,
      detail: derived.no_progress,
    };
  }
  return null;
}

/**
 * Fail closed when ledger integrity or active-run selection is ambiguous, then
 * evaluate no_progress only on the deterministically selected active ledger.
 * @param {string} cwd
 * @returns {null | {reason: string, detail: object, ledger?: string}}
 */
export function shouldDenyMutationForNoProgress(
  cwd,
  thresholds = DEFAULT_NO_PROGRESS_THRESHOLDS,
) {
  const selected = selectActiveLedger(cwd);
  if (selected.reason) {
    return {
      reason: selected.reason,
      detail: {
        ledger_state: selected.reason,
        active_runs: selected.active?.map((entry) => entry.run) || [],
      },
      ledger: selected.ledger?.path,
    };
  }
  if (!selected.ledger) return null;

  const stop = evaluateNoProgressStop(selected.ledger.events, thresholds);
  if (!stop) return null;
  return {
    reason: stop.reason,
    detail: stop.detail,
    ledger: selected.ledger.path,
  };
}

/**
 * Bash that only invokes the workflow-event CLI (no chaining/redirects).
 * @param {string} command
 */
export function isWorkflowEventEscapeCommand(command) {
  const c = String(command || "").trim();
  if (!c) return false;
  // No shell chaining, pipes, or redirects that could mutate elsewhere.
  if (/[;&|<>`]/.test(c) || /\n/.test(c) || /\$\(/.test(c)) return false;
  // Relative scripts/workflow-event, bare workflow-event, or absolute .../workflow-event.
  return /^(?:node\s+|bun\s+|bash\s+)?(?:(?:\.\/)?(?:scripts\/)?workflow-event|\/(?:[A-Za-z0-9._-]+\/)*workflow-event)(?:\s+|$)/.test(
    c,
  );
}

/**
 * Escape hatch while no_progress stop is active:
 * - PLAN.md Write/Edit/MultiEdit
 * - workflow-event-only Bash
 * - validated scripts/plan-cleanup Bash
 *
 * @param {string} toolName normalized (Write|Edit|MultiEdit|Bash)
 * @param {Record<string, unknown>} toolInput
 * @param {(path: string, cwd?: string) => boolean} isPlanFileFn
 * @param {string} cwd
 */
export function isNoProgressEscapeHatch(
  toolName,
  toolInput,
  isPlanFileFn,
  cwd,
) {
  const input = toolInput || {};
  if (toolName === "Write" || toolName === "Edit" || toolName === "MultiEdit") {
    const filePath = String(
      input.file_path || input.path || input.filePath || "",
    );
    return Boolean(isPlanFileFn && isPlanFileFn(filePath, cwd));
  }
  if (toolName === "Bash") {
    const command = String(input.command || input.cmd || "");
    return (
      isWorkflowEventEscapeCommand(command) ||
      isNarrowPlanCleanupCommand(command)
    );
  }
  return false;
}
