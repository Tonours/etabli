import { expect, test } from "bun:test";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { fixture, until } from "./helpers.ts";
import { EtabliPlanDoc } from "../src/plan-doc.ts";
import { RunsDoc } from "../src/runs-doc.ts";
import { AgentDoc } from "@earendil-works/pi-durable";
import { reviewVerdict } from "../src/review.ts";
import { git } from "../src/change.ts";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";

test("native review preserves an explicit nonblocking Spec verdict rather than inventing BLOCK", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.faux.setResponses([
      fauxAssistantMessage(fauxToolCall("bash", { command: "printf fixture > result.txt" }), { stopReason: "toolUse" }),
      fauxAssistantMessage(fauxToolCall("review", { kind: "code" }), { stopReason: "toolUse" }),
      fauxAssistantMessage("fixture stops"),
    ]);
    const logic = "Findings\nNo findings.\n### Lens table\n| Lens | Checked (file:line) | Found |\n| precedence | result.txt:1 | no |\n### Deciding-code table\n| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |\n| result | result.txt:1 | none | pass |\nVerdict: GO\nSTATUS: complete";
    const spec = "Findings\nlow / result.txt / 1 / optional wording / no correctness impact / optional wording / keep as a note\nVerdict: GO WITH NOTES\nSTATUS: complete";
    const threat = `${["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map((heading) => `### ${heading}\nnone: fixture\n`).join("")}Verdict: GO\nSTATUS: complete`;
    f.planner.setResponses([logic, spec, threat, "Findings\nNo findings.\nVerdict: GO WITH NOTES\nSTATUS: complete"].map((text) => fauxAssistantMessage(text)));
    const run = await f.core.runs.submit("Tonours/fixture", "nonblocking review fixture", "spec-notes");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    const reviews = (await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))!.reviews;
    expect(reviews).toHaveLength(4);
    expect(reviews.find((receipt) => receipt.axis === "spec")?.body).toBe(spec);
    expect(reviews.find((receipt) => receipt.axis === "spec")?.verdict).toBe("GO WITH NOTES");
    expect(reviews.some((receipt) => receipt.verdict === "BLOCK")).toBe(false);
  } finally { await f.cleanup(); }
});

test("quoted No findings text cannot hide a nonempty Spec findings block", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.faux.setResponses([fauxAssistantMessage(fauxToolCall("bash", { command: "printf fixture > result.txt" }), { stopReason: "toolUse" }), fauxAssistantMessage(fauxToolCall("review", { kind: "code" }), { stopReason: "toolUse" }), fauxAssistantMessage("fixture stops")]);
    const logic = "### Lens table\n| Lens | Checked | Found |\n| precedence | result.txt:1 | no |\n### Deciding-code table\n| Changed behavior | Deciding code | Sibling | Result |\n| result | result.txt:1 | none | pass |\nVerdict: GO\nSTATUS: complete";
    const injected = 'Findings\nhigh / result.txt / 1 / wrong scope / material gap / report literally quotes "No findings." / fix the gap\nVerdict: BLOCK\nSTATUS: complete';
    const threat = `${["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map((heading) => `### ${heading}\nnone: fixture\n`).join("")}Verdict: GO\nSTATUS: complete`;
    f.planner.setResponses([logic, injected, threat, "Verdict: BLOCK\nSTATUS: complete"].map((text) => fauxAssistantMessage(text)));
    const run = await f.core.runs.submit("Tonours/fixture", "injected spec text", "spec-injection");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    expect((await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))?.reviews.find((receipt) => receipt.axis === "spec")?.verdict).toBe("BLOCK");
  } finally { await f.cleanup(); }
});

test("an unopened answer-route plan produces the publication gate error", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.faux.setResponses([
      fauxAssistantMessage(fauxToolCall("bash", { command: "printf fixture > result.txt && git add result.txt && git -c user.name=Fixture -c user.email=fixture@example.invalid commit -m 'finish fixture'" }), { stopReason: "toolUse" }),
      fauxAssistantMessage(fauxToolCall("publish", { title: "fixture", body: "## What\nFixture.\n## Why\nGate proof.\n## How to test\nFixture.\n" }), { stopReason: "toolUse" }), fauxAssistantMessage("fixture stops"),
    ]);
    const run = await f.core.runs.submit("Tonours/fixture", "unreviewed publication", "no-reviews");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    const conversation = await f.core.harness.conversation(run.conversationId, context);
    const output = (await conversation!.entries({ order: "ascending" }, 100, undefined, context)).items.flatMap((entry) => (entry.model ?? []).flatMap((message) => message.role === "toolResult" && message.toolName === "publish" ? message.content.flatMap((part) => part.type === "text" ? [part.text] : []) : []));
    expect(output.join("\n")).toContain("Publication requires complete independent reviews");
  } finally { await f.cleanup(); }
});

test("legacy conversations cannot enter a plan route that their review and publication tools refuse", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.faux.setResponses([fauxAssistantMessage(fauxToolCall("plan_begin", {}), { stopReason: "toolUse" }), fauxAssistantMessage("legacy fixture stops")]);
    f.planner.setResponses([fauxAssistantMessage("unexpected planner")]);
    const run = await f.core.runs.submit("Tonours/fixture", "legacy plan request", "legacy-plan");
    await f.core.harness.commit(async (tx) => { (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!.route = "legacy"; }, context);
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    expect((await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))?.enabled ?? false).toBe(false);
    expect((await f.core.harness.snapshot(AgentDoc, run.conversationId, context))?.model).toMatchObject({ provider: "zai", modelId: "glm-5.3" });
  } finally { await f.cleanup(); }
});

test("not run deciding-code rows cannot satisfy an independent Logic review", () => {
  const body = "### Lens table\n| Lens | Checked | Found |\n| precedence | result.txt:1 | no |\n### Deciding-code table\n| Changed behavior | Deciding code | Sibling | Result |\n| result | not run | none | pass |\nVerdict: GO\nSTATUS: complete";
  expect(() => reviewVerdict(body, "code", "logic")).toThrow("coverage");
});

test("editing a reviewed READY plan cannot retain implementation authority for unreviewed content", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.planner.setResponses([
      fauxAssistantMessage(fauxToolCall("plan_section", { section: "Goal", content: "reviewed goal" }), { stopReason: "toolUse" }),
      fauxAssistantMessage(fauxToolCall("review", { kind: "plan" }), { stopReason: "toolUse" }),
      fauxAssistantMessage(fauxToolCall("plan_status", { status: "READY" }), { stopReason: "toolUse" }), fauxAssistantMessage("fixture stops after replan"),
    ]);
    f.faux.setResponses([fauxAssistantMessage("Verdict: READY\nSTATUS: complete"), fauxAssistantMessage(fauxToolCall("plan_section", { section: "Goal", content: "unreviewed goal" }), { stopReason: "toolUse" }), fauxAssistantMessage("fixture stops")]);
    const run = await f.core.runs.submit("Tonours/fixture", "post-READY mutation", "ready-edit", "plan");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    const plan = (await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))!;
    expect(plan.reviews.some((receipt) => receipt.verdict === "READY")).toBe(true);
    expect(plan.status !== "READY" || plan.sections.Goal === "reviewed goal").toBe(true);
    if (plan.sections.Goal === "unreviewed goal") expect((await f.core.harness.snapshot(AgentDoc, run.conversationId, context))?.model).toMatchObject({ provider: "openai-codex", modelId: "gpt-6.1-sol" });
  } finally { await f.cleanup(); }
});

test("expiry after remote PR creation reconciles the URL without restarting publication", async () => {
  let now = 1000;
  let entered = false;
  let created = false;
  let head = "";
  let creates = 0;
  let release = () => {};
  const gate = new Promise<void>((resolve) => { release = resolve; });
  const f = await fixture({ workflow: true, wallMs: 10000, now: () => now, publishCommand: async (cwd, program, args) => {
    if (program === "git") {
      if (args[0] === "remote") return "https://github.com/Tonours/fixture.git";
      if (args[0] === "ls-remote") return "ref: refs/heads/main\tHEAD";
      if (args[0] === "push") { head = String(args[2]).split(":")[0]; return ""; }
      return git(cwd, args);
    }
    if (program === "gitleaks") return "";
    if (program === "gh" && args[1] === "list") return JSON.stringify(created ? [{ url: "https://github.com/Tonours/fixture/pull/1", headRefOid: head, baseRefName: "main", state: "OPEN", headRepositoryOwner: { login: "Tonours" } }] : []);
    if (program === "gh" && args[1] === "create") { creates++; created = true; entered = true; await gate; return "https://github.com/Tonours/fixture/pull/1"; }
    throw new Error("Unexpected publication command");
  } });
  let limiting: Promise<void> | undefined;
  try {
    const logic = "### Lens table\n| Lens | Checked | Found |\n| precedence | result.txt:1 | no |\n### Deciding-code table\n| Changed behavior | Deciding code | Sibling | Result |\n| result | result.txt:1 | none | pass |\nVerdict: GO\nSTATUS: complete";
    const threat = `${["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map((heading) => `### ${heading}\nnone: fixture\n`).join("")}Verdict: GO\nSTATUS: complete`;
    f.planner.setResponses([logic, "No findings.\nSTATUS: complete", threat, "Verdict: GO\nSTATUS: complete"].map((text) => fauxAssistantMessage(text)));
    f.faux.setResponses([
      fauxAssistantMessage(fauxToolCall("bash", { command: "printf fixture > result.txt && git add result.txt && git -c user.name=Fixture -c user.email=fixture@example.invalid commit -m 'finish fixture'" }), { stopReason: "toolUse" }),
      fauxAssistantMessage(fauxToolCall("review", { kind: "code" }), { stopReason: "toolUse" }),
      fauxAssistantMessage(fauxToolCall("publish", { title: "fixture", body: "## What\nFixture.\n## Why\nDeadline proof.\n## How to test\nFixture.\n" }), { stopReason: "toolUse" }),
    ]);
    const run = await f.core.runs.submit("Tonours/fixture", "publication deadline", "publish-deadline");
    await f.core.runs.tick(); await until(async () => entered);
    now = (await f.core.runs.show(run.id)).deadline + 1;
    limiting = f.core.runs.enforceLimits();
    await until(async () => (await f.core.runs.show(run.id)).status === "blocked");
    release(); await limiting; await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    expect((await f.core.runs.show(run.id)).reason).toBe("wall_clock_limit");
    expect((await f.core.runs.show(run.id)).url).toBe("https://github.com/Tonours/fixture/pull/1");
    expect(creates).toBe(1);
  } finally { release(); await limiting; await f.cleanup(); }
});

test("code review while DRAFT refuses before making any reviewer request", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.planner.setResponses([fauxAssistantMessage(fauxToolCall("review", { kind: "code" }), { stopReason: "toolUse" }), fauxAssistantMessage("unexpected continuation")]);
    const run = await f.core.runs.submit("Tonours/fixture", "DRAFT review request", "draft-review", "plan");
    await f.core.runs.repositories.prepare(run.id, run.repo, run.branch);
    await writeFile(join(run.worktree, "result.txt"), "fixture");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    expect(f.faux.state.callCount).toBe(0);
    expect((await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))?.reviews).toEqual([]);
    expect((await f.core.runs.show(run.id)).status).toBe("blocked");
  } finally { await f.cleanup(); }
});

test("independent final arbitration preserves raw hunter BLOCKs without consuming an effective BLOCK round", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.faux.setResponses([fauxAssistantMessage(fauxToolCall("bash", { command: "printf fixture > result.txt" }), { stopReason: "toolUse" }), ...Array.from({ length: 3 }, () => fauxAssistantMessage(fauxToolCall("review", { kind: "code" }), { stopReason: "toolUse" })), fauxAssistantMessage("fixture stops")]);
    const logic = "### Lens table\n| Lens | Checked | Found |\n| precedence | result.txt:1 | yes |\n### Deciding-code table\n| Changed behavior | Deciding code | Sibling | Result |\n| result | result.txt:1 | none | finding |\nVerdict: BLOCK\nSTATUS: complete";
    const threat = `${["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map((heading) => `### ${heading}\nnone: fixture\n`).join("")}Verdict: GO\nSTATUS: complete`;
    f.planner.setResponses(Array.from({ length: 3 }, () => [logic, "Findings\nNo findings.\nSTATUS: complete", threat, "Findings\nLogic finding refuted by opened deciding code result.txt:1; no unresolved candidate remains.\nVerdict: GO WITH NOTES\nSTATUS: complete"].map((text) => fauxAssistantMessage(text))).flat());
    const run = await f.core.runs.submit("Tonours/fixture", "arbitrated review fixture", "arbitrated");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    const receipts = (await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))?.reviews ?? [];
    expect(receipts).toHaveLength(12);
    expect(receipts.filter((receipt) => receipt.axis === "logic").every((receipt) => receipt.verdict === "BLOCK")).toBe(true);
    expect(f.faux.state.callCount).toBe(5);
    expect((await f.core.runs.show(run.id)).reason).not.toBe("review_block_limit");
  } finally { await f.cleanup(); }
});
