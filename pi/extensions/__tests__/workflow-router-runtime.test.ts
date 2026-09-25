import { describe, expect, test } from "bun:test";
import { classifyWorkflowRoute } from "../lib/workflow-router-runtime.ts";

describe("workflow router runtime", () => {
	test("does not trust prompt wording alone for READY plan implementation", () => {
		expect(classifyWorkflowRoute("Implémente le PLAN.md ready")).toMatchObject({
			route: "plan-implement",
			reason:
				"READY plan mentioned, but actual PLAN.md status is not proven READY",
			planChain: {
				currentPlanStatus: "missing",
				currentPhase: "planning",
				nextRoute: "plan-loop",
			},
		});
	});

	test("keeps read-only READY plan prompts as answers", () => {
		expect(classifyWorkflowRoute("Résume le PLAN.md ready")).toMatchObject({
			route: "answer",
			writeAllowed: false,
		});
		expect(
			classifyWorkflowRoute("Résume le PLAN.md ready", { planStatus: "ready" }),
		).toMatchObject({
			route: "answer",
			writeAllowed: false,
		});
	});

	test("routes actual READY plan implementation to implement", () => {
		expect(
			classifyWorkflowRoute("Implémente le PLAN.md ready", {
				planStatus: "ready",
			}),
		).toMatchObject({
			route: "implement",
			planChain: {
				currentPlanStatus: "ready",
				currentPhase: "ready_to_implement",
				nextRoute: "implement",
			},
		});
	});

	test("routes autonomous plan-loop requests through plan-implement", () => {
		expect(
			classifyWorkflowRoute("Lance le plan-loop en autonomie jusqu'au bout"),
		).toMatchObject({
			route: "plan-implement",
			reason: "autonomous plan-loop request",
			stopCondition:
				"READY plan implemented, verified/reviewed, archived, root PLAN.md deleted; else CHALLENGED/blocked with evidence",
			planChain: {
				currentPhase: "planning",
				nextRoute: "plan-loop",
			},
		});
	});

	test("routes ordinary coding to direct edit without a plan", () => {
		const decision = classifyWorkflowRoute("Corrige tout y compris les warnings");

		expect(decision).toMatchObject({
			route: "answer",
			writeAllowed: true,
		});
	});

	test("routes adversarial plan review to adversary", () => {
		expect(
			classifyWorkflowRoute("Fais une passe adversary sur le PLAN.md"),
		).toMatchObject({
			route: "adversary",
			skill: "adversary",
			writeAllowed: true,
			stopCondition:
				"plan stays READY, becomes CHALLENGED, or adversary blocker reported",
		});
	});

	test("does not route adversarial code review to plan adversary", () => {
		expect(
			classifyWorkflowRoute(
				"fais une code-review complète puis une code-review adversary",
			),
		).toMatchObject({
			route: "review",
			skill: "review",
			writeAllowed: false,
		});
	});

	test("keeps explicitly read-only adversarial plan review read-only", () => {
		expect(
			classifyWorkflowRoute(
				"Read-only adversarial PLAN.md review. Do not edit files.",
			),
		).toMatchObject({
			route: "review",
			skill: "review",
			writeAllowed: false,
			reason: "read-only adversarial review request",
		});
	});

	test("routes reviews and verification as read-only", () => {
		expect(
			classifyWorkflowRoute("Fais une review de notre roadmap"),
		).toMatchObject({
			route: "review",
			writeAllowed: false,
		});
		expect(
			classifyWorkflowRoute("Retest et prouve que c'est fini"),
		).toMatchObject({
			route: "verify",
			writeAllowed: false,
		});
	});

	test("always attaches parent-only multi-execution", () => {
		const expected = {
			mode: "single",
			strategy: "single",
			writer: "parent-only",
			reason: "multi-model portfolio removed",
		} as const;
		expect(classifyWorkflowRoute("Corrige le bug").multiExecution).toEqual(
			expected,
		);
		expect(
			classifyWorkflowRoute("Fais un plan sans panel").multiExecution,
		).toEqual(expected);
	});

	test("routes Linear ticket creation and Linear work to dedicated skills", () => {
		expect(
			classifyWorkflowRoute("Crée un ticket Linear pour ce bug de login"),
		).toMatchObject({
			route: "linear-ticket-create",
			skill: "linear-ticket-create",
			writeAllowed: true,
		});

		expect(
			classifyWorkflowRoute(
				"Peux-tu créer un ticket Linear pour corriger le bug de login",
			),
		).toMatchObject({
			route: "linear-ticket-create",
			skill: "linear-ticket-create",
			writeAllowed: true,
		});

		expect(
			classifyWorkflowRoute("Corrige le bug décrit dans Linear LIN-123"),
		).toMatchObject({
			route: "linear-work",
			skill: "linear-work",
			writeAllowed: true,
		});

		expect(
			classifyWorkflowRoute("Résume le ticket Linear LIN-123"),
		).toMatchObject({
			route: "answer",
			writeAllowed: false,
		});
	});

	test("routes Linear bug analysis to bug-check", () => {
		expect(
			classifyWorkflowRoute("Analyse le bug Linear PRD-387 sans coder"),
		).toMatchObject({
			route: "bug-check",
			skill: "bug-check",
			writeAllowed: false,
		});
	});

	test("routes GitHub PR reviews through gh-specific review", () => {
		expect(
			classifyWorkflowRoute("Fais une code review de la PR GitHub 42"),
		).toMatchObject({
			route: "pr-review",
			skill: "pr-review",
			writeAllowed: false,
		});
	});

	test("routes PR QA, security PR, and explicit CI fix", () => {
		expect(
			classifyWorkflowRoute("Comment tester la PR GitHub 42 ?"),
		).toMatchObject({
			route: "pr-qa",
			skill: "pr-qa",
			writeAllowed: false,
		});

		expect(classifyWorkflowRoute("Audite la PR Dependabot #1606")).toMatchObject({
			route: "sec-pr",
			skill: "sec-pr",
			writeAllowed: false,
		});

		expect(classifyWorkflowRoute("ci-fix 42")).toMatchObject({
			route: "ci-fix",
			skill: "ci-fix",
			writeAllowed: true,
		});

		expect(classifyWorkflowRoute("fix CI and push PR #42")).toMatchObject({
			route: "ci-fix",
			skill: "ci-fix",
			writeAllowed: true,
		});
	});

	test("routes sourced research to research-plan", () => {
		expect(
			classifyWorkflowRoute("Fais un fact-check sourcé via recherche web"),
		).toMatchObject({
			route: "research-plan",
			artifact: "cited document under docs/",
		});
	});

	test("adds bounded SaaS knowledge retrieval without changing the workflow route", () => {
		const decision = classifyWorkflowRoute(
			"Je recherche des idées de SaaS rentables",
		);

		expect(decision).toMatchObject({
			route: "research-plan",
			knowledgeContext: {
				topics: ["saas"],
				query:
					"saas opportunity product discovery buyer pain budget workflow validation",
			},
		});
		expect(decision.knowledgeContext?.command).toContain("--max-tokens 2500");
		expect(decision.knowledgeContext?.command).not.toContain("rentables");
	});

	test("supports multiple knowledge topics and leaves unrelated answers untouched", () => {
		expect(
			classifyWorkflowRoute("Corrige le bug CSS dans notre SaaS"),
		).toMatchObject({
			route: "answer",
			knowledgeContext: { topics: ["saas", "frontend-css"] },
		});
		expect(classifyWorkflowRoute("Bonjour, comment vas-tu ?")).not.toHaveProperty(
			"knowledgeContext",
		);
		expect(classifyWorkflowRoute("J’ai une question simple")).not.toHaveProperty(
			"knowledgeContext",
		);
	});

	test("maps every supported durable knowledge family", () => {
		const cases = [
			["Compare les coding agents et MCP", ["ai-agents"]],
			[
				"Explique cette architecture logicielle et son couplage",
				["software-design"],
			],
			["Comment évaluer un voice agent en temps réel ?", ["voice"]],
			["Organise notre knowledge base comme un second brain", ["second-brain"]],
			["Analyse l'autorisation de ce webhook", ["web-security"]],
		] as const;

		for (const [prompt, topics] of cases) {
			expect(classifyWorkflowRoute(prompt).knowledgeContext?.topics).toEqual([
				...topics,
			]);
		}
	});

	test("keeps built-in topic families ahead of dynamic metadata", () => {
		const decision = classifyWorkflowRoute("Donne-moi des idées de SaaS", {
			dynamicKnowledgeContext: {
				topics: ["finops"],
				query: "finops cloud cost",
				reason: "test dynamic context",
				command: "safe-test-command",
				source: "obvault-metadata",
			},
		});

		expect(decision.knowledgeContext).toMatchObject({
			topics: ["saas"],
			query:
				"saas opportunity product discovery buyer pain budget workflow validation",
		});
		expect(decision.knowledgeContext?.source).toBeUndefined();
	});

	test("routes destructive prompts to ops-stop", () => {
		expect(
			classifyWorkflowRoute("Supprime ce dossier de production"),
		).toMatchObject({
			route: "ops-stop",
			writeAllowed: false,
		});
		expect(
			classifyWorkflowRoute("Supprime définitivement ce dépôt et sa base de données."),
		).toMatchObject({
			route: "ops-stop",
			writeAllowed: false,
		});
	});

	test("resolves knowledge context for an answer route", () => {
		const decision = classifyWorkflowRoute("Donne-moi des idées de SaaS");

		expect(decision.route).toBe("answer");
		expect(decision.knowledgeContext?.topics).toContain("saas");
		expect(decision.knowledgeContext?.command).toContain(
			"~/work/obvault/_meta/obvault context",
		);
	});

	test("plan-loop suggestion points at the frontier pool, not a dead route (T4 F8)", () => {
		const decision = classifyWorkflowRoute("write a plan for the migration");
		expect(decision.route).toBe("plan-loop");
		expect(decision.suggestion).toContain("pool frontalier");
		expect(decision.suggestion).not.toContain("openai-codex");
	});
});
