import {
	buildAutonomousPlanChain as buildAutonomousPlanChainCore,
	classifyWorkflowRoute as classifyWorkflowRouteCore,
} from "../../../workflow/runtime/workflow-router-core.mjs";

export const WORKFLOW_ROUTER_EXTENSION_VERSION = "0.7.0";

export type WorkflowRoute =
	| "answer"
	| "plan-loop"
	| "adversary"
	| "implement"
	| "plan-implement"
	| "review"
	| "verify"
	| "ops-stop";

export type PlanStatus =
	| "missing"
	| "draft"
	| "challenged"
	| "ready"
	| "unknown";

export type WorkflowPlanChain = {
	kind: "autonomous-plan-loop";
	currentPlanStatus: PlanStatus;
	currentPhase: "planning" | "ready_to_implement";
	nextRoute: "plan-loop" | "implement";
	requiredEvidence: string[];
};

export type WorkflowKnowledgeContext = {
	topics: string[];
	query: string;
	reason: string;
	command: string;
	source?: "obvault-metadata";
	matchedNotes?: string[];
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
	knowledgeContext?: WorkflowKnowledgeContext;
	multiExecution: WorkflowMultiExecution;
};

export type WorkflowMultiExecution = {
	mode: "single";
	strategy: "single";
	writer: "parent-only";
	reason: string;
};

export type WorkflowRouteContext = {
	planStatus?: PlanStatus;
	dynamicKnowledgeContext?: WorkflowKnowledgeContext;
};

export function classifyWorkflowRoute(
	prompt: string,
	context: WorkflowRouteContext = {},
): WorkflowRouteDecision {
	const core = classifyWorkflowRouteCore(prompt, context) as Omit<
		WorkflowRouteDecision,
		"route"
	> & {
		route: WorkflowRoute | "verify-workflow";
	};
	const route = core.route === "verify-workflow" ? "verify" : core.route;
	return {
		...core,
		route,
		skill:
			route === "answer" || route === "ops-stop"
				? core.skill
				: route,
		stopCondition: core.stopCondition.replace(/Verdict: /g, ""),
	};
}

export function buildAutonomousPlanChain(
	planStatus: PlanStatus,
): WorkflowPlanChain {
	return buildAutonomousPlanChainCore(planStatus) as WorkflowPlanChain;
}

