import { expect, test } from "bun:test";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { AgentDoc } from "@earendil-works/pi-durable";
import { changePlanStatus, EtabliPlanDoc, phaseModel, planHash, reviewCandidates, startPlan, templateSections } from "../src/plan-doc.ts";
import { fixture } from "./helpers.ts";

const checkout = resolve(import.meta.dir, "../..");

test("phase models and mixed-author review routes come from the shared registry", async () => {
  expect(await phaseModel(checkout, "planner")).toMatchObject({ provider: "openai-codex", modelId: "gpt-6.1-sol" });
  expect(await phaseModel(checkout, "implementer")).toMatchObject({ provider: "zai", modelId: "glm-5.3" });
  expect(await phaseModel(checkout, "escalation")).toMatchObject({ provider: "openai-codex", modelId: "gpt-6-astra" });
  expect(await reviewCandidates(checkout, ["openai", "zai"])).toEqual([expect.objectContaining({ alias: "opus", family: "anthropic", transport: "cli" })]);
  expect((await reviewCandidates(checkout, ["openai"]))[0].alias).toBe("glm");
  expect((await reviewCandidates(checkout, ["zai"])).map((route) => route.alias)).toEqual(["sol", "astra"]);
  await expect(reviewCandidates(checkout, [])).rejects.toThrow("provenance");
  await expect(reviewCandidates(checkout, ["unknown"])).rejects.toThrow("provenance");
});

test("native plan document persists independently of files and gates READY on current review", async () => {
  const f = await fixture();
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "plan fixture", "plan-doc");
    const sections = await templateSections(checkout);
    expect(Object.keys(sections)).toContain("Acceptance Criteria");
    await f.core.harness.commit((tx) => startPlan(tx, run.conversationId, sections, { provider: "fixture", modelId: "fixture" }), context);
    const plan = (await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))!;
    expect(plan.status).toBe("DRAFT");
    await expect(f.core.harness.commit((tx) => changePlanStatus(tx, run.conversationId, "READY", { provider: "fixture", modelId: "fixture" }, ["openai"]), context)).rejects.toThrow("current plan");
    const reviewer = (await reviewCandidates(checkout, ["openai"]))[0];
    await f.core.harness.commit(async (tx) => {
      const value = await tx.doc(EtabliPlanDoc, run.conversationId);
      value.reviews.push({ kind: "plan", axis: "adversary", round: "fixture", sourceHash: planHash(value), planHash: planHash(value), authors: ["openai"], reviewer, verdict: "READY", body: "READY", conversationId: run.conversationId });
      await changePlanStatus(tx, run.conversationId, "READY", { provider: "fixture", modelId: "fixture" }, ["openai"]);
    }, context);
    await f.reopen();
    expect((await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))?.status).toBe("READY");
    expect((await f.core.harness.snapshot(AgentDoc, run.conversationId, context))?.model).toEqual({ provider: "fixture", modelId: "fixture" });
    await f.core.harness.commit(async (tx) => { (await tx.doc(EtabliPlanDoc, run.conversationId)).sections.Goal = "changed after review"; }, context);
    await expect(f.core.harness.commit((tx) => changePlanStatus(tx, run.conversationId, "READY", { provider: "fixture", modelId: "fixture" }, ["openai"]), context)).rejects.toThrow("current plan");
    expect(await readFile(resolve(f.root, "PLAN.md"), "utf8").catch(() => "absent")).toBe("absent");
  } finally { await f.cleanup(); }
});
