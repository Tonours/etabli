import { expect, test } from "bun:test";
import { readFile, writeFile, mkdir, mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { AgentDoc, configure, type JsonObject, type ConversationId } from "@earendil-works/pi-durable";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { fixture, until } from "./helpers.ts";
import { subagentModel } from "../src/subagents.ts";
import { ChildOwnerDoc } from "../src/guards.ts";
import { EtabliPlanDoc } from "../src/plan-doc.ts";
import { RunsDoc } from "../src/runs-doc.ts";

const call = (name: string, args: JsonObject) => fauxAssistantMessage(fauxToolCall(name, args), { stopReason: "toolUse" });
const model = async (role: string) => ({ provider: "children", modelId: role });
async function transcript(f: Awaited<ReturnType<typeof fixture>>, id: ConversationId) {
  return JSON.stringify((await (await f.core.harness.conversation(id, context))!.entries({ order: "ascending" }, 100, undefined, context)).items);
}
async function children(f: Awaited<ReturnType<typeof fixture>>, parent: ConversationId) {
  return (await f.core.harness.commit((tx) => tx.scanConversations({}, 100), context)).items.filter((child) => child.owner?.conversationId === parent);
}
function provider(f: Awaited<ReturnType<typeof fixture>>) {
  const child = fauxProvider({ provider: "children", models: [{ id: "scout" }, { id: "worker" }] });
  f.models.setProvider(child.provider);
  return child;
}

test("scout is native read-only, task-owned, nonrecursive, and returns its actual answer", async () => {
  const f = await fixture({ subagentModel: model });
  try {
    const child = provider(f);
    let offered: string[] = [];
    child.setResponses([
      async (input) => { offered = input.messages.flatMap((message) => message.role === "system" ? (message.toolsAdded ?? []).map((tool) => tool.name) : []); return call("read", { path: "check.sh" }); },
      fauxAssistantMessage([fauxToolCall("write", { path: "forbidden", content: "bad" }), fauxToolCall("bash", { command: "touch forbidden" }), fauxToolCall("worker", { task: "recursive" }), fauxToolCall("mcp__alambic_obvault__vault_capture", {})], { stopReason: "toolUse" }),
      fauxAssistantMessage("scout actual answer"),
    ]);
    f.faux.setResponses([call("scout", { task: "inspect check.sh" }), fauxAssistantMessage("parent done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "delegate scout", "scout");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    const owned = await children(f, run.conversationId);
    expect(owned).toHaveLength(1);
    expect(owned[0]!.owner?.taskId).toBeDefined();
    expect(offered).toEqual(["read"]);
    const agent = await f.core.harness.snapshot(AgentDoc, owned[0]!.id, context);
    expect(agent?.extensions).toEqual(["coding-tools", "etabli-guards"]);
    expect(agent?.maxTurns).toBe(32);
    expect(agent?.cwd).toBe(run.worktree);
    expect((await f.core.harness.snapshot(ChildOwnerDoc, owned[0]!.id, context))?.parentId).toBe(run.conversationId);
    expect(await transcript(f, run.conversationId)).toContain("scout actual answer");
    expect(await readFile(join(run.worktree, "forbidden"), "utf8").catch(() => "absent")).toBe("absent");
    expect(await transcript(f, owned[0]!.id)).toContain("not available");
  } finally { await f.cleanup(); }
});

test("worker actual write/edit/bash paths inherit guards and reviewed publication policy", async () => {
  const f = await fixture({ workflow: true, subagentModel: model });
  try {
    const child = provider(f);
    let offered: string[] = [];
    child.setResponses([
      async (input) => { offered = input.messages.flatMap((message) => message.role === "system" ? (message.toolsAdded ?? []).map((tool) => tool.name) : []); return fauxAssistantMessage([
        fauxToolCall("write", { path: "plain.ts", content: "export const value = 1;\n" }),
        fauxToolCall("write", { path: "comment.ts", content: "// forbidden\n" }),
        fauxToolCall("bash", { command: "git push origin HEAD:fixture" }),
        fauxToolCall("bash", { command: "gh pr create --repo Tonours/fixture" }),
        fauxToolCall("bash", { command: "gh pr merge 1" }),
        fauxToolCall("bash", { command: "git status --porcelain" }),
        fauxToolCall("worker", { task: "recursive worker" }),
      ], { stopReason: "toolUse" }); },
      call("edit", { path: "plain.ts", edits: [{ oldText: "export const value = 1;", newText: "// forbidden\nexport const value = 2;" }] }),
      fauxAssistantMessage("worker actual answer"),
    ]);
    f.faux.setResponses([call("worker", { task: "implement fixture" }), fauxAssistantMessage("parent done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "delegate worker", "worker");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    const owned = await children(f, run.conversationId);
    expect(offered.sort()).toEqual(["bash", "edit", "read", "write"]);
    expect(await readFile(join(run.worktree, "plain.ts"), "utf8")).toBe("export const value = 1;\n");
    const text = await transcript(f, owned[0]!.id);
    expect(text).toContain("no-comments:");
    expect(text).toContain("reviewed publish tool");
    expect(text).toContain("PR merge is forbidden");
    expect(text).toContain("Tool worker is not available");
    const history = (await (await f.core.harness.conversation(owned[0]!.id, context))!.entries({ order: "ascending" }, 100, undefined, context)).items;
    expect(history.flatMap((entry) => (entry.model ?? []).filter((message) => message.role === "toolResult" && message.toolName === "bash" && !message.isError))).toHaveLength(1);
    expect(await transcript(f, run.conversationId)).toContain("worker actual answer");
  } finally { await f.cleanup(); }
});

for (const failure of ["DRAFT", "CHALLENGED", "terminal", "missing", "cycle", "unresolved"] as const) test(`worker mutation rechecks parent authority: ${failure}`, async () => {
  const f = await fixture({ subagentModel: model });
  try {
    const child = provider(f);
    const run = await f.core.runs.submit("Tonours/fixture", "recheck", `recheck-${failure}`);
    child.setResponses([async () => {
      const owned = await children(f, run.conversationId);
      await f.core.harness.commit(async (tx) => {
        if (failure === "terminal") (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!.status = "blocked";
        else if (failure === "missing") await tx.retireDoc(ChildOwnerDoc, owned[0]!.id);
        else if (failure === "cycle") (await tx.doc(ChildOwnerDoc, owned[0]!.id)).parentId = owned[0]!.id;
        else if (failure === "unresolved") {
          const ownerless = await tx.createConversation({ ownership: { kind: "ownerless" } });
          (await tx.doc(ChildOwnerDoc, owned[0]!.id)).parentId = ownerless.id;
        } else { const plan = await tx.doc(EtabliPlanDoc, run.conversationId); plan.enabled = true; plan.status = failure; }
      }, context);
      return fauxAssistantMessage([fauxToolCall("read", { path: "check.sh" }), fauxToolCall("write", { path: "no-write", content: "bad" }), fauxToolCall("edit", { path: "check.sh", edits: [{ oldText: "test", newText: "false" }] }), fauxToolCall("bash", { command: "touch no-bash" })], { stopReason: "toolUse" });
    }, fauxAssistantMessage("denials observed")]);
    f.faux.setResponses([call("worker", { task: "mutate after authority changes" }), fauxAssistantMessage("parent done")]);
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    const owned = await children(f, run.conversationId);
    const text = await transcript(f, owned[0]!.id);
    expect(text).toContain(failure === "terminal" ? "run is terminal" : ["DRAFT", "CHALLENGED"].includes(failure) ? "parent plan requires READY" : "parent run is unresolved");
    const reads = (await (await f.core.harness.conversation(owned[0]!.id, context))!.entries({}, 100, undefined, context)).items.flatMap((entry) => (entry.model ?? []).flatMap((message) => message.role === "toolResult" && message.toolName === "read" ? [message.isError] : []));
    expect(reads).toHaveLength(1);
    expect(reads[0]).toBe(failure === "terminal");
    expect(await readFile(join(run.worktree, "no-write"), "utf8").catch(() => "absent")).toBe("absent");
    expect(await readFile(join(run.worktree, "no-bash"), "utf8").catch(() => "absent")).toBe("absent");
    expect(await readFile(join(run.worktree, "check.sh"), "utf8")).toBe("test -f result.txt\n");
  } finally { await f.cleanup(); }
});

test("enabled DRAFT rejects worker admission while scout and READY/disabled-plan neighbors work", async () => {
  const f = await fixture({ subagentModel: model });
  try {
    const child = provider(f);
    child.setResponses([fauxAssistantMessage("scout during plan"), call("write", { path: "ready.txt", content: "ready" }), fauxAssistantMessage("ready worker")]);
    const run = await f.core.runs.submit("Tonours/fixture", "plan neighbors", "neighbors");
    await f.core.harness.commit(async (tx) => { const plan = await tx.doc(EtabliPlanDoc, run.conversationId); plan.enabled = true; plan.status = "DRAFT"; }, context);
    f.faux.setResponses([
      call("worker", { task: "denied" }), call("scout", { task: "permitted" }),
      async () => { await f.core.harness.commit(async (tx) => { (await tx.doc(EtabliPlanDoc, run.conversationId)).status = "READY"; }, context); return call("worker", { task: "permitted ready" }); }, fauxAssistantMessage("parent done"),
    ]);
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    expect(await transcript(f, run.conversationId)).toContain("Worker requires parent plan READY");
    expect((await children(f, run.conversationId)).length).toBe(2);
    expect(await readFile(join(run.worktree, "ready.txt"), "utf8")).toBe("ready");
  } finally { await f.cleanup(); }
});

test("one challenged run cannot revoke a READY sibling worker's authority", async () => {
  const f = await fixture({ subagentModel: model });
  try {
    const child = provider(f);
    child.setResponses([call("write", { path: "sibling.txt", content: "ready sibling" }), fauxAssistantMessage("sibling answer")]);
    const challenged = await f.core.runs.submit("Tonours/fixture", "challenged parent", "sibling-challenged");
    const ready = await f.core.runs.submit("Tonours/fixture", "ready parent", "sibling-ready");
    await f.core.harness.commit(async (tx) => {
      for (const [id, status] of [[challenged.conversationId, "CHALLENGED"], [ready.conversationId, "READY"]] as const) {
        const plan = await tx.doc(EtabliPlanDoc, id); plan.enabled = true; plan.status = status;
      }
    }, context);
    const parent = async (input: import("@earendil-works/pi-ai").TranscriptContext) => input.messages.some((message) => message.role === "toolResult" && message.toolName === "worker") ? fauxAssistantMessage("parent done") : call("worker", { task: "write sibling.txt" });
    f.faux.setResponses(Array.from({ length: 4 }, () => parent));
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    expect(await children(f, challenged.conversationId)).toHaveLength(0);
    expect(await children(f, ready.conversationId)).toHaveLength(1);
    expect(await readFile(join(ready.worktree, "sibling.txt"), "utf8")).toBe("ready sibling");
    expect(await readFile(join(challenged.worktree, "sibling.txt"), "utf8").catch(() => "absent")).toBe("absent");
  } finally { await f.cleanup(); }
});

test("owner abort reaches child and settles the native task graph", async () => {
  const f = await fixture({ subagentModel: model });
  try {
    const child = provider(f);
    let entered = false;
    child.setResponses([async (_input, options) => { entered = true; await new Promise<void>((resolve) => { if (options?.signal?.aborted) resolve(); else options?.signal?.addEventListener("abort", () => resolve(), { once: true }); }); return fauxAssistantMessage("aborted"); }]);
    f.faux.setResponses([call("worker", { task: "wait for abort" })]);
    const run = await f.core.runs.submit("Tonours/fixture", "cancel", "cancel");
    await f.core.runs.tick(); await until(async () => entered);
    const graph = await f.core.harness.watchTaskGraph(context);
    graph.start(async () => {});
    try {
      expect(Object.keys(graph.value.tasks).length).toBeGreaterThan(0);
      await f.core.runs.abort(run.id);
      await f.core.harness.waitForIdle(context);
      await until(async () => Object.keys(graph.value.tasks).length === 0);
      expect(Object.keys(graph.value.tasks)).toHaveLength(0);
      expect((await f.core.runs.show(run.id))?.status).toBe("aborted");
    } finally { graph.stop(); }
  } finally { await f.cleanup(); }
});

test("canonical scout route is cheap/native and invalid providers fail without fallback", async () => {
  expect(await subagentModel(join(import.meta.dirname, "../.."), "scout")).toEqual({ provider: "zai", modelId: "glm-5.3-flash" });
  const root = await mkdtemp(join(tmpdir(), "durable-scout-route-"));
  try {
    await mkdir(join(root, "workflow/runtime"), { recursive: true });
    for (const provider of [undefined, "foreign"]) {
      await writeFile(join(root, "workflow/runtime/model-routing.json"), JSON.stringify({ models: { glm_flash: { provider, family: "zai", model: "cheap" } }, durable: { native_routes: { glm: { provider: "zai" } } } }));
      await expect(subagentModel(root, "scout")).rejects.toThrow("unavailable");
    }
  } finally { await rm(root, { recursive: true, force: true }); }
});


test("explicit ownerless sentinel permits a native bash control without a run", async () => {
  const f = await fixture();
  try {
    const raw = await f.core.harness.commit(async (tx) => {
      const record = await tx.createConversation({ ownership: { kind: "ownerless" } });
      await configure(tx, record.id, { cwd: f.source, model: { provider: "fixture", modelId: "fixture" } });
      return record;
    }, context);
    f.faux.setResponses([call("bash", { command: "true" }), fauxAssistantMessage("ownerless control")]);
    const conversation = (await f.core.harness.conversation(raw.id, context))!;
    await (await conversation.submit({ type: "input", content: "control", requestId: "ownerless-control" }, context)).wait(context);
    expect((await f.core.harness.snapshot(ChildOwnerDoc, raw.id, context))?.parentId).toBeNull();
    const results = (await conversation.entries({}, 100, undefined, context)).items.flatMap((entry) => (entry.model ?? []).filter((message) => message.role === "toolResult"));
    expect(results).toHaveLength(1);
    expect(results[0]!.isError).toBe(false);
  } finally { await f.cleanup(); }
});
