import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
	beginCompaction,
	blocksNavigation,
	compactInstructions,
	completeCompaction,
	createState,
	decide,
	failCompaction,
	formatTokens,
	isBenignCompactionError,
	newGeneration,
	readConfig,
	skipCompaction,
	syncSession,
} from "./lib/session-hygiene-runtime.ts";

const sessionIdOf = (ctx: ExtensionContext): string | null => {
	try {
		return ctx.sessionManager.getSessionId();
	} catch {
		return null;
	}
};

const notify = (ctx: ExtensionContext, message: string, type: "info" | "warning" | "error") => {
	try {
		ctx.ui.notify(message, type);
	} catch {
		return;
	}
};

export default function sessionHygiene(pi: ExtensionAPI, env: Record<string, string | undefined> = process.env) {
	const config = readConfig(env);
	let state = createState();

	const startGeneration = (ctx: ExtensionContext) => {
		state = newGeneration(state, sessionIdOf(ctx));
	};

	const blockDuringCompaction = (ctx: ExtensionContext, action: string) => {
		if (!blocksNavigation(state)) return undefined;
		notify(ctx, `session-hygiene: ${action} blocked until the automatic compaction finishes`, "warning");
		return { cancel: true };
	};

	const handleFailure = (ctx: ExtensionContext, generation: number, error: unknown) => {
		const message = error instanceof Error ? error.message : String(error);
		if (isBenignCompactionError(message)) {
			state = skipCompaction(state, generation).state;
			return;
		}
		const failed = failCompaction(state, generation);
		state = failed.state;
		if (failed.outcome === "ignored") return;
		const suffix = failed.outcome === "disarmed" ? "; auto-compaction disabled for this session" : "";
		notify(ctx, `session-hygiene: compaction failed (${message})${suffix}`, failed.outcome === "disarmed" ? "error" : "warning");
	};

	pi.on("session_start", (_event, ctx) => startGeneration(ctx));
	pi.on("session_tree", (_event, ctx) => startGeneration(ctx));
	pi.on("session_before_tree", (_event, ctx) => blockDuringCompaction(ctx, "tree navigation"));
	pi.on("session_before_fork", (_event, ctx) => blockDuringCompaction(ctx, "fork"));
	pi.on("session_before_switch", (_event, ctx) => blockDuringCompaction(ctx, "session switch"));

	pi.on("agent_settled", (_event, ctx) => {
		let generation: number | null = null;
		try {
			state = syncSession(state, sessionIdOf(ctx));
			const apiAvailable = typeof ctx.compact === "function" && typeof ctx.getContextUsage === "function";
			const tokens = apiAvailable ? (ctx.getContextUsage()?.tokens ?? null) : null;
			const snapshot = {
				hasUI: ctx.hasUI,
				mode: ctx.mode,
				idle: ctx.isIdle(),
				pending: ctx.hasPendingMessages(),
				apiAvailable,
				tokens,
			};
			if (decide(state, snapshot, config) !== "compact" || tokens === null) return;
			const started = beginCompaction(state);
			state = started.state;
			generation = started.generation;
			const owned = generation;
			notify(ctx, `session-hygiene: auto-compacting at ${formatTokens(tokens)} tokens (threshold ${formatTokens(config.hardTokens)})`, "info");
			ctx.compact({
				customInstructions: compactInstructions(),
				onComplete: (result) => {
					const done = completeCompaction(state, owned, result?.estimatedTokensAfter, config);
					state = done.state;
					if (done.outcome === "disarmed") {
						notify(ctx, "session-hygiene: compaction left the context above the threshold; auto-compaction disabled for this session", "warning");
					}
				},
				onError: (error) => handleFailure(ctx, owned, error),
			});
		} catch (error) {
			if (generation !== null) handleFailure(ctx, generation, error);
		}
	});
}
