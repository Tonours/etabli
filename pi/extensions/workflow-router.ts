import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  appendWorkflowRouterGuidance,
  classifyWorkflowRoute,
  shouldInjectWorkflowRouter,
  WORKFLOW_ROUTER_EXTENSION_VERSION,
  type PlanStatus,
} from "./lib/workflow-router-runtime.ts";
import { resolveDynamicKnowledgeContext } from "../../workflow/runtime/obvault-topic-resolver.mjs";

const CUSTOM_MESSAGE_TYPE = "etabli.workflow-router";

type RoutablePi = ExtensionAPI & {
  appendEntry?: (customType: string, data?: unknown) => void;
};

function readPlanStatus(cwd: string): PlanStatus {
  try {
    const content = readFileSync(resolve(cwd, "PLAN.md"), "utf-8");
    const match = content.match(/^\s*-\s*Status:\s*(DRAFT|CHALLENGED|READY)\s*$/im);
    return match ? (match[1].toLowerCase() as PlanStatus) : "unknown";
  } catch {
    return "missing";
  }
}

function eventCwd(event: { cwd?: unknown }): string {
  if (typeof event.cwd === "string" && event.cwd.trim() !== "") return event.cwd;
  if (typeof process.cwd === "function") return process.cwd();
  return ".";
}

function promptPlanStatusFallback(prompt: string): PlanStatus {
  if (/\bdraft\b|brouillon/i.test(prompt)) return "draft";
  if (/\bchallenged\b|bloqu[eé]|challenge/i.test(prompt)) return "challenged";
  return "unknown";
}

export default function (pi: ExtensionAPI) {
  const routablePi = pi as RoutablePi;

  pi.on("before_agent_start", (event) => {
    if (!shouldInjectWorkflowRouter(event.prompt)) return undefined;

    const planStatus = readPlanStatus(eventCwd(event));
    const routeContext = {
      planStatus: planStatus === "missing" ? promptPlanStatusFallback(event.prompt) : planStatus,
      hasTaskTools: pi.getActiveTools().some((toolName) => toolName.startsWith("Task")),
    };
    let decision = classifyWorkflowRoute(event.prompt, routeContext);
    if (!decision.knowledgeContext) {
      decision = classifyWorkflowRoute(event.prompt, {
        ...routeContext,
        dynamicKnowledgeContext: resolveDynamicKnowledgeContext(event.prompt) ?? undefined,
      });
    }

    routablePi.appendEntry?.(CUSTOM_MESSAGE_TYPE, {
      version: WORKFLOW_ROUTER_EXTENSION_VERSION,
      decision,
    });

    if (decision.route === "answer" && !decision.knowledgeContext) return undefined;

    return {
      systemPrompt: appendWorkflowRouterGuidance(event.systemPrompt, decision),
    };
  });
}
