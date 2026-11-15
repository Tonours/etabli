import { expect, test } from "bun:test";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { LiveDoc, type ConversationView, type ConversationId, type EntryId } from "@earendil-works/pi-durable";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { Text, visibleWidth } from "@earendil-works/pi-tui";
import { stat } from "node:fs/promises";
import { join } from "node:path";
import { TuiModel, age, safe, lines } from "../tui/model.ts";
import { SafeInput, tui } from "../tui/app.ts";
import { serve } from "../src/api.ts";
import { request, watchRun } from "../src/client.ts";
import { fixture, until } from "./helpers.ts";

test("native sanitizers protect server text and pasted drafts without losing Unicode layout", () => {
  const hostile = "é\u001b]52;c;Y2xpcA==\u0007好\u001b[2J\u0000\u009b";
  expect(safe(hostile)).not.toMatch(/[\u0000-\u001f\u007f-\u009f]/);
  expect(safe(hostile)).toContain("é好");
  expect(lines(`first\r\n${hostile}\nlast`)).toStartWith("first\n");
  const input = new SafeInput();
  input.handleInput(`\u001b[200~${hostile}\u001b[201~`);
  expect(input.getValue()).not.toMatch(/[\u0000-\u001f\u007f-\u009f]/);
  for (const width of [4, 9, 40]) for (const row of new Text(lines(hostile), 0, 0).render(width)) expect(visibleWidth(row)).toBeLessThanOrEqual(width);
  expect(age(0, 59_000)).toBe("59s");
  expect(age(0, 60_000)).toBe("1m");
  expect(age(0, 3_600_000)).toBe("1h");
});

test("recent window deduplicates, stays bounded, and uses before rather than contiguous ids for gaps", () => {
  const model = new TuiModel("unused", undefined, () => {});
  const view = (ids: number[], before?: number) => ({ conversation: { id: 1 as ConversationId }, entries: ids.map((id) => ({ id: id as EntryId, conversationId: 1 as ConversationId, kind: "fixture" })), before: before as EntryId | undefined, docs: {} }) satisfies ConversationView;
  model.merge(view([2, 10]));
  model.merge(view([10, 20], 2));
  expect(model.entries.map((entry) => Number(entry.id))).toEqual([2, 10, 20]);
  expect(model.gap).toBe(false);
  expect(model.omitted).toBe(false);
  model.merge(view([], 20));
  expect(model.omitted).toBe(false);
  model.merge(view([50], 40));
  expect(model.gap).toBe(true);
  expect(model.transcript()).toContain("Entries missed");
  model.merge(view(Array.from({ length: 120 }, (_, i) => 60 + i)));
  expect(model.entries).toHaveLength(100);
  expect(Number(model.entries[0].id)).toBe(80);
  expect(model.transcript()).toContain("Earlier entries omitted");
  model.close();
});

test("list polling cannot erase an action failure or turn a refresh failure into an action retry", async () => {
  const f = await fixture();
  let server = await serve(f.core, f.state);
  const model = new TuiModel(f.state, undefined, () => {});
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "action errors", "action-errors");
    await model.refresh();
    model.selectedId = run.id;
    model.runs = model.runs.map(row => ({ ...row, status: "implementing" }));
    model.begin("steer");
    model.targetId = "00000000-0000-0000-0000-000000000000";
    model.draft = "keep the unsent draft";
    await model.send();
    expect(model.error).toContain("Request failed");
    expect(model.draft).toBe("keep the unsent draft");
    await model.refresh();
    expect(model.error).toContain("Request failed");
    expect(model.draft).toBe("keep the unsent draft");
    model.cancel();
    expect(model.error).toBe("");
    model.runs = model.runs.map(row => ({ ...row, status: "implementing" }));
    model.begin("steer");
    await server.shutdown();
    await model.refresh();
    expect(model.error).not.toContain("Request failed");
    expect(model.actionError).toBe("");
    expect(model.refreshError).toContain("Cannot refresh");
    server = await serve(f.core, f.state);
    await model.refresh();
    expect(model.error).toBe("");
  } finally { model.close(); await server.shutdown(); await f.cleanup(); }
});

test("visible transcript hides thinking/system payloads and sanitizes live tool progress", () => {
  const model = new TuiModel("unused", undefined, () => {});
  const message = fauxAssistantMessage("visible answer");
  message.content.push({ type: "thinking", thinking: "hidden reasoning" });
  model.entries = [{ id: 2 as EntryId, conversationId: 1 as ConversationId, kind: "fixture", model: [{ role: "system", content: "hidden system", timestamp: 0 }, message] }];
  model.docs = { "pi.live": { tools: [{ name: "bash\u001b[2J", status: "running", output: "working\u0007" }], generation: { message: { role: "assistant", content: [{ type: "text", text: "partial text" }] } } } };
  const visible = model.transcript();
  expect(visible).toContain("visible answer");
  expect(visible).toContain("partial text");
  expect(visible).toContain("tool bash: running");
  expect(visible).not.toContain("hidden");
  expect(visible).not.toMatch(/[\u0000-\u0009\u000b-\u001f\u007f-\u009f]/);
  model.close();
});

test("native model/client follows a busy run, steers once, cancels abort and confirms the captured target", async () => {
  const f = await fixture();
  const server = await serve(f.core, f.state);
  const model = new TuiModel(f.state, undefined, () => {});
  try {
    f.faux.setResponses([
      fauxAssistantMessage(fauxToolCall("bash", { command: "printf started > started; sleep 0.3; printf finished" }), { stopReason: "toolUse" }),
      async (_input, options) => {
        await new Promise<void>((resolve) => options?.signal?.addEventListener("abort", () => resolve(), { once: true }));
        return fauxAssistantMessage("aborted");
      },
    ]);
    const run = await f.core.runs.submit("Tonours/fixture", "TUI busy run", "tui-first");
    await f.core.runs.tick();
    await until(() => stat(join(run.worktree, "started")).then(() => true, () => false));
    const other = await f.core.runs.submit("Tonours/fixture", "leave this queued", "tui-other");
    await model.refresh();
    model.select(run.id);
    await until(async () => model.status === "Live" && model.transcript().includes("TUI busy run"));
    model.begin("steer");
    model.draft = "steer from actual TUI model";
    await Promise.all([model.send(), model.send()]);
    await until(async () => model.transcript().includes("steer from actual TUI model"));
    const contents = model.entries.map((entry) => JSON.stringify(entry));
    expect(contents.filter((entry) => entry.includes("steer from actual TUI model"))).toHaveLength(1);
    const tool = model.entries.findIndex((entry) => entry.kind === "pi.tool-result");
    expect(tool).toBeGreaterThanOrEqual(0);
    expect(contents.findIndex((entry) => entry.includes("steer from actual TUI model"))).toBeGreaterThan(tool);
    model.begin("abort");
    model.cancel();
    expect((await f.core.runs.show(run.id)).status).toBe("implementing");
    expect((await f.core.harness.snapshot(LiveDoc, run.conversationId, context))?.run).toBeDefined();
    model.begin("abort");
    model.runs = [...model.runs].reverse();
    await model.send();
    expect((await f.core.runs.show(run.id)).status).toBe("aborted");
    expect((await f.core.runs.show(other.id)).status).toBe("queued");
    expect((await f.core.harness.snapshot(LiveDoc, run.conversationId, context))?.run).toBeUndefined();
    model.close();
    const graph = await f.core.harness.watchTaskGraph(context);
    expect(Object.values(graph.value.tasks).filter((task) => task.conversationId === run.conversationId)).toHaveLength(0);
    await graph.stop();
  } finally { model.close(); await server.shutdown(); await f.cleanup(); }
});

test("empty and disconnected list, selection races, terminal state and quit do not mutate a run", async () => {
  const f = await fixture();
  let server = await serve(f.core, f.state);
  const model = new TuiModel(f.state, undefined, () => {});
  const watches: AbortController[] = [];
  try {
    await model.refresh();
    expect(model.runs).toHaveLength(0);
    model.cancel();
    expect(model.mode).toBe("list");
    const first = await f.core.runs.submit("Tonours/fixture", "first distinct prompt", "first");
    const second = await f.core.runs.submit("Tonours/fixture", "second distinct prompt", "second");
    await model.refresh();
    model.select(first.id);
    model.select(second.id);
    await until(async () => model.status === "Live");
    expect(model.selectedId).toBe(second.id);
    model.begin("steer");
    expect(model.mode).toBe("run");
    model.begin("abort");
    expect(model.mode).toBe("abort");
    model.cancel();
    await server.shutdown();
    await until(async () => model.status.startsWith("Disconnected"));
    await model.refresh();
    expect(model.error).toContain("Cannot refresh");
    server = await serve(f.core, f.state);
    await until(async () => model.status === "Live");
    model.close();
    expect((await f.core.runs.show(second.id)).status).toBe("queued");
    const controller = new AbortController(); watches.push(controller);
    let seen = false;
    await watchRun(f.state, second.id, undefined, undefined, controller.signal, () => { seen = true; }, () => {});
    await until(async () => seen);
    controller.abort();
    expect(await request(f.state, { op: "abort", id: second.id })).toEqual({ aborted: true });
    const terminal = new TuiModel(f.state, undefined, () => {});
    await terminal.refresh();
    terminal.selectedId = second.id;
    terminal.begin("abort");
    expect(terminal.mode).toBe("list");
    terminal.close();
  } finally { watches.forEach((c) => c.abort()); model.close(); await server.shutdown(); await f.cleanup(); }
});

test("headless TUI refuses before network or terminal mutation; remote watch keeps origin checks", async () => {
  await expect(tui("does-not-exist")).rejects.toThrow("interactive terminal");
  const controller = new AbortController();
  await expect(watchRun("unused", "unused", undefined, { host: "http://example.invalid", tokenFile: "not-read" }, controller.signal, () => {}, () => {})).rejects.toThrow("HTTPS origin");
  await expect(watchRun("unused", "unused", undefined, { host: "https://example.invalid/path", tokenFile: "not-read" }, controller.signal, () => {}, () => {})).rejects.toThrow("HTTPS origin");
});
