import {
	buildAutonomousPlanChain as buildAutonomousPlanChainCore,
	classifyWorkflowRoute as classifyWorkflowRouteCore,
} from "../../../workflow/runtime/workflow-router-core.mjs";

export const WORKFLOW_ROUTER_EXTENSION_VERSION = "0.6.0";

export type WorkflowRoute =
	| "answer"
	| "plan-loop"
	| "adversary"
	| "implement"
	| "plan-implement"
	| "bug-check"
	| "linear-ticket-create"
	| "linear-work"
	| "pr-review"
	| "pr-qa"
	| "sec-pr"
	| "ci-fix"
	| "review"
	| "verify"
	| "research-plan"
	| "spec-guide"
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
	mode: "single" | "panel";
	trigger: "none" | "explicit" | "adaptive";
	strategy: "single" | "scout" | "council";
	signals: string[];
	score: number;
	reason: string;
	roles: string[];
	fallbackRoles: string[];
	adjudicator: string | null;
	maxSidecars: number;
	maxDepth: number;
	independentFirstPasses: boolean;
	writer: "parent-only";
	panelStages: string[];
	budget: {
		maxFirstPassAgents: number;
		maxFallbackAgents: number;
		maxResumesPerPrimary: number;
		maxAdjudications: number;
		maxClaims: number;
		requestedOutputTokens: {
			scout?: number;
			firstPassPerAgent?: number;
			rebuttalPerAgent?: number;
			adjudication?: number;
			total: number;
		};
	};
	runtimeStatus?: "pending" | "degraded" | "not_needed";
};

export type WorkflowRouteContext = {
	planStatus?: PlanStatus;
	hasTaskTools?: boolean;
	hasAgentTools?: boolean;
	dynamicKnowledgeContext?: WorkflowKnowledgeContext;
};

function runtimeStatusFor(
	mode: WorkflowMultiExecution["mode"],
	hasAgentTools: boolean | undefined,
): NonNullable<WorkflowMultiExecution["runtimeStatus"]> {
	if (mode === "single") return "not_needed";
	return hasAgentTools === true ? "pending" : "degraded";
}

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
			route === "answer" || route === "ops-stop" || route === "research-plan"
				? core.skill
				: route,
		stopCondition: core.stopCondition.replace(/Verdict: /g, ""),
		multiExecution: {
			...core.multiExecution,
			runtimeStatus: runtimeStatusFor(
				core.multiExecution.mode,
				context.hasAgentTools,
			),
		},
	};
}

export function buildAutonomousPlanChain(
	planStatus: PlanStatus,
): WorkflowPlanChain {
	return buildAutonomousPlanChainCore(planStatus) as WorkflowPlanChain;
}

