import { describe, expect, test } from "bun:test";
import { classifyWorkflowRoute as classifyPi, type WorkflowRoute } from "../lib/workflow-router-runtime.ts";

type ClaudeDecision = {
  route: string;
  stopCondition: string;
  requiredEvidence: string;
  writeAllowed: boolean;
  planChain?: {
    currentPlanStatus: string;
    currentPhase: string;
    nextRoute: string;
    requiredEvidence: string[];
  };
};

const { classifyWorkflowRoute: classifyClaude } = await import("../../../claude/hooks/workflow-router-lib.mjs") as {
  classifyWorkflowRoute(prompt: string): ClaudeDecision;
};

function equivalentRoute(route: string): WorkflowRoute | string {
  return route === "verify-workflow" ? "verify" : route;
}

describe("Pi and Claude workflow router alignment", () => {
  const prompts = [
    "Fais une review de notre roadmap",
    "Retest et prouve que tout passe",
    "Implémente le PLAN.md ready",
    "Résume le PLAN.md ready",
    "Lance le plan-loop en autonomie jusqu'au bout",
    "Fais une passe adversary sur le PLAN.md",
    "fais une code-review complète puis une code-review adversary",
    "Read-only adversarial PLAN.md review. Do not edit files.",
    "Peux-tu créer un ticket Linear pour corriger le bug de login",
    "Résume le ticket Linear LIN-123",
    "Analyse le bug Linear PRD-387 sans coder",
    "Corrige le bug décrit dans Linear LIN-123",
    "Fais une code review de la PR GitHub 42",
    "Comment tester la PR GitHub 42 ?",
    "Audite la PR Dependabot #1606",
    "fix CI and push PR #42",
    "remove this folder",
    "Fais une recherche web sourcée sur les pratiques agentiques",
    "Corrige le bug de login et valide",
  ];

  for (const prompt of prompts) {
    test(prompt, () => {
      const piDecision = classifyPi(prompt);
      const claudeDecision = classifyClaude(prompt);

      expect(equivalentRoute(claudeDecision.route)).toBe(piDecision.route);
      expect(claudeDecision.writeAllowed).toBe(piDecision.writeAllowed);
    });
  }

  // Pure planning (no review/verify/autonomous verbs) must route to plan-loop in
  // both adapters. This is the only prompt that exercises the plan-loop branch
  // shared across harnesses, so it guards drift on the planning route.
  test("Fais un plan de refactor", () => {
    expect(equivalentRoute(classifyClaude("Fais un plan de refactor").route)).toBe(
      classifyPi("Fais un plan de refactor").route,
    );
    expect(classifyPi("Fais un plan de refactor").route).toBe("plan-loop");
  });

  // The READY gate is the most drift-prone routing decision: only an actual
  // READY PLAN.md authorizes `implement`. Both adapters must agree when
  // planStatus is proven READY, and must NOT route to implement otherwise.
  test("READY plan implementation gate aligns across harnesses", () => {
    const readyPi = classifyPi("Implémente le PLAN.md ready", { planStatus: "ready" });
    const readyClaude = classifyClaude("Implémente le PLAN.md ready", { planStatus: "ready" });
    expect(equivalentRoute(readyClaude.route)).toBe(readyPi.route);
    expect(readyPi.route).toBe("implement");

    const missingPi = classifyPi("Implémente le PLAN.md ready", { planStatus: "missing" });
    const missingClaude = classifyClaude("Implémente le PLAN.md ready", { planStatus: "missing" });
    expect(equivalentRoute(missingClaude.route)).toBe(missingPi.route);
    expect(missingPi.route).not.toBe("implement");
    expect(missingClaude.stopCondition).toBe(missingPi.stopCondition);
    expect(missingClaude.requiredEvidence).toBe(missingPi.requiredEvidence);
    expect(missingClaude.planChain).toEqual(missingPi.planChain);
  });

  test("autonomous plan-loop chain metadata aligns across harnesses", () => {
    const prompt = "Lance le plan-loop en autonomie jusqu'au bout";
    const piDecision = classifyPi(prompt, { planStatus: "missing" });
    const claudeDecision = classifyClaude(prompt, { planStatus: "missing" });

    expect(equivalentRoute(claudeDecision.route)).toBe(piDecision.route);
    expect(claudeDecision.stopCondition).toBe(piDecision.stopCondition);
    expect(claudeDecision.requiredEvidence).toBe(piDecision.requiredEvidence);
    expect(claudeDecision.planChain).toEqual(piDecision.planChain);
  });
});
