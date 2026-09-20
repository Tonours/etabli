import {
	addComponentTotals as sumComponents,
	componentTotals,
	maxComponentTotals as maxComponents,
	zeroComponentTotals as zero,
} from "./usage-accounting.mjs";

export { componentTotals };
export function usageFromHeadlessRecord(record) {
	const usage = record?.result?.usage ?? record?.usage ?? null;
	if (!usage || typeof usage !== "object") return null;
	const totals = componentTotals(usage);
	if (
		totals.input_tokens === 0 &&
		totals.output_tokens === 0 &&
		totals.cache_read_tokens === 0 &&
		totals.cache_creation_tokens === 0
	) {
		return null;
	}
	const modelUsage = record?.result?.modelUsage ?? record?.modelUsage;
	if (modelUsage && typeof modelUsage === "object") {
		let summed = null;
		for (const entry of Object.values(modelUsage)) {
			const u =
				entry?.usage && typeof entry.usage === "object" ? entry.usage : entry;
			const parts = componentTotals(u);
			summed = summed ? sumComponents(summed, parts) : parts;
		}
		if (
			summed &&
			summed.processed_total_tokens > 0 &&
			summed.processed_total_tokens !== totals.processed_total_tokens
		) {
			return {
				...totals,
				model_usage_mismatch: {
					result_usage: totals.processed_total_tokens,
					model_usage_sum: summed.processed_total_tokens,
				},
			};
		}
	}
	return totals;
}

export function usageFromCostStates(samples, sessionId) {
	let last = null;
	for (const sample of samples || []) {
		if (sessionId && sample?.session_id && sample.session_id !== sessionId) {
			continue;
		}
		const cumulative =
			sample?.data?.cumulative_usage ??
			sample?.cumulative_usage ??
			sample?.data?.usage ??
			sample?.usage ??
			sample;
		const parts = componentTotals(cumulative);
		if (parts.processed_total_tokens > 0) last = parts;
	}
	return last;
}

function classifyEntry(entry) {
	if (
		entry?.isSidechain === true ||
		entry?.sidechain === true ||
		(typeof entry?.userType === "string" && entry.userType === "subagent")
	) {
		return "subagent";
	}
	const requestId = entry?.requestId ?? entry?.request_id;
	const messageId =
		entry?.uuid ?? entry?.message?.id ?? entry?.message?.uuid ?? entry?.id;
	if (requestId || messageId) return "main";
	return "auxiliary";
}

function entryUsage(entry) {
	return (
		entry?.usage ??
		entry?.message?.usage ??
		entry?.message?.message?.usage ??
		null
	);
}

function entryGroupKeys(entry) {
	const requestId = entry?.requestId ?? entry?.request_id ?? null;
	const messageId =
		entry?.uuid ?? entry?.message?.id ?? entry?.message?.uuid ?? null;
	return { requestId, messageId };
}

export function rollupTranscript(entries) {
	const groups = new Map();
	for (const entry of entries || []) {
		const usage = entryUsage(entry);
		if (!usage || typeof usage !== "object") continue;
		const parts = componentTotals(usage);
		if (parts.processed_total_tokens === 0) continue;
		const cls = classifyEntry(entry);
		const { requestId, messageId } = entryGroupKeys(entry);
		const key = requestId ?? messageId ?? `unattributed:${groups.size}`;
		const groupKey = `${cls}:${key}`;
		const existing = groups.get(groupKey);
		if (existing) {
			existing.usage = maxComponents(existing.usage, parts);
			existing.entries += 1;
		} else {
			groups.set(groupKey, { cls, key, usage: parts, entries: 1 });
		}
	}
	const totalsByClass = { main: zero(), subagent: zero(), auxiliary: zero() };
	const rolled = [];
	for (const group of groups.values()) {
		totalsByClass[group.cls] = sumComponents(
			totalsByClass[group.cls],
			group.usage,
		);
		rolled.push(group);
	}
	const attributed = sumComponents(totalsByClass.main, totalsByClass.subagent);
	return {
		groups: rolled,
		totals_by_class: totalsByClass,
		attributed_total_tokens: attributed.processed_total_tokens,
		processed_total_tokens: sumComponents(attributed, totalsByClass.auxiliary)
			.processed_total_tokens,
	};
}

export function reconcileWithE2E(rollup, e2e, opts = {}) {
	const tolerance = opts.tolerance ?? 0.01;
	const e2eTotal = e2e.processed_total_tokens;
	const attributed = rollup.attributed_total_tokens;
	const residual = e2eTotal - attributed;
	const residualRatio = e2eTotal > 0 ? Math.abs(residual) / e2eTotal : 0;
	return {
		e2e_total_tokens: e2eTotal,
		attributed_total_tokens: attributed,
		residual_tokens: residual,
		residual_ratio: residualRatio,
		within_tolerance: residualRatio <= tolerance,
	};
}
