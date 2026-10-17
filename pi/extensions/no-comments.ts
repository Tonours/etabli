import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { noCommentsGuardDecision } from "../../workflow/runtime/no-comments-guard.mjs";

type DenyDecision = {
	hookSpecificOutput?: {
		permissionDecision?: string;
		permissionDecisionReason?: string;
	};
};

function eventCwd(event: unknown): string {
	if (typeof event === "object" && event !== null && "cwd" in event) {
		const cwd = (event as { cwd?: unknown }).cwd;
		if (typeof cwd === "string" && cwd.trim() !== "") return cwd;
	}
	if (typeof process.cwd === "function") return process.cwd();
	return ".";
}

export default function noComments(pi: ExtensionAPI): void {
	pi.on("tool_call", (event) => {
		const decision = noCommentsGuardDecision({
			cwd: eventCwd(event),
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
