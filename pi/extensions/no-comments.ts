import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { noCommentsGuardDecision } from "../../workflow/runtime/no-comments-guard.mjs";

type DenyDecision = {
	hookSpecificOutput?: {
		permissionDecision?: string;
		permissionDecisionReason?: string;
	};
};

export default function noComments(pi: ExtensionAPI): void {
	pi.on("tool_call", (event, ctx) => {
		const decision = noCommentsGuardDecision({
			cwd: ctx.cwd,
			tool_name: event.toolName,
			tool_input: event.input || {},
		}) as DenyDecision | null;
		if (decision?.hookSpecificOutput?.permissionDecision === "deny") {
			return {
				block: true,
				reason:
					decision.hookSpecificOutput.permissionDecisionReason ||
					"no-comments: added code comments are blocked",
			};
		}
		return undefined;
	});
}
