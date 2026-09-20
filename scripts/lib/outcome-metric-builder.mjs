import { usageFromAssistantMessages } from "./usage-accounting.mjs";

export { usageFromAssistantMessages };

/**
 * Pure builders for blueprint M1 outcome_metric details.
 * Never invents token totals: measured only when real usage is provided.
 */

/**
 * @typedef {{ id: string, role?: string, input_tokens: number, output_tokens: number, total_tokens: number }} ParticipantUsage
 * @typedef {{ input_tokens: number, output_tokens: number, total_tokens: number, tool_calls?: number, elapsed_ms?: number }} CoreUsage
 */

function isNonNegInt(n) {
	return typeof n === "number" && Number.isInteger(n) && n >= 0;
}

function isNonNegNumber(n) {
	return typeof n === "number" && Number.isFinite(n) && n >= 0;
}

/**
 * Normalize one participant row.
 * @param {Partial<ParticipantUsage> & { id: string }} row
 * @returns {ParticipantUsage | null}
 */
export function normalizeParticipant(row) {
	if (!row || typeof row.id !== "string" || row.id.trim() === "") return null;
	const input = Number(row.input_tokens);
	const output = Number(row.output_tokens);
	const total =
		row.total_tokens == null ? input + output : Number(row.total_tokens);
	if (!isNonNegInt(input) || !isNonNegInt(output) || !isNonNegInt(total))
		return null;
	if (total < input + output) return null;
	/** @type {ParticipantUsage} */
	const out = {
		id: row.id.trim(),
		input_tokens: input,
		output_tokens: output,
		total_tokens: total,
	};
	const cacheRead = Number(row.cache_read_tokens ?? 0);
	const cacheCreation = Number(row.cache_creation_tokens ?? 0);
	if (isNonNegInt(cacheRead) && cacheRead > 0) out.cache_read_tokens = cacheRead;
	if (isNonNegInt(cacheCreation) && cacheCreation > 0)
		out.cache_creation_tokens = cacheCreation;
	if (typeof row.role === "string" && row.role.trim() !== "")
		out.role = row.role.trim();
	return out;
}

/**
 * Build participant_usage from parent + multi_execution usage blocks.
 * @param {{
 *   parent?: { id?: string, role?: string, input_tokens: number, output_tokens: number, total_tokens?: number },
 *   sidecars?: Array<{ id: string, role?: string, input_tokens: number, output_tokens: number, total_tokens?: number }>,
 * }} parts
 * @returns {ParticipantUsage[]}
 */
export function buildParticipantUsage(parts = {}) {
	/** @type {ParticipantUsage[]} */
	const rows = [];
	if (parts.parent) {
		const parent = normalizeParticipant({
			id: parts.parent.id || "parent",
			role: parts.parent.role || "parent",
			input_tokens: parts.parent.input_tokens,
			output_tokens: parts.parent.output_tokens,
			total_tokens: parts.parent.total_tokens,
			cache_read_tokens: parts.parent.cache_read_tokens,
			cache_creation_tokens: parts.parent.cache_creation_tokens,
		});
		if (parent) rows.push(parent);
	}
	for (const side of parts.sidecars || []) {
		const row = normalizeParticipant(side);
		if (row) rows.push(row);
	}
	// Dedupe by id keeping first
	const seen = new Set();
	return rows.filter((row) => {
		if (seen.has(row.id)) return false;
		seen.add(row.id);
		return true;
	});
}

/**
 * Extract measured sidecar usage from multi_execution_completed ledger events.
 * @param {Array<{ event?: string, detail?: any }>} events
 */
export function sidecarsFromLedgerEvents(events) {
	/** @type {Array<{ id: string, role?: string, input_tokens: number, output_tokens: number, total_tokens: number }>} */
	const sidecars = [];
	let index = 0;
	for (const event of events || []) {
		if (event?.event !== "multi_execution_completed") continue;
		const detail = event.detail || {};
		const usage = detail.usage || {};
		if (usage.measured !== true) continue;
		const input = Number(usage.input_tokens);
		const output = Number(usage.output_tokens);
		const total = Number(usage.total_tokens);
		if (!isNonNegInt(input) || !isNonNegInt(output) || !isNonNegInt(total))
			continue;
		if (total < input + output) continue;
		const participants = Array.isArray(detail.participants)
			? detail.participants
			: [];
		if (participants.length === 1) {
			const p = participants[0];
			sidecars.push({
				id:
					typeof p.id === "string" && p.id.trim() ? p.id.trim() : `sidecar-${index}`,
				role: typeof p.model === "string" ? p.model : "sidecar",
				input_tokens: input,
				output_tokens: output,
				total_tokens: total,
			});
		} else {
			// Panel totals are aggregate; attribute as one synthetic panel row to avoid fake splits.
			sidecars.push({
				id: `multi-execution-${index}`,
				role: detail.strategy || "council",
				input_tokens: input,
				output_tokens: output,
				total_tokens: total,
			});
		}
		index += 1;
	}
	return sidecars;
}

/**
 * Batch window from first/last ISO timestamps on ledger events.
 * @param {Array<{ ts?: string }>} events
 */
export function batchWindowFromEvents(events) {
	const stamps = (events || [])
		.map((e) => (typeof e.ts === "string" ? e.ts : null))
		.filter(Boolean)
		.sort();
	if (stamps.length === 0) return {};
	const started = stamps[0];
	const terminal = stamps[stamps.length - 1];
	const startMs = Date.parse(started);
	const endMs = Date.parse(terminal);
	/** @type {{ batch_started_at?: string, batch_terminal_at?: string, batch_wall_clock_ms?: number }} */
	const out = { batch_started_at: started, batch_terminal_at: terminal };
	if (Number.isFinite(startMs) && Number.isFinite(endMs) && endMs >= startMs) {
		const ms = Math.max(1, endMs - startMs);
		out.batch_wall_clock_ms = ms;
	}
	return out;
}

/**
 * Build outcome_metric detail.
 * @param {{
 *   success?: boolean,
 *   outcome?: string,
 *   success_kind?: "run_terminal" | "task_grader",
 *   grader_success?: boolean,
 *   parent?: CoreUsage & { id?: string, role?: string },
 *   sidecars?: Array<any>,
 *   tool_calls?: number,
 *   elapsed_ms?: number,
 *   runtime?: string,
 *   turn_count?: number,
 *   auto_continue_count?: number,
 *   batch_started_at?: string,
 *   batch_terminal_at?: string,
 *   batch_wall_clock_ms?: number,
 *   unmeasured_reason?: string,
 * }} input
 */
export function buildOutcomeMetricDetail(input = {}) {
	const participants = buildParticipantUsage({
		parent: input.parent,
		sidecars: input.sidecars,
	});
	const success = input.success !== false;
	const outcome =
		typeof input.outcome === "string" && input.outcome.trim()
			? input.outcome.trim()
			: success
				? "success"
				: "failed";

	/** @type {Record<string, unknown>} */
	const detail = {
		outcome,
		success,
	};

	// task_grader only when a final-state grader actually succeeded.
	if (input.success_kind === "task_grader") {
		if (input.grader_success === true) {
			detail.success_kind = "task_grader";
			detail.grader_success = true;
		} else {
			detail.success_kind = "run_terminal";
		}
	} else if (input.success_kind === "run_terminal") {
		detail.success_kind = "run_terminal";
	}

	if (participants.length > 0) {
		const inputTokens = participants.reduce((s, p) => s + p.input_tokens, 0);
		const outputTokens = participants.reduce((s, p) => s + p.output_tokens, 0);
		const totalTokens = participants.reduce((s, p) => s + p.total_tokens, 0);
		const cacheReadTokens = participants.reduce(
			(s, p) => s + (p.cache_read_tokens ?? 0),
			0,
		);
		const cacheCreationTokens = participants.reduce(
			(s, p) => s + (p.cache_creation_tokens ?? 0),
			0,
		);
		detail.measured = true;
		detail.usage_schema_version = 2;
		detail.input_tokens = inputTokens;
		detail.output_tokens = outputTokens;
		detail.total_tokens = totalTokens;
		detail.cache_read_tokens = cacheReadTokens;
		detail.cache_creation_tokens = cacheCreationTokens;
		detail.processed_total_tokens =
			inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens;
		detail.participant_usage = participants;
		detail.tool_calls = isNonNegInt(input.tool_calls) ? input.tool_calls : 0;
		detail.elapsed_ms = isNonNegNumber(input.elapsed_ms) ? input.elapsed_ms : 0;
	} else if (
		input.parent &&
		isNonNegInt(input.parent.input_tokens) &&
		isNonNegInt(input.parent.output_tokens)
	) {
		const total = isNonNegInt(input.parent.total_tokens)
			? input.parent.total_tokens
			: input.parent.input_tokens + input.parent.output_tokens;
		const cacheRead = isNonNegInt(input.parent.cache_read_tokens)
			? input.parent.cache_read_tokens
			: 0;
		const cacheCreation = isNonNegInt(input.parent.cache_creation_tokens)
			? input.parent.cache_creation_tokens
			: 0;
		detail.measured = true;
		detail.usage_schema_version = 2;
		detail.input_tokens = input.parent.input_tokens;
		detail.output_tokens = input.parent.output_tokens;
		detail.total_tokens = total;
		detail.cache_read_tokens = cacheRead;
		detail.cache_creation_tokens = cacheCreation;
		detail.processed_total_tokens =
			input.parent.input_tokens +
			input.parent.output_tokens +
			cacheRead +
			cacheCreation;
		detail.tool_calls = isNonNegInt(input.tool_calls) ? input.tool_calls : 0;
		detail.elapsed_ms = isNonNegNumber(input.elapsed_ms) ? input.elapsed_ms : 0;
	} else {
		detail.measured = false;
		detail.reason = input.unmeasured_reason || "usage unavailable";
	}

	if (typeof input.runtime === "string" && input.runtime.trim())
		detail.runtime = input.runtime.trim();
	if (isNonNegInt(input.turn_count)) detail.turn_count = input.turn_count;
	if (isNonNegInt(input.auto_continue_count))
		detail.auto_continue_count = input.auto_continue_count;
	if (typeof input.batch_started_at === "string")
		detail.batch_started_at = input.batch_started_at;
	if (typeof input.batch_terminal_at === "string")
		detail.batch_terminal_at = input.batch_terminal_at;
	if (
		isNonNegNumber(input.batch_wall_clock_ms) &&
		input.batch_wall_clock_ms > 0
	) {
		detail.batch_wall_clock_ms = input.batch_wall_clock_ms;
	}

	return detail;
}

/**
 * Whether a ledger already has a measured outcome_metric.
 * @param {Array<{ event?: string, detail?: any }>} events
 */
export function hasMeasuredOutcomeMetric(events) {
	return (events || []).some(
		(e) => e?.event === "outcome_metric" && e.detail?.measured === true,
	);
}

/**
 * Whether ledger is still open for appends.
 * @param {Array<{ event?: string }>} events
 */
export function isLedgerOpen(events) {
	return !(events || []).some(
		(e) => e?.event === "completed" || e?.event === "blocked",
	);
}

/**
 * Build from ledger events + optional parent usage.
 * @param {Array<any>} events
 * @param {{ parent?: any, success?: boolean, success_kind?: string, grader_success?: boolean, runtime?: string, tool_calls?: number, elapsed_ms?: number, turn_count?: number, auto_continue_count?: number }} opts
 */
export function buildFromLedgerEvents(events, opts = {}) {
	const sidecars = sidecarsFromLedgerEvents(events);
	const batch = batchWindowFromEvents(events);
	return buildOutcomeMetricDetail({
		success: opts.success,
		outcome: opts.outcome,
		success_kind: opts.success_kind,
		grader_success: opts.grader_success,
		parent: opts.parent,
		sidecars,
		tool_calls: opts.tool_calls,
		elapsed_ms: opts.elapsed_ms ?? batch.batch_wall_clock_ms,
		runtime: opts.runtime,
		turn_count: opts.turn_count,
		auto_continue_count: opts.auto_continue_count,
		...batch,
		unmeasured_reason: opts.unmeasured_reason,
	});
}
