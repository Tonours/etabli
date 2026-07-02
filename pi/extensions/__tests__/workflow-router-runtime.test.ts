import { describe, expect, test } from "bun:test";
import {
  appendWorkflowRouterGuidance,
  classifyWorkflowRoute,
  shouldInjectWorkflowRouter,
} from "../lib/workflow-router-runtime.ts";

describe("workflow router runtime", () => {
  test("does not trust prompt wording alone for READY plan implementation", () => {
    expect(classifyWorkflowRoute("Implémente le PLAN.md ready")).toMatchObject({
      route: "plan-implement",
      reason: "implementation request mentions a READY plan, but actual PLAN.md status is not proven READY",
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
    expect(classifyWorkflowRoute("Résume le PLAN.md ready", { planStatus: "ready" })).toMatchObject({
      route: "answer",
      writeAllowed: false,
    });
  });

  test("routes actual READY plan implementation to implement", () => {
    expect(classifyWorkflowRoute("Implémente le PLAN.md ready", { planStatus: "ready" })).toMatchObject({
      route: "implement",
      planChain: {
        currentPlanStatus: "ready",
        currentPhase: "ready_to_implement",
        nextRoute: "implement",
      },
    });
  });

  test("routes autonomous plan-loop requests through plan-implement", () => {
    expect(classifyWorkflowRoute("Lance le plan-loop en autonomie jusqu'au bout")).toMatchObject({
      route: "plan-implement",
      reason: "autonomous plan-loop request",
      stopCondition: "READY plan implemented, verified/reviewed, archived, and root PLAN.md deleted; or CHALLENGED/blocked with evidence",
      planChain: {
        currentPhase: "planning",
        nextRoute: "plan-loop",
      },
    });
  });

  test("routes implementation without ready plan to plan-implement", () => {
    const decision = classifyWorkflowRoute("Corrige tout y compris les warnings");

    expect(decision).toMatchObject({
      route: "plan-implement",
      skill: "plan-implement",
      requiredEvidence: "actual root PLAN.md Status: READY before implementation, adversary evidence, focused validation, review evidence, docs/plan archive, root PLAN.md deletion, and final handoff",
      writeAllowed: true,
    });
  });

  test("routes adversarial plan review to adversary", () => {
    expect(classifyWorkflowRoute("Fais une passe adversary sur le PLAN.md")).toMatchObject({
      route: "adversary",
      skill: "adversary",
      writeAllowed: true,
      stopCondition: "plan remains READY, becomes CHALLENGED, or adversary blocker is reported",
    });
  });

  test("does not route adversarial code review to plan adversary", () => {
    expect(classifyWorkflowRoute("fais une code-review complète puis une code-review adversary")).toMatchObject({
      route: "review",
      skill: "review",
      writeAllowed: false,
    });
  });

  test("keeps explicitly read-only adversarial plan review read-only", () => {
    expect(classifyWorkflowRoute("Read-only adversarial PLAN.md review. Do not edit files.")).toMatchObject({
      route: "review",
      skill: "review",
      writeAllowed: false,
      reason: "read-only adversarial review request",
    });
  });

  test("routes reviews and verification as read-only", () => {
    expect(classifyWorkflowRoute("Fais une review de notre roadmap")).toMatchObject({
      route: "review",
      writeAllowed: false,
    });
    expect(classifyWorkflowRoute("Retest et prouve que c'est fini")).toMatchObject({
      route: "verify",
      writeAllowed: false,
    });
  });

  test("routes Linear ticket creation and Linear work to dedicated skills", () => {
    expect(classifyWorkflowRoute("Crée un ticket Linear pour ce bug de login")).toMatchObject({
      route: "linear-ticket-create",
      skill: "linear-ticket-create",
      writeAllowed: true,
    });

    expect(classifyWorkflowRoute("Peux-tu créer un ticket Linear pour corriger le bug de login")).toMatchObject({
      route: "linear-ticket-create",
      skill: "linear-ticket-create",
      writeAllowed: true,
    });

    expect(classifyWorkflowRoute("Corrige le bug décrit dans Linear LIN-123")).toMatchObject({
      route: "linear-work",
      skill: "linear-work",
      writeAllowed: true,
    });

    expect(classifyWorkflowRoute("Résume le ticket Linear LIN-123")).toMatchObject({
      route: "answer",
      writeAllowed: false,
    });
  });

  test("routes Linear bug analysis to bug-check", () => {
    expect(classifyWorkflowRoute("Analyse le bug Linear PRD-387 sans coder")).toMatchObject({
      route: "bug-check",
      skill: "bug-check",
      writeAllowed: false,
    });
  });

  test("routes GitHub PR reviews through gh-specific review", () => {
    expect(classifyWorkflowRoute("Fais une code review de la PR GitHub 42")).toMatchObject({
      route: "pr-review",
      skill: "pr-review",
      writeAllowed: false,
    });
  });

  test("routes PR QA, security PR, and explicit CI fix", () => {
    expect(classifyWorkflowRoute("Comment tester la PR GitHub 42 ?")).toMatchObject({
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
    expect(classifyWorkflowRoute("Fais un fact-check sourcé via recherche web")).toMatchObject({
      route: "research-plan",
      artifact: "cited document under docs/",
    });
  });

  test("routes destructive prompts to ops-stop", () => {
    expect(classifyWorkflowRoute("Supprime ce dossier de production")).toMatchObject({
      route: "ops-stop",
      writeAllowed: false,
    });
  });

  test("does not inject for slash commands", () => {
    expect(shouldInjectWorkflowRouter("/skill:implement")).toBe(false);
    expect(shouldInjectWorkflowRouter("implémente")).toBe(true);
  });

  test("appends route guidance once", () => {
    const decision = classifyWorkflowRoute("Fais un plan");
    const first = appendWorkflowRouterGuidance("Base prompt", decision);
    const second = appendWorkflowRouterGuidance(first, decision);

    expect(first).toContain("# Etabli Workflow Router");
    expect(first).toContain("Route: plan-loop");
    expect(second).toBe(first);
  });
});
