const COMPONENT_ALIASES = {
	input_tokens: ["input_tokens", "inputTokens", "input", "prompt_tokens"],
	output_tokens: ["output_tokens", "outputTokens", "output", "completion_tokens"],
	cache_read_tokens: [
		"cache_read_tokens",
		"cache_read_input_tokens",
		"cacheReadInputTokens",
		"cacheRead",
		"cache_read",
	],
	cache_creation_tokens: [
		"cache_creation_tokens",
		"cache_creation_input_tokens",
		"cacheCreationInputTokens",
		"cacheCreation",
		"cache_creation",
	],
};

const TOTAL_ALIASES = ["total_tokens", "totalTokens"];

export function isNonNegativeInteger(value) {
	return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

function componentOf(usage, keys) {
	for (const key of keys) {
		const value = Number(usage?.[key]);
		if (isNonNegativeInteger(value)) return value;
	}
	return 0;
}

function hasValidComponent(usage, keys) {
	return keys.some((key) =>
		isNonNegativeInteger(Number(usage?.[key])),
	);
}

function hasInvalidExplicitTotal(usage) {
	const key = TOTAL_ALIASES.find((candidate) => usage?.[candidate] !== undefined);
	return key !== undefined && !isNonNegativeInteger(Number(usage[key]));
}

function explicitTotalOf(usage) {
	for (const key of TOTAL_ALIASES) {
		const value = Number(usage?.[key]);
		if (isNonNegativeInteger(value)) return value;
	}
	return null;
}

export function normalizeUsage(usage) {
	const input = componentOf(usage, COMPONENT_ALIASES.input_tokens);
	const output = componentOf(usage, COMPONENT_ALIASES.output_tokens);
	const cacheRead = componentOf(usage, COMPONENT_ALIASES.cache_read_tokens);
	const cacheCreation = componentOf(
		usage,
		COMPONENT_ALIASES.cache_creation_tokens,
	);
	return {
		input_tokens: input,
		output_tokens: output,
		total_tokens: explicitTotalOf(usage) ?? input + output,
		cache_read_tokens: cacheRead,
		cache_creation_tokens: cacheCreation,
		processed_total_tokens: input + output + cacheRead + cacheCreation,
	};
}

export function componentTotals(usage) {
	const normalized = normalizeUsage(usage);
	return {
		input_tokens: normalized.input_tokens,
		output_tokens: normalized.output_tokens,
		cache_read_tokens: normalized.cache_read_tokens,
		cache_creation_tokens: normalized.cache_creation_tokens,
		processed_total_tokens: normalized.processed_total_tokens,
	};
}

export function addComponentTotals(left, right) {
	return {
		input_tokens: left.input_tokens + right.input_tokens,
		output_tokens: left.output_tokens + right.output_tokens,
		cache_read_tokens: left.cache_read_tokens + right.cache_read_tokens,
		cache_creation_tokens:
			left.cache_creation_tokens + right.cache_creation_tokens,
		processed_total_tokens:
			left.processed_total_tokens + right.processed_total_tokens,
	};
}

export function maxComponentTotals(left, right) {
	const out = {
		input_tokens: Math.max(left.input_tokens, right.input_tokens),
		output_tokens: Math.max(left.output_tokens, right.output_tokens),
		cache_read_tokens: Math.max(
			left.cache_read_tokens,
			right.cache_read_tokens,
		),
		cache_creation_tokens: Math.max(
			left.cache_creation_tokens,
			right.cache_creation_tokens,
		),
	};
	return {
		...out,
		processed_total_tokens:
			out.input_tokens +
			out.output_tokens +
			out.cache_read_tokens +
			out.cache_creation_tokens,
	};
}

export function zeroComponentTotals() {
	return {
		input_tokens: 0,
		output_tokens: 0,
		cache_read_tokens: 0,
		cache_creation_tokens: 0,
		processed_total_tokens: 0,
	};
}

export function zeroUsage() {
	return {
		input_tokens: 0,
		output_tokens: 0,
		total_tokens: 0,
		cache_read_tokens: 0,
		cache_creation_tokens: 0,
		processed_total_tokens: 0,
	};
}

export function addUsage(left, right) {
	return {
		input_tokens: left.input_tokens + right.input_tokens,
		output_tokens: left.output_tokens + right.output_tokens,
		total_tokens: left.total_tokens + right.total_tokens,
		cache_read_tokens: left.cache_read_tokens + right.cache_read_tokens,
		cache_creation_tokens:
			left.cache_creation_tokens + right.cache_creation_tokens,
		processed_total_tokens:
			left.processed_total_tokens + right.processed_total_tokens,
	};
}

export function maxUsage(left, right) {
	const out = {
		input_tokens: Math.max(left.input_tokens, right.input_tokens),
		output_tokens: Math.max(left.output_tokens, right.output_tokens),
		total_tokens: Math.max(left.total_tokens, right.total_tokens),
		cache_read_tokens: Math.max(
			left.cache_read_tokens,
			right.cache_read_tokens,
		),
		cache_creation_tokens: Math.max(
			left.cache_creation_tokens,
			right.cache_creation_tokens,
		),
	};
	return {
		...out,
		processed_total_tokens:
			out.input_tokens +
			out.output_tokens +
			out.cache_read_tokens +
			out.cache_creation_tokens,
	};
}

export function usageFromAssistantMessages(messages) {
	let total = zeroUsage();
	let found = false;
	for (const message of messages || []) {
		if (!message || message.role !== "assistant" || !message.usage) continue;
		const usage = normalizeUsage(message.usage);
		if (
			!hasValidComponent(message.usage, COMPONENT_ALIASES.input_tokens) ||
			!hasValidComponent(message.usage, COMPONENT_ALIASES.output_tokens) ||
			hasInvalidExplicitTotal(message.usage)
		) {
			continue;
		}
		total = addUsage(total, usage);
		found = true;
	}
	return found ? total : null;
}

export function baseUsageProjection(usage) {
	if (!usage) return null;
	return {
		input_tokens: usage.input_tokens,
		output_tokens: usage.output_tokens,
		total_tokens: usage.total_tokens,
	};
}

export function accumulateAssistantUsage(current, messages) {
	const next = baseUsageProjection(usageFromAssistantMessages(messages));
	if (!next) return current;
	if (!current) return next;
	return {
		input_tokens: current.input_tokens + next.input_tokens,
		output_tokens: current.output_tokens + next.output_tokens,
		total_tokens: current.total_tokens + next.total_tokens,
	};
}
