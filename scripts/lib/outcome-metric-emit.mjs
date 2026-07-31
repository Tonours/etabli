/**
 * Emit measured outcome_metric into the primary active ledger when usage exists.
 * Safe no-op without ledger / when already measured / when terminal.
 */
import {
	appendLedgerEvent,
	pickPrimaryActiveLedger,
} from "./ledger-auto-emit.mjs";
import { loadLedgerEvents } from "./no-progress-guard.mjs";
import {
	buildFromLedgerEvents,
	hasMeasuredOutcomeMetric,
	isLedgerOpen,
	usageFromAssistantMessages,
} from "./outcome-metric-builder.mjs";

/**
 * @param {string} cwd
 * @param {{
 *   messages?: any[],
 *   parentUsage?: { input_tokens: number, output_tokens: number, total_tokens: number } | null,
 *   runtime?: string,
 *   success?: boolean,
 *   success_kind?: "run_terminal" | "task_grader",
 *   tool_calls?: number,
 *   turn_count?: number,
 *   auto_continue_count?: number,
 * }} opts
 */
export function maybeEmitOutcomeMetric(cwd, opts = {}) {
	const primary = pickPrimaryActiveLedger(cwd);
	if (!primary) {
		return { emitted: false, reason: "no_active_ledger" };
	}

	let events;
	try {
		events = loadLedgerEvents(primary.path);
	} catch {
		return {
			emitted: false,
			reason: "ledger_unreadable",
			ledger: primary.path,
		};
	}

	if (!isLedgerOpen(events)) {
		return { emitted: false, reason: "ledger_terminal", ledger: primary.path };
	}
	if (hasMeasuredOutcomeMetric(events)) {
		return { emitted: false, reason: "already_measured", ledger: primary.path };
	}

	const parent =
		opts.parentUsage || usageFromAssistantMessages(opts.messages || []) || null;

		let successKind = opts.success_kind || "run_terminal";
	let graderSuccess = opts.grader_success;
	if (successKind === "task_grader" && graderSuccess !== true) {
		successKind = "run_terminal";
		graderSuccess = undefined;
	}

	const detail = buildFromLedgerEvents(events, {
		parent: parent
			? {
					id: "parent",
					role: "parent",
					input_tokens: parent.input_tokens,
					output_tokens: parent.output_tokens,
					total_tokens: parent.total_tokens,
				}
			: undefined,
		success: opts.success !== false,
		success_kind: successKind,
		grader_success: graderSuccess,
		runtime: opts.runtime,
		tool_calls: opts.tool_calls,
		turn_count: opts.turn_count,
		auto_continue_count: opts.auto_continue_count,
	});


	if (detail.measured !== true) {
		return {
			emitted: false,
			reason: "no_measured_usage",
			ledger: primary.path,
			detail,
		};
	}

	try {
		appendLedgerEvent(
			primary.path,
			"outcome_metric",
			detail,
			primary.slug || undefined,
		);
		return { emitted: true, reason: "appended", ledger: primary.path, detail };
	} catch (error) {
		return {
			emitted: false,
			reason: "append_failed",
			ledger: primary.path,
			error: error instanceof Error ? error.message : String(error),
		};
	}
}
