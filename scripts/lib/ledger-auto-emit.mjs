/**
 * Ledger-scoped auto-emit of validation_failed / no_progress.
 * Only when an active non-terminal .workflow ledger exists.
 * Does not invent slugs when no ledger is present.
 */
import { appendFileSync } from "node:fs";
import { isNonEmptyString } from "./predicates.mjs";
import { basename, dirname } from "node:path";
import { evaluateNoProgressStop } from "./no-progress-guard.mjs";
import {
	getActiveRunPointer,
	selectActiveLedger,
} from "./ledger-integrity.mjs";

function isoTs() {
	return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

/**
 * Pick the uniquely selected active ledger, never by modification-time tie-break.
 * @param {string} cwd
 */
export function pickPrimaryActiveLedger(cwd) {
	const selected = selectActiveLedger(cwd);
	return selected.reason ? null : selected.ledger;
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

function pointerStillSelects(cwd, run) {
	const pointer = getActiveRunPointer(cwd);
	return pointer.state === "present" && pointer.run === run;
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

	const selection = selectActiveLedger(cwd);
	if (selection.reason) {
		return { emitted: false, reason: selection.reason };
	}
	const primary = selection.ledger;
	if (!primary) return { emitted: false, reason: "no_active_ledger" };
	const pointerBacked = selection.inspection?.pointer?.state === "present";
	if (pointerBacked && !pointerStillSelects(cwd, primary.run)) {
		return { emitted: false, reason: "active_run_changed", ledger: primary.path };
	}

	let events = primary.events;
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
	if (pointerBacked && !pointerStillSelects(cwd, primary.run)) {
		return { emitted: false, reason: "active_run_changed", ledger: primary.path };
	}
	appendLedgerEvent(
		primary.path,
		"validation_failed",
		vfDetail,
		basename(dirname(primary.path)),
	);
	emitted.push("validation_failed");

	events = [
		...events,
		{
			schema_version: 2,
			ts: isoTs(),
			event: "validation_failed",
			run: basename(dirname(primary.path)),
			detail: vfDetail,
		},
	];
	const stop = evaluateNoProgressStop(events);
	const hasExplicit = events.some((e) => e.event === "no_progress");
	if (stop && !hasExplicit) {
		const headSha =
			(isNonEmptyString(input?.head_sha) && String(input.head_sha)) || "unknown";
		const np = stop.detail || {};
		if (!pointerBacked || pointerStillSelects(cwd, primary.run)) {
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
/** Flatten a tool_result content payload to plain text. */
function toolResultText(content) {
	if (typeof content === "string") return content;
	if (Array.isArray(content)) {
		return content
			.map((c) => (typeof c === "string" ? c : c?.text || ""))
			.join("\n");
	}
	if (content && typeof content === "object" && "text" in content) {
		return String(content.text);
	}
	return "";
}

export function inferBashFailureFromToolResult(content, isError) {
	const text = toolResultText(content);

	const exitMatch = text.match(/exit(?:\s+code)?[=:\s]+(-?\d+)/i);
	if (exitMatch) {
		const code = Number(exitMatch[1]);
		if (Number.isInteger(code) && code !== 0) {
			return {
				failed: true,
				exit: Math.abs(code) || 1,
				failure: text.slice(0, 200) || `exit ${code}`,
			};
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

const VALIDATION_SEGMENT_PATTERNS = [
	/^(?:\.?\/)?scripts\/verify-agentic-infra(?:\s+(?:core|full|live))?$/i,
	/^(?:\.?\/)?scripts\/workflow-event\s+validate\s+[a-z0-9][a-z0-9_-]*(?:\s+--profile\s+(?:structural|autonomous-completed|blocked-terminal))?$/i,
	/^(?:bun|npm|pnpm|yarn)\s+(?:test|lint|run\s+(?:test|lint|typecheck|check|verify|validate|audit|eval))\b[^;&|]*$/i,
	/^node\s+(?:--check|--test)\b[^;&|]*$/i,
	/^python3?\s+-m\s+(?:pytest|unittest)\b[^;&|]*$/i,
	/^pytest(?:\s+[^;&|]+)?$/i,
	/^(?:cargo|go)\s+test\b[^;&|]*$/i,
	/^(?:bash|sh)\s+tests\/[a-z0-9][a-z0-9._/-]*$/i,
	/^git\s+diff\s+[^;&|]*\bcheck\b[^;&|]*$/i,
];

/*
 * Flags that make a command mutating or non-terminating: auto-fix / write
 * modes rewrite files, snapshot/golden updates regenerate fixtures, and watch
 * modes never exit. None of them is a one-shot validation, so a command
 * carrying one must not be treated as a validation run (else the ledger
 * wrongly credits progress or, on failure, blocks via no_progress).
 */
const MUTATING_OR_WATCH_FLAG_PATTERNS = [
	/^-{1,2}fix/i, // eslint/prettier/gofmt auto-fix (incl. --fix-dry-run)
	/^--write\b/i, // formatter write mode
	/^-u$/, // jest snapshot update
	/^--update(-snapshots?)?$/i, // jest/pytest snapshot update
	/^--updateSnapshots?$/i,
	/^-update$/, // go golden-file update idiom
	/^-{1,2}watch/i, // jest/vitest/node/tsc watch modes (incl. --watchAll)
	/^-w$/, // short watch alias (tsc -w, vitest -w)
];

function hasMutatingOrWatchFlag(segment) {
	return segment
		.split(/\s+/)
		.some((token) =>
			MUTATING_OR_WATCH_FLAG_PATTERNS.some((pattern) => pattern.test(token)),
		);
}

function isValidationSegment(segment) {
	const normalized = segment.trim().replace(/\s+2>&1\s*$/i, "");
	if (normalized.includes("..")) return false;
	if (hasMutatingOrWatchFlag(normalized)) return false;
	return VALIDATION_SEGMENT_PATTERNS.some((pattern) => pattern.test(normalized));
}

export function isLikelyValidationCommand(command) {
	const value = String(command || "").trim();
	if (!value || value.includes("..") || /[\r\n;|<>`]|\$\(/.test(value))
		return false;
	const segments = value.split(/\s+&&\s+/);
	if (segments.length > 2) return false;
	if (segments.length === 2 && !/^cd\s+[^;&|]+$/i.test(segments[0].trim()))
		return false;
	return isValidationSegment(segments.at(-1));
}
