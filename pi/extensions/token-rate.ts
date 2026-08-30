/**
 * Token Rate — shows the last LLM call's output speed (tok/s) in the footer.
 *
 * Each assistant message is timed from the end of the previous message
 * (user prompt or tool result) to the end of the streaming response, then
 * divided by the reported output tokens. Displayed via ctx.ui.setStatus().
 */
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "token-rate";
/** Ignore degenerate windows (cache hits, aborted retries). */
const MIN_SECONDS = 0.5;

const isAssistant = (m: { role?: string }): m is AssistantMessage =>
	m.role === "assistant";

const formatRate = (rate: number): string =>
	rate >= 100 ? Math.round(rate).toString() : rate.toFixed(1);

export default function (pi: ExtensionAPI) {
	/** Timestamp (ms) of the last finalized user/toolResult message. */
	let previousEnd: number | null = null;
	/** Timestamp (ms) captured when the current assistant stream started. */
	let streamStart: number | null = null;

	pi.on("session_start", (_event, ctx) => {
		previousEnd = null;
		streamStart = null;
		ctx.ui.setStatus(STATUS_KEY, undefined);
	});

	pi.on("message_start", (event) => {
		if (isAssistant(event.message)) {
			streamStart = previousEnd ?? Date.now();
		}
	});

	pi.on("message_end", (event, ctx) => {
		const message = event.message;

		if (!isAssistant(message)) {
			previousEnd = Date.now();
			return;
		}

		const startedAt = streamStart ?? Date.now();
		streamStart = null;
		const seconds = (Date.now() - startedAt) / 1000;

		const measurable =
			message.usage.output > 0 &&
			seconds >= MIN_SECONDS &&
			message.stopReason !== "error" &&
			message.stopReason !== "aborted";

		if (measurable) {
			const rate = message.usage.output / seconds;
			const text =
				ctx.ui.theme.fg("accent", `⚡ ${formatRate(rate)}`) +
				ctx.ui.theme.fg("dim", " tok/s");
			ctx.ui.setStatus(STATUS_KEY, text);
		}
	});
}
