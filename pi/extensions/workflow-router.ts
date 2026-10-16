import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { WORKFLOW_ROUTER_EXTENSION_VERSION } from "./lib/workflow-router-runtime.ts";
import { eventCwd, resolveWorkflowRouteContext } from "./lib/workflow-route-context.ts";

const CUSTOM_MESSAGE_TYPE = "etabli.workflow-router";

type RoutablePi = ExtensionAPI & {
	appendEntry?: (customType: string, data?: unknown) => void;
};

export default function (pi: ExtensionAPI) {
	const routablePi = pi as RoutablePi;
	pi.on("before_agent_start", (event, ctx) => {
		const trimmedPrompt = event.prompt.trim();
		if (trimmedPrompt === "" || trimmedPrompt.startsWith("/")) return undefined;
		const { decision } = resolveWorkflowRouteContext(event.prompt, eventCwd(event, ctx));
		routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
			version: WORKFLOW_ROUTER_EXTENSION_VERSION,
			decision,
		});
		return undefined;
	});
}
