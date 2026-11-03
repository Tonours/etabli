import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { prBodyGuardDecision } from "../../workflow/runtime/pr-body-guard.mjs";

type DenyDecision = {
	hookSpecificOutput?: {
		permissionDecision?: string;
		permissionDecisionReason?: string;
	};
};

export default function prBody(pi: ExtensionAPI): void {
	pi.on("tool_call", (event, ctx) => {
		let decision: DenyDecision | null = null;
		try {
			decision = prBodyGuardDecision({
				cwd: ctx.cwd,
				tool_name: event.toolName,
				tool_input: event.input || {},
			}) as DenyDecision | null;
		} catch {
			return undefined;
		}
		if (decision?.hookSpecificOutput?.permissionDecision === "deny") {
			return {
				block: true,
				reason: decision.hookSpecificOutput.permissionDecisionReason || "pr-body: PR body refused",
			};
		}
		return undefined;
	});
}
