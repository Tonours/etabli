import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { classifyWorkflowRoute as classifyPi, type WorkflowRoute } from "../lib/workflow-router-runtime.ts";

type ClaudeDecision = {
  route: string;
  artifact: string;
  stopCondition: string;
  requiredEvidence: string;
  writeAllowed: boolean;
  planChain?: {
    currentPlanStatus: string;
    currentPhase: string;
    nextRoute: string;
    requiredEvidence: string[];
  };
  knowledgeContext?: {
    topics: string[];
    query: string;
    reason: string;
    command: string;
  };
};

const { classifyWorkflowRoute: classifyClaude } = await import("../../../workflow/runtime/workflow-router-core.mjs") as {
  classifyWorkflowRoute(prompt: string, context?: { planStatus?: string }): ClaudeDecision;
};

const fixtures = JSON.parse(
  readFileSync(new URL("../../../tests/router-evals/core.json", import.meta.url), "utf8"),
) as Array<{ prompt: string; context?: { planStatus?: "missing" | "draft" | "challenged" | "ready" | "unknown" } }>;

function equivalentRoute(route: string): WorkflowRoute | string {
  return route === "verify-workflow" ? "verify" : route;
}

function normalizeDecision(decision: ClaudeDecision) {
  return {
    route: equivalentRoute(decision.route),
    artifact: decision.artifact,
    stopCondition: decision.stopCondition.replace(/Verdict: /g, ""),
    requiredEvidence: decision.requiredEvidence,
    writeAllowed: decision.writeAllowed,
    planChain: decision.planChain ?? null,
    knowledgeContext: decision.knowledgeContext ?? null,
  };
}

describe("Pi and Claude workflow router alignment", () => {
  for (const fixture of fixtures) {
    test(fixture.prompt, () => {
      const context = fixture.context;
      const piDecision = classifyPi(fixture.prompt, context);
      const claudeDecision = classifyClaude(fixture.prompt, context);

      expect(normalizeDecision(claudeDecision)).toEqual(normalizeDecision(piDecision));
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
