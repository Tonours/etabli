import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { AgentDoc } from "@earendil-works/pi-durable";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import type { TranscriptContext } from "@earendil-works/pi-ai";
import { CiDoc } from "../src/ci-doc.ts";
import { EtabliPlanDoc, type ReviewReceipt } from "../src/plan-doc.ts";
import { PublishDoc } from "../src/publish.ts";
import { RunsDoc } from "../src/runs-doc.ts";
import { ChildOwnerDoc } from "../src/guards.ts";
import { finalSnapshot } from "../src/backup.ts";
import { fixture } from "./helpers.ts";

const sha = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex");
const offered = (input: TranscriptContext) => [...new Set(input.messages.flatMap((message) => message.role === "system" ? (message.toolsAdded ?? []).map((tool) => tool.name) : []))].sort();
const call = (name: string, args: { task?: string; query?: string }) => fauxAssistantMessage(fauxToolCall(name, args), { stopReason: "toolUse" });

test("CI reactivation retains deferred tools and root guards with fresh task-owned workers", async () => {
  let time = 1000;
  const f = await fixture({ workflow: true, now: () => time, subagentModel: async () => ({ provider: "child", modelId: "child" }), mcpServers: { fixture: { command: process.execPath, args: [join(import.meta.dirname, "fixtures/mcp-server.ts")] } } });
  try {
    const child = fauxProvider({ provider: "child", models: [{ id: "child" }] });
    f.models.setProvider(child.provider);
    child.setResponses([fauxAssistantMessage("old worker answer")]);
    let beforeTools: string[] = [];
    f.faux.setResponses([
      call("tool_search", { query: "mcp__fixture__echo" }),
      async (input) => { beforeTools = offered(input); return call("worker", { task: "old owned worker" }); }, fauxAssistantMessage("old parent answer"),
    ]);
    const run = await f.core.runs.submit("Tonours/fixture", "CI owned subtree fixture", "ci-subagents");
    await f.core.harness.commit(async (tx) => { const plan = await tx.doc(EtabliPlanDoc, run.conversationId); plan.enabled = true; plan.status = "READY"; }, context);
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    const conversation = (await f.core.harness.conversation(run.conversationId, context))!;
    const oldSubmission = (await f.core.runs.show(run.id)).submissionId;
    const beforeAgent = await f.core.harness.snapshot(AgentDoc, run.conversationId, context);
    const oldChildren = (await f.core.harness.commit((tx) => tx.scanConversations({ ownerConversationId: run.conversationId }, 100), context)).items;
    expect(oldChildren).toHaveLength(1);
    const oldTranscript = JSON.stringify((await (await f.core.harness.conversation(oldChildren[0]!.id, context))!.entries({}, 100, undefined, context)).items);
    const graph = await f.core.harness.watchTaskGraph(context);
    try { expect(Object.keys(graph.value.tasks)).toHaveLength(0); } finally { await graph.stop(); }
    expect(beforeTools).toContain("mcp__fixture__echo");
    const publishedHead = execFileSync("git", ["-C", run.worktree, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
    expect(execFileSync("git", ["-C", run.worktree, "status", "--porcelain"], { encoding: "utf8" }).trim()).toBe("");
    const url = "https://github.com/Tonours/fixture/pull/1";
    const receipt = (kind: "plan" | "code"): ReviewReceipt => ({ kind, axis: "adversary", round: "fixture", sourceHash: "fixture", planHash: "fixture", authors: ["zai"], reviewer: { alias: "sol", family: "openai", provider: "openai-codex", modelId: "gpt-6.1-sol", transport: "native" }, verdict: kind === "plan" ? "READY" : "GO", body: "fixture", conversationId: run.conversationId });
    const planReceipt = receipt("plan");
    await f.core.harness.commit(async (tx) => {
      const stored = (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!;
      Object.assign(stored, { status: "done", reason: "published", notified: true, url });
      (await tx.doc(PublishDoc, run.conversationId)).head = publishedHead;
      (await tx.doc(EtabliPlanDoc, run.conversationId)).reviews = [planReceipt, receipt("code")];
    }, context);
    const archived = await finalSnapshot(f.state, run.id);
    const oldArchive = sha(await readFile(archived));
    expect((await stat(archived)).mode & 0o777).toBe(0o400);
    const input = "CI regression exact input";
    await f.core.harness.commit(async (tx) => {
      (await tx.doc(CiDoc)).runs.push({ runId: run.id, url, head: publishedHead, originalStartedAt: 1000, nextPollAt: 0, backoff: 60_000, retired: "", attempts: [{ number: 1, triggerHead: publishedHead, checks: [], input, requestId: `ci:${run.id}:1`, state: "reserved" }] });
    }, context);
    let afterTools: string[] = [];
    child.setResponses([
      fauxAssistantMessage([
        fauxToolCall("write", { path: "forbidden.ts", content: "// forbidden\n" }),
        fauxToolCall("bash", { command: "gh pr create --repo Tonours/fixture" }),
        fauxToolCall("bash", { command: "git push origin HEAD:fixture" }),
        fauxToolCall("write", { path: "ci-marker.txt", content: "new worker" }),
      ], { stopReason: "toolUse" }), fauxAssistantMessage("new worker answer"),
    ]);
    f.faux.setResponses([async (context) => { afterTools = offered(context); return call("worker", { task: "fresh CI owned worker" }); }, fauxAssistantMessage("new parent answer")]);
    time = 2000;
    expect(await f.core.runs.reactivateCi(run.id, 1)).toBe(true);
    const active = await f.core.runs.show(run.id);
    expect(active.conversationId).toBe(run.conversationId);
    expect(active.submissionId).not.toBe(oldSubmission);
    expect(active.status).toBe("implementing");
    expect(active.reason).toBe("");
    expect(active.notified).toBe(false);
    expect(active.startedAt).toBe(time);
    const afterAgent = await f.core.harness.snapshot(AgentDoc, run.conversationId, context);
    for (const key of ["extensions", "tools", "modelTools"] as const) expect(afterAgent?.[key]).toEqual(beforeAgent?.[key]);
    const plan = await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context);
    expect(plan?.status).toBe("READY");
    expect(plan?.reviews).toEqual([planReceipt]);
    expect(await f.core.harness.snapshot(PublishDoc, run.conversationId, context)).toEqual(PublishDoc.definition.initial());
    const attempt = (await f.core.harness.snapshot(CiDoc, context))?.runs.find((row) => row.runId === run.id)?.attempts[0];
    expect(attempt).toMatchObject({ number: 1, input, requestId: `ci:${run.id}:1`, state: "submitted" });
    await f.core.harness.waitForIdle(context);
    expect(afterTools).toEqual(beforeTools);
    const entries = (await conversation.entries({}, 100, undefined, context)).items;
    const delivered = entries.flatMap((entry) => (entry.model ?? []).filter((message) => message.role === "user" && message.content === input));
    expect(delivered).toHaveLength(1);
    const children = (await f.core.harness.commit((tx) => tx.scanConversations({ ownerConversationId: run.conversationId }, 100), context)).items;
    expect(children).toHaveLength(2);
    const fresh = children.find((record) => record.id !== oldChildren[0]!.id)!;
    expect(fresh.owner?.taskId).not.toBe(oldChildren[0]!.owner?.taskId);
    expect((await f.core.harness.snapshot(ChildOwnerDoc, fresh.id, context))?.parentId).toBe(run.conversationId);
    expect(JSON.stringify((await (await f.core.harness.conversation(oldChildren[0]!.id, context))!.entries({}, 100, undefined, context)).items)).toBe(oldTranscript);
    const newHistory = JSON.stringify((await (await f.core.harness.conversation(fresh.id, context))!.entries({}, 100, undefined, context)).items);
    expect(newHistory).toContain("no-comments:");
    expect(newHistory).toContain("reviewed publish tool");
    expect(await readFile(join(run.worktree, "ci-marker.txt"), "utf8")).toBe("new worker");
    expect(await readFile(join(run.worktree, "forbidden.ts"), "utf8").catch(() => "absent")).toBe("absent");
    expect(sha(await readFile(archived))).toBe(oldArchive);
    expect((await stat(archived)).mode & 0o777).toBe(0o400);
    const settled = await f.core.harness.watchTaskGraph(context);
    try { expect(Object.keys(settled.value.tasks)).toHaveLength(0); } finally { await settled.stop(); }
  } finally { await f.cleanup(); }
});

test("CI reactivation refuses a terminal row whose native owned subtree is still live", async () => {
  const f = await fixture({ workflow: true, subagentModel: async () => ({ provider: "child", modelId: "child" }) });
  try {
    const child = fauxProvider({ provider: "child", models: [{ id: "child" }] });
    f.models.setProvider(child.provider);
    let entered = false;
    child.setResponses([async (_input, options) => {
      entered = true;
      await new Promise<void>((resolve) => { if (options?.signal?.aborted) resolve(); else options?.signal?.addEventListener("abort", () => resolve(), { once: true }); });
      return fauxAssistantMessage("owner stopped");
    }]);
    f.faux.setResponses([call("worker", { task: "hold old owned subtree" })]);
    const run = await f.core.runs.submit("Tonours/fixture", "CI live subtree refusal", "ci-live-subtree");
    await f.core.runs.tick();
    const { until } = await import("./helpers.ts");
    await until(async () => entered);
    const current = await f.core.runs.show(run.id);
    const publishedHead = execFileSync("git", ["-C", run.worktree, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
    const url = "https://github.com/Tonours/fixture/pull/1";
    await f.core.harness.commit(async (tx) => {
      Object.assign((await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!, { status: "done", reason: "published", notified: true, url });
      (await tx.doc(PublishDoc, run.conversationId)).head = publishedHead;
    }, context);
    const archived = await finalSnapshot(f.state, run.id);
    const oldArchive = sha(await readFile(archived));
    await f.core.harness.commit(async (tx) => {
      (await tx.doc(CiDoc)).runs.push({ runId: run.id, url, head: publishedHead, originalStartedAt: current.startedAt, nextPollAt: 0, backoff: 60_000, retired: "", attempts: [{ number: 1, triggerHead: publishedHead, checks: [], input: "CI live refusal input", requestId: `ci:${run.id}:1`, state: "reserved" }] });
    }, context);
    expect(await f.core.runs.reactivateCi(run.id, 1)).toBe(false);
    expect((await f.core.runs.show(run.id)).submissionId).toBe(current.submissionId);
    const attempt = (await f.core.harness.snapshot(CiDoc, context))?.runs.find((row) => row.runId === run.id)?.attempts[0];
    expect(attempt?.state).toBe("reserved");
    const owned = (await f.core.harness.commit((tx) => tx.scanConversations({ ownerConversationId: run.conversationId }, 100), context)).items;
    expect(owned).toHaveLength(1);
    expect(sha(await readFile(archived))).toBe(oldArchive);
    await (await f.core.harness.conversation(run.conversationId, context))!.abort(context, { background: true });
    await f.core.harness.waitForIdle(context);
  } finally { await f.cleanup(); }
});
