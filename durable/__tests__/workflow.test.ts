import { expect, test } from "bun:test";
import { stat, readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { AgentDoc } from "@earendil-works/pi-durable";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { fixture } from "./helpers.ts";
import { dispatch } from "../src/daemon.ts";
import { EtabliPlanDoc } from "../src/plan-doc.ts";
import { RunsDoc } from "../src/runs-doc.ts";
import { git } from "../src/change.ts";

const call = (name: string, args: Record<string, string>) => fauxAssistantMessage(fauxToolCall(name, args), { stopReason: "toolUse" });
const report = (axis: string, verdict = "GO") => `Findings\nNo findings.\n${axis === "logic" ? "### Open questions\nNone.\n### Lens table\n| Lens | Checked (file:line) | Found |\n| precedence | result.txt:1 | no |\n### Deciding-code table\n| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |\n| result | result.txt:1 | none | pass |\n" : axis === "threat" ? ["Deciding inputs", "Entry-point inventory", "Reused guards", "Deferrals", "Rollout", "Attack tests"].map((name) => `### ${name}\nnone: fixture\n`).join("") : ""}Verdict: ${verdict}\nSTATUS: complete`;

test("plan-route native tools persist DRAFT, review in an owned fresh child and switch the very next request to GLM", async () => {
  const f = await fixture({ workflow: true });
  let firstModel = "";
  let afterReady = "";
  try {
    f.planner.setResponses([
      async (_input, _options, _state, model) => { firstModel = `${model.provider}/${model.id}`; return call("plan_section", { section: "Goal", content: "Produce a fixture." }); },
      call("review", { kind: "plan" }), call("plan_status", { status: "READY" }),
    ]);
    f.faux.setResponses([fauxAssistantMessage(report("adversary", "READY")), async (_input, _options, _state, model) => { afterReady = `${model.provider}/${model.id}`; return fauxAssistantMessage("stop fixture without publishing"); }]);
    const run = await f.core.runs.submit("Tonours/fixture", "native plan fixture", "native-plan", "plan");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    const plan = await dispatch(f.core, { op: "plan", id: run.id }) as { status: string; reviews: { conversationId: number }[] };
    expect(plan.status).toBe("READY");
    expect(firstModel).toBe("openai-codex/gpt-6.1-sol");
    expect(afterReady).toBe("zai/glm-5.3");
    expect(plan.reviews).toHaveLength(1);
    const child = await f.core.harness.conversation(plan.reviews[0].conversationId as typeof run.conversationId, context);
    const record = await f.core.harness.commit((tx) => tx.conversation(child!.id), context);
    expect(record?.owner?.conversationId).toBe(run.conversationId);
    expect(record?.owner?.taskId).toBeNumber();
    expect(record?.parent).toBeUndefined();
    const childAgent = await f.core.harness.snapshot(AgentDoc, child!.id, context);
    expect(childAgent?.model).toMatchObject({ provider: "zai", modelId: "glm-5.3" });
    expect(childAgent?.tools).toEqual(["read"]);
    expect(childAgent?.modelTools).toEqual(["read"]);
    expect(await stat(join(run.worktree, "PLAN.md")).then(() => true, () => false)).toBe(false);
    expect(await readdir(join(run.worktree, "docs/plan")).catch(() => [])).toEqual([]);
    await f.core.runs.tick();
    expect((await f.core.runs.show(run.id)).reason).toBe("workflow_finished_without_publication");
    await f.reopen();
    expect((await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))?.status).toBe("READY");
  } finally { await f.cleanup(); }
});

test("three BLOCK rounds on the same code pin block without a fourth parent request", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.faux.setResponses([call("bash", { command: "printf finished > result.txt" }), ...Array.from({ length: 3 }, () => call("review", { kind: "code" }))]);
    f.planner.setResponses(Array.from({ length: 3 }, () => ["logic", "spec", "threat", "adversary"].map((axis) => fauxAssistantMessage(report(axis, axis === "adversary" ? "BLOCK" : "GO")))).flat());
    const run = await f.core.runs.submit("Tonours/fixture", "review rounds", "three-block");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    expect(await f.core.runs.show(run.id)).toMatchObject({ status: "blocked", reason: "review_block_limit" });
    const plan = await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context);
    expect(plan?.reviews).toHaveLength(12);
    expect(new Set(plan?.reviews.map((receipt) => receipt.round)).size).toBe(3);
    expect(f.faux.state.callCount).toBe(4);
    expect(plan?.reviews.every((receipt) => receipt.reviewer.family === "openai" && receipt.authors.join() === "zai")).toBe(true);
  } finally { await f.cleanup(); }
});

test("recorded Astra escalation and a CHALLENGED review route back to the planner", async () => {
  const f = await fixture({ workflow: true });
  const observed: string[] = [];
  try {
    f.planner.setResponses([
      call("plan_escalate", { reason: "Resolve a difficult planning assumption" }),
      async (_input, _options, _state, model) => { observed.push(model.id); return call("review", { kind: "plan" }); },
      async (_input, _options, _state, model) => { observed.push(model.id); return fauxAssistantMessage("fixture stops after challenged plan"); },
    ]);
    f.faux.setResponses([fauxAssistantMessage(report("adversary", "CHALLENGED"))]);
    const run = await f.core.runs.submit("Tonours/fixture", "planner escalation", "escalation", "plan");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    expect(observed).toEqual(["gpt-6-astra", "gpt-6.1-sol"]);
    expect(await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context)).toMatchObject({ status: "CHALLENGED", escalation: "Resolve a difficult planning assumption" });
  } finally { await f.cleanup(); }
});

test("mixed native author history selects only CLI Opus and records its task-owned review children", async () => {
  const observed: string[] = [];
  const f = await fixture({ workflow: true, reviewCli: async (input) => { observed.push(input.modelId); const axis = /^Axis: (\w+)/.exec(input.prompt)?.[1] ?? ""; return { body: report(axis), provider: "anthropic", modelId: input.modelId, tools: ["Read", "Grep", "Glob"] }; } });
  try {
    f.planner.setResponses([call("plan_section", { section: "Goal", content: "mixed authors" }), call("review", { kind: "plan" }), call("plan_status", { status: "READY" })]);
    f.faux.setResponses([fauxAssistantMessage(report("adversary", "READY")), call("bash", { command: "printf mixed > result.txt" }), call("review", { kind: "code" }), fauxAssistantMessage("fixture ends")]);
    const run = await f.core.runs.submit("Tonours/fixture", "mixed authors", "mixed", "plan");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    const plan = await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context);
    expect(observed).toEqual(Array(4).fill("claude-opus-5-5"));
    expect(plan?.reviews.slice(1).every((receipt) => receipt.authors.join() === "openai,zai" && receipt.reviewer.family === "anthropic" && receipt.reviewer.transport === "cli")).toBe(true);
    for (const receipt of plan!.reviews.slice(1)) {
      const child = await f.core.harness.conversation(receipt.conversationId, context);
      const record = await f.core.harness.commit((tx) => tx.conversation(child!.id), context);
      expect(record?.owner?.conversationId).toBe(run.conversationId);
      expect(record?.owner?.taskId).toBeNumber();
      expect(record?.parent).toBeUndefined();
      expect((await f.core.harness.snapshot(AgentDoc, receipt.conversationId, context))?.tools).toEqual([]);
      expect((await child!.entries({ order: "ascending" }, 10, undefined, context)).items.some((entry) => entry.kind === "etabli.cli-review")).toBe(true);
    }
  } finally { await f.cleanup(); }
});

test("reviewed workflow publishes its branch, persists URL and notifies once across reopen", async () => {
  let creates = 0;
  let pushes = 0;
  let publishedHead = "";
  const notifyArgv: string[] = [];
  const f = await fixture({ workflow: true, notifyArgv, publishCommand: async (cwd, program, args) => {
    if (program === "git") {
      if (args[0] === "remote") return "https://github.com/Tonours/fixture.git";
      if (args[0] === "ls-remote") return "ref: refs/heads/main\tHEAD";
      if (args[0] === "push") { pushes++; publishedHead = String(args[2]).split(":")[0]; return ""; }
      return git(cwd, args);
    }
    if (program === "gitleaks") return "";
    if (program === "gh" && args[1] === "list") return JSON.stringify(creates ? [{ url: "https://github.com/Tonours/fixture/pull/1", headRefOid: publishedHead, baseRefName: "main", state: "OPEN", headRepositoryOwner: { login: "Tonours" } }] : []);
    if (program === "gh" && args[1] === "create") { creates++; return "https://github.com/Tonours/fixture/pull/1"; }
    throw new Error("Unexpected publication command");
  } });
  notifyArgv.push(process.execPath, "-e", `require('node:fs').appendFileSync(${JSON.stringify(join(f.root, "notify.jsonl"))},JSON.stringify(process.argv.slice(1))+'\\n')`);
  try {
    f.faux.setResponses([
      call("bash", { command: "printf finished > result.txt && git add result.txt && git -c user.name=Fixture -c user.email=fixture@example.invalid commit -m 'finish fixture'" }),
      call("review", { kind: "code" }),
      call("publish", { title: "finish fixture", body: "## What\nAdds a fixture.\n\n## Why\nVerifies publication.\n\n## How to test\nRun check.sh.\n" }),
    ]);
    f.planner.setResponses(["logic", "spec", "threat", "adversary"].map((axis) => fauxAssistantMessage(report(axis))));
    const run = await f.core.runs.submit("Tonours/fixture", "publish end to end", "publish-e2e");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    expect(await f.core.runs.show(run.id)).toMatchObject({ status: "done", reason: "published", url: "https://github.com/Tonours/fixture/pull/1", notified: true });
    expect(creates).toBe(1);
    expect(pushes).toBe(1);
    expect(f.faux.state.callCount).toBe(3);
    const archived = await readFile(join(f.state, "final", `${run.id}.sqlite`));
    expect((await stat(join(f.state, "final", `${run.id}.sqlite`))).mode & 0o777).toBe(0o400);
    await f.reopen();
    await f.core.runs.tick();
    const notifications = (await readFile(join(f.root, "notify.jsonl"), "utf8")).trim().split("\n").map((line) => JSON.parse(line));
    expect(notifications).toHaveLength(1);
    expect(notifications[0]).toContain("https://github.com/Tonours/fixture/pull/1");
    expect(creates).toBe(1);
    expect(await readFile(join(f.state, "final", `${run.id}.sqlite`))).toEqual(archived);
  } finally { await f.cleanup(); }
});

test("unavailable eligible review blocks, and direct publication cannot replace the review tool", async () => {
  const f = await fixture({ workflow: true, reviewCli: async () => { throw new Error("CLI unavailable in this fixture"); } });
  try {
    f.models.deleteProvider("openai-codex");
    f.faux.setResponses([call("bash", { command: "printf fixture > result.txt" }), call("review", { kind: "code" })]);
    const run = await f.core.runs.submit("Tonours/fixture", "unavailable reviewer", "unavailable");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    expect(await f.core.runs.show(run.id)).toMatchObject({ status: "blocked", reason: "review_unavailable_or_invalid" });
  } finally { await f.cleanup(); }
});

for (const stored of ["new", "existing"] as const) {
  test(`${stored} run retries preserve admission after promotion and reopening`, async () => {
    const f = await fixture({ workflow: true });
    const admission = { op: "run", repo: "Tonours/fixture", prompt: "Promote this request", requestId: "promoted", route: "answer" };
    try {
      f.faux.setResponses([call("plan_begin", {})]);
      f.planner.setResponses([fauxAssistantMessage("The plan is drafted.")]);
      const run = await f.core.runs.submit(admission.repo, admission.prompt, admission.requestId);
      if (stored === "existing") {
        await f.core.harness.commit(async (tx) => { delete (await tx.doc(RunsDoc)).runs[0].admissionRoute; }, context);
      }
      await f.core.runs.tick();
      await f.core.harness.waitForIdle(context);
      expect((await f.core.runs.show(run.id)).route).toBe("plan");

      await f.reopen();
      const retries = await Promise.all([dispatch(f.core, admission), dispatch(f.core, admission)]);
      for (const retry of retries) expect(retry).toMatchObject({ id: run.id, route: "plan" });
      await expect(dispatch(f.core, { ...admission, route: "plan" })).rejects.toThrow("different input");
      await expect(dispatch(f.core, { ...admission, prompt: "Other input" })).rejects.toThrow("different input");
      await expect(dispatch(f.core, { ...admission, repo: "Tonours/another" })).rejects.toThrow("different input");
      expect(await f.core.runs.list()).toHaveLength(1);

      await f.core.harness.commit(async (tx) => { delete (await tx.doc(RunsDoc)).runs[0].admissionRoute; }, context);
      await expect(dispatch(f.core, admission)).rejects.toThrow("different input");
      expect(await dispatch(f.core, { ...admission, route: "plan" })).toMatchObject({ id: run.id });
    } finally { await f.cleanup(); }
  });
}

test("a root planner can discover files but only mutates code in READY", async () => {
  const f = await fixture({ workflow: true });
  try {
    f.planner.setResponses([
      fauxAssistantMessage([
        fauxToolCall("bash", { command: "ls -1" }, { id: "draft-list" }),
        fauxToolCall("bash", { command: "grep -rlF -- 'test -f result.txt' ." }, { id: "draft-search" }),
        fauxToolCall("write", { path: "draft.txt", content: "draft" }),
        fauxToolCall("edit", { path: "check.sh", edits: [{ oldText: "result.txt", newText: "draft.txt" }] }),
        fauxToolCall("bash", { command: "touch draft-shell.txt" }),
        fauxToolCall("bash", { command: "git fetch origin" }, { id: "draft-fetch" }),
      ], { stopReason: "toolUse" }),
      call("plan_section", { section: "Goal", content: "Make a READY fixture." }),
      call("review", { kind: "plan" }),
      call("plan_status", { status: "READY" }),
      fauxAssistantMessage([
        fauxToolCall("read", { path: "check.sh" }),
        fauxToolCall("bash", { command: "touch challenged.txt" }),
      ], { stopReason: "toolUse" }),
      fauxAssistantMessage("Replan complete."),
    ]);
    f.faux.setResponses([
      fauxAssistantMessage(report("adversary", "READY")),
      call("write", { path: "ready.txt", content: "written\n" }),
      fauxAssistantMessage(fauxToolCall("edit", { path: "ready.txt", edits: [{ oldText: "written", newText: "edited" }] }), { stopReason: "toolUse" }),
      call("bash", { command: "touch ready-shell.txt" }),
      call("plan_section", { section: "Goal", content: "Revise the reviewed goal." }),
    ]);
    const run = await f.core.runs.submit("Tonours/fixture", "Exercise root phase gates", "root-gates", "plan");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);

    const conversation = (await f.core.harness.conversation(run.conversationId, context))!;
    const entries = (await conversation.entries({ order: "ascending" }, 100, undefined, context)).items;
    const rendered = JSON.stringify(entries);
    const toolResults = entries.flatMap((entry) => entry.model ?? []).filter((message) => message.role === "toolResult");
    const results = toolResults.filter((result) => !result.isError);
    expect(toolResults.find((result) => result.toolCallId === "draft-fetch")).toMatchObject({
      isError: true,
      content: expect.arrayContaining([expect.objectContaining({ text: expect.stringContaining("durable guard: plan requires READY") })]),
    });
    for (const toolCallId of ["draft-list", "draft-search"]) {
      expect(results.find((result) => result.toolCallId === toolCallId)?.content).toEqual(
        expect.arrayContaining([expect.objectContaining({ text: expect.stringContaining("check.sh") })]),
      );
    }
    expect(results.some((result) => result.toolName === "read" &&
      result.content.some((part) => part.type === "text" && part.text.includes("test -f result.txt")),
    )).toBe(true);
    expect(rendered).toContain("durable guard: plan requires READY");
    expect((await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))?.status).toBe("CHALLENGED");
    for (const path of ["draft.txt", "draft-shell.txt", "challenged.txt"]) {
      await expect(stat(join(run.worktree, path))).rejects.toMatchObject({ code: "ENOENT" });
    }
    expect(await readFile(join(run.worktree, "check.sh"), "utf8")).toContain("result.txt");
    expect(await readFile(join(run.worktree, "ready.txt"), "utf8")).toBe("edited\n");
    expect((await stat(join(run.worktree, "ready-shell.txt"))).isFile()).toBe(true);
  } finally { await f.cleanup(); }
});
