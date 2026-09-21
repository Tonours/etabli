import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { pickPrimaryActiveLedger } from "./lib/ledger-auto-emit.ts";
import { createPiRunBinding, PI_RUN_BINDING_TYPE } from "./lib/pi-run-binding.ts";

function maybeAppendRunBinding(pi: ExtensionAPI, ctx: ExtensionContext) {
	const ledger = pickPrimaryActiveLedger(ctx.cwd);
	const genesis = ledger?.events?.[0];
	if (!ledger || !genesis) return;
	const entries = ctx.sessionManager.getEntries();
	const binding = createPiRunBinding(ctx.sessionManager.getSessionId(), ledger.run, genesis);
	if (entries.some((entry) => entry.type === "custom" && entry.customType === PI_RUN_BINDING_TYPE && (entry.data as { fingerprint?: unknown } | undefined)?.fingerprint === binding.fingerprint)) return;
	pi.appendEntry(PI_RUN_BINDING_TYPE, binding);
}

export default function workflowRunBinding(pi: ExtensionAPI) {
	pi.on("tool_result", (_event, ctx) => {
		try {
			maybeAppendRunBinding(pi, ctx);
		} catch {
			// Diagnostic metadata must never break tool delivery.
		}
	});
	pi.on("agent_settled", (_event, ctx) => {
		try {
			maybeAppendRunBinding(pi, ctx);
		} catch {
			// Diagnostic metadata must never break the agent lifecycle.
		}
	});
}
