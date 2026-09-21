import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { resolveDynamicKnowledgeContext } from "../../../workflow/runtime/obvault-topic-resolver.mjs";
import { parsePlanStatus } from "../../../workflow/runtime/workflow-router-core.mjs";
import {
	classifyWorkflowRoute,
	type PlanStatus,
	type WorkflowRouteContext,
	type WorkflowRouteDecision,
} from "./workflow-router-runtime.ts";

function readPlanStatus(cwd: string): PlanStatus {
	try {
		return parsePlanStatus(readFileSync(resolve(cwd, "PLAN.md"), "utf8")) as PlanStatus;
	} catch {
		return "missing";
	}
}

function planStatusWord(prompt: string, statusPattern: RegExp): boolean {
	const planNoun = /\bplan\b(?![\w-])(?!\s+to\b)|(?:^|[^\w-])plan\.md\b/i;
	return planNoun.test(prompt) && statusPattern.test(prompt);
}

function promptPlanStatusFallback(prompt: string): PlanStatus {
	if (planStatusWord(prompt, /\bdraft\b|brouillon/i)) return "draft";
	if (planStatusWord(prompt, /\bchallenged\b|challeng[eé]e?s?\b|bloqu[eé]e?s?\b|\bblocked\b/i)) return "challenged";
	return "unknown";
}

export function eventCwd(event: unknown, ctx?: { cwd?: unknown }): string {
	if (typeof ctx?.cwd === "string" && ctx.cwd.trim() !== "") return ctx.cwd;
	if (typeof event === "object" && event !== null && "cwd" in event) {
		const cwd = (event as { cwd?: unknown }).cwd;
		if (typeof cwd === "string" && cwd.trim() !== "") return cwd;
	}
	return typeof process.cwd === "function" ? process.cwd() : ".";
}

export function resolveWorkflowRouteContext(prompt: string, cwd: string): {
	decision: WorkflowRouteDecision;
	routeContext: WorkflowRouteContext & { planStatus: PlanStatus };
} {
	const persistedStatus = readPlanStatus(cwd);
	const routeContext = {
		planStatus: persistedStatus === "missing" ? promptPlanStatusFallback(prompt) : persistedStatus,
	};
	let decision = classifyWorkflowRoute(prompt, routeContext);
	if (!decision.knowledgeContext) {
		decision = classifyWorkflowRoute(prompt, {
			...routeContext,
			dynamicKnowledgeContext: resolveDynamicKnowledgeContext(prompt) ?? undefined,
		});
	}
	return { decision, routeContext };
}
