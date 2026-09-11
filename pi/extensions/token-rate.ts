import type {
	AssistantMessage,
	AssistantMessageEvent,
} from "@earendil-works/pi-ai";
import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { formatRate, TokenRateTracker } from "./lib/token-rate-runtime.ts";

const STATUS_KEY = "token-rate";

const isAssistant = (m: { role?: string }): m is AssistantMessage =>
	m.role === "assistant";

const streamedDelta = (event: AssistantMessageEvent): string | null =>
	event.type === "text_delta" ||
	event.type === "thinking_delta" ||
	event.type === "toolcall_delta"
		? event.delta
		: null;

export default function (pi: ExtensionAPI) {
	let previousEnd: number | null = null;
	const tracker = new TokenRateTracker();

	const statusText = (ctx: ExtensionContext, rate: number, estimated: boolean) =>
		ctx.ui.theme.fg("accent", `⚡ ${estimated ? "~" : ""}${formatRate(rate)}`) +
		ctx.ui.theme.fg("dim", " tok/s");

	pi.on("session_start", (_event, ctx) => {
		previousEnd = null;
		tracker.reset();
		ctx.ui.setStatus(STATUS_KEY, undefined);
	});

	pi.on("message_start", (event) => {
		if (isAssistant(event.message)) {
			tracker.start(previousEnd ?? Date.now());
		}
	});

	pi.on("message_update", (event, ctx) => {
		const delta = streamedDelta(event.assistantMessageEvent);
		if (delta === null) return;
		const live = tracker.onDelta(delta, Date.now());
		if (live === null) return;
		ctx.ui.setStatus(STATUS_KEY, statusText(ctx, live.rate, true));
	});

	pi.on("message_end", (event, ctx) => {
		const message = event.message;

		if (!isAssistant(message)) {
			previousEnd = Date.now();
			return;
		}

		const exact =
			message.stopReason === "error" || message.stopReason === "aborted"
				? null
				: tracker.finish(message.usage.output, Date.now());

		if (exact === null) {
			ctx.ui.setStatus(STATUS_KEY, undefined);
			return;
		}

		ctx.ui.setStatus(STATUS_KEY, statusText(ctx, exact, false));
	});
}
