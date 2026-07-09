import {
  buildAutonomousPlanChain as buildAutonomousPlanChainCore,
  classifyWorkflowRoute as classifyWorkflowRouteCore,
} from "../../../workflow/runtime/workflow-router-core.mjs";

export const WORKFLOW_ROUTER_EXTENSION_VERSION = "0.2.0";

export type WorkflowRoute =
  | "answer" | "plan-loop" | "adversary" | "implement" | "plan-implement"
  | "bug-check" | "linear-ticket-create" | "linear-work" | "pr-review"
  | "pr-qa" | "sec-pr" | "ci-fix" | "review" | "verify"
  | "research-plan" | "spec-guide" | "ops-stop";

export type PlanStatus = "missing" | "draft" | "challenged" | "ready" | "unknown";

export type WorkflowPlanChain = {
  kind: "autonomous-plan-loop";
  currentPlanStatus: PlanStatus;
  currentPhase: "planning" | "ready_to_implement";
  nextRoute: "plan-loop" | "implement";
  requiredEvidence: string[];
};

export type WorkflowRouteDecision = {
  route: WorkflowRoute;
  reason: string;
  command?: string;
  skill?: string;
  artifact: string;
  stopCondition: string;
  requiredEvidence: string;
  writeAllowed: boolean;
  suggestion?: string;
  planChain?: WorkflowPlanChain;
};

export type WorkflowRouteContext = { planStatus?: PlanStatus; hasTaskTools?: boolean };

export function classifyWorkflowRoute(
  prompt: string,
  context: WorkflowRouteContext = {},
): WorkflowRouteDecision {
  const core = classifyWorkflowRouteCore(prompt, context) as WorkflowRouteDecision & { route: WorkflowRoute | "verify-workflow" };
  const route = core.route === "verify-workflow" ? "verify" : core.route;
  return {
    ...core,
    route,
    skill: route === "answer" || route === "ops-stop" || route === "research-plan" ? core.skill : route,
    stopCondition: core.stopCondition.replace(/Verdict: /g, ""),
  };
}

export function buildAutonomousPlanChain(planStatus: PlanStatus): WorkflowPlanChain {
  return buildAutonomousPlanChainCore(planStatus) as WorkflowPlanChain;
}

export function appendWorkflowRouterGuidance(
  systemPrompt: string,
  decision: WorkflowRouteDecision,
): string {
  const marker = "# Etabli Workflow Router";
  if (systemPrompt.includes(marker)) return systemPrompt;
  const chain = decision.planChain
    ? `\nPlan chain: ${decision.planChain.currentPhase} -> ${decision.planChain.nextRoute}\nPlan status source: actual root PLAN.md status when available, not prompt wording alone.\nAutonomous completion evidence: ${decision.planChain.requiredEvidence.join("; ")}`
    : "";
  return `${systemPrompt.trimEnd()}\n\n${marker}\n\nRoute: ${decision.route}\nReason: ${decision.reason}\nArtifact: ${decision.artifact}\nStop condition: ${decision.stopCondition}\nRequired evidence: ${decision.requiredEvidence}${chain}\n\nFollow this route unless the user explicitly invoked another skill or new local evidence proves the route is wrong. Keep Pi as the primary tool; do not create an external wrapper.`;
}

export function shouldInjectWorkflowRouter(prompt: string): boolean {
  const trimmed = prompt.trim();
  return trimmed !== "" && !trimmed.startsWith("/");
}
