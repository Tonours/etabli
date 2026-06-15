import { describe, expect, test } from "bun:test";
import { classifyWorkflowRoute as classifyPi, type WorkflowRoute } from "../lib/workflow-router-runtime.ts";

type ClaudeDecision = {
  route: string;
  writeAllowed: boolean;
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
  ];

  for (const prompt of prompts) {
    test(prompt, () => {
      const piDecision = classifyPi(prompt);
      const claudeDecision = classifyClaude(prompt);

      expect(equivalentRoute(claudeDecision.route)).toBe(piDecision.route);
      expect(claudeDecision.writeAllowed).toBe(piDecision.writeAllowed);
    });
  }
});
