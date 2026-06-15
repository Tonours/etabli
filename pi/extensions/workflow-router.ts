import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  appendWorkflowRouterGuidance,
  classifyWorkflowRoute,
  shouldInjectWorkflowRouter,
  WORKFLOW_ROUTER_EXTENSION_VERSION,
  type PlanStatus,
} from "./lib/workflow-router-runtime.ts";

const CUSTOM_MESSAGE_TYPE = "etabli.workflow-router";

type RoutablePi = ExtensionAPI & {
  appendEntry?: (customType: string, data?: unknown) => void;
};

function inferPlanStatus(prompt: string): PlanStatus {
  if (/\bready\b|\bpr[eê]t\b/i.test(prompt)) return "ready";
  if (/\bdraft\b|brouillon/i.test(prompt)) return "draft";
  if (/\bchallenged\b|bloqu[eé]|challenge/i.test(prompt)) return "challenged";
  return "unknown";
}

export default function (pi: ExtensionAPI) {
  const routablePi = pi as RoutablePi;

  pi.on("before_agent_start", (event) => {
    if (!shouldInjectWorkflowRouter(event.prompt)) return undefined;

    const decision = classifyWorkflowRoute(event.prompt, {
      planStatus: inferPlanStatus(event.prompt),
      hasTaskTools: pi.getActiveTools().some((toolName) => toolName.startsWith("Task")),
    });

    routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
      version: WORKFLOW_ROUTER_EXTENSION_VERSION,
      decision,
    });

    return {
      systemPrompt: appendWorkflowRouterGuidance(event.systemPrompt, decision),
    };
  });
}
