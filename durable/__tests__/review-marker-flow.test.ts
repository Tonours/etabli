import { expect, test } from "bun:test";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { fixture } from "./helpers.ts";
import { EtabliPlanDoc } from "../src/plan-doc.ts";

const logic = "### Lens table\n| Lens | Result |\n| result.txt:1 | checked |\n### Deciding-code table\n| Code | Result |\n| result.txt:1 | checked |\nVerdict: GO\nSTATUS: complete";
const threat = ["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map(heading => `### ${heading}\nfixture checked\n`).join("") + "Verdict: GO\nSTATUS: complete";
const ambiguous = "Verdict: BLOCK\n\nVerdict: GO\nSTATUS: complete";

for (const recovers of [false, true]) {
  test(`native code adversary ${recovers ? "retries on astra" : "exhausts both routes without partial receipts"}`, async () => {
    const f = await fixture({ workflow: true });
    try {
      f.faux.setResponses([
        fauxAssistantMessage(fauxToolCall("bash", { command: "printf fixture > result.txt" }), { stopReason: "toolUse" }),
        fauxAssistantMessage(fauxToolCall("review", { kind: "code" }), { stopReason: "toolUse" }),
        fauxAssistantMessage("fixture done"),
      ]);
      f.planner.setResponses([logic, "Findings\nNo findings.\nSTATUS: complete", threat, ambiguous, recovers ? "Verdict: GO\nSTATUS: complete" : ambiguous].map(body => fauxAssistantMessage(body)));
      const run = await f.core.runs.submit("Tonours/fixture", "native parser correction", `marker-code-${recovers}`);
      await f.core.runs.tick();
      await f.core.harness.waitForIdle(context);
      const plan = await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context);
      const reviews = plan?.reviews ?? [];
      expect(f.planner.state.callCount).toBe(5);
      if (recovers) {
        expect(reviews).toHaveLength(4);
        expect(reviews.find(receipt => receipt.axis === "adversary")?.reviewer.modelId).toBe("gpt-6-astra");
        expect(reviews.some(receipt => receipt.body === ambiguous)).toBe(false);
        expect((await f.core.runs.show(run.id)).status).not.toBe("blocked");
      } else {
        expect(plan).toBeUndefined();
        expect(reviews).toEqual([]);
        expect(await f.core.runs.show(run.id)).toMatchObject({ status: "blocked", reason: "review_unavailable_or_invalid" });
        expect(f.faux.state.callCount).toBe(2);
      }
    } finally { await f.cleanup(); }
  });
}

for (const valid of [false, true]) {
  test(`native plan ${valid ? "control stores one receipt" : "ambiguity blocks without READY authority"}`, async () => {
    const f = await fixture({ workflow: true });
    try {
      f.planner.setResponses([
        fauxAssistantMessage(fauxToolCall("review", { kind: "plan" }), { stopReason: "toolUse" }),
        fauxAssistantMessage("fixture done"),
      ]);
      f.faux.setResponses([fauxAssistantMessage(valid ? "Verdict: READY\n\nSTATUS: complete" : "Verdict: CHALLENGED\n\nVerdict: READY\nSTATUS: complete")]);
      const run = await f.core.runs.submit("Tonours/fixture", "native plan parser correction", `marker-plan-${valid}`, "plan");
      await f.core.runs.tick();
      await f.core.harness.waitForIdle(context);
      const plan = (await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))!;
      expect(f.faux.state.callCount).toBe(1);
      expect(plan.reviews).toHaveLength(valid ? 1 : 0);
      if (valid) expect(plan.reviews[0].verdict).toBe("READY");
      else {
        expect(plan.status).not.toBe("READY");
        expect(await f.core.runs.show(run.id)).toMatchObject({ status: "blocked", reason: "review_unavailable_or_invalid" });
        expect(f.planner.state.callCount).toBe(1);
      }
    } finally { await f.cleanup(); }
  });
}
