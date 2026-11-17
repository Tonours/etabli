import { expect, test } from "bun:test";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { LiveDoc, type ConversationView, type ConversationId, type EntryId } from "@earendil-works/pi-durable";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { Text, visibleWidth } from "@earendil-works/pi-tui";
import { stat } from "node:fs/promises";
import { join } from "node:path";
import { TuiModel, listView, safe, lines } from "../tui/model.ts";
import { age } from "../shared/runs-view.ts";
import type { Run } from "../src/runs-doc.ts";
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
  expect(age(0, 47 * 3_600_000)).toBe("47h");
  expect(age(0, 72 * 3_600_000)).toBe("3d");
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
    expect(model.notice).toBe("Instruction queued");
    await until(async () => model.entries.some((entry) => JSON.stringify(entry).includes("steer from actual TUI model")));
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

const HOUR = 3_600_000;
const NOW = 1_000 * HOUR;
const row = (id: string, status: Run["status"], extra: Partial<Run> = {}): Run => ({ id: id.padEnd(36, "0"), requestId: id, repo: "Tonours/fixture", prompt: `prompt ${id}`, conversationId: 1 as ConversationId, branch: "b", worktree: "w", route: "plan", status, reason: "", url: "", createdAt: NOW - HOUR, startedAt: NOW - HOUR, deadline: 0, maxTurns: 64, submissionId: "", notified: false, ...extra });
const plain = (line: { text: string }[]) => line.map((part) => part.text).join("");

test("list view groups rows in display order, aligns columns, pairs tone with a glyph and shows the detail line", () => {
  const runs = [
    row("done-old", "done", { reason: "published", createdAt: NOW - 100 * HOUR, startedAt: NOW - 100 * HOUR }),
    row("busy", "implementing", { repo: "o/r" }),
    row("blocked", "blocked", { reason: "ci_attempts_exhausted", url: "https://github.com/Tonours/fixture/pull/7", createdAt: NOW - 3 * HOUR, startedAt: NOW - 3 * HOUR }),
    row("web", "blocked", { reason: "model_error", url: "http://example.test/x" }),
  ];
  const view = listView(runs, runs[2].id, NOW);
  const text = view.lines.map(plain);
  expect(text[0]).toBe("2 need you · 1 working · 0 queued");
  expect(text.filter((line) => /\(\d\)$/.test(line))).toEqual(["Needs you (2)", "In progress (1)", "Finished (1)"]);
  const rows = text.filter((line) => line.includes("prompt"));
  expect(rows.map((line) => line.indexOf("prompt"))).toEqual(rows.map(() => rows[0].indexOf("prompt")));
  expect(rows).toHaveLength(4);
  expect(text[view.selectedLine].startsWith(">")).toBe(true);
  expect(text[view.selectedLine]).toContain("! CI failing");
  expect(text.findIndex((line) => line.startsWith(">"))).toBe(view.selectedLine);
  expect(text.find((line) => line.includes("PR opened"))).toContain("4d");
  expect(text.find((line) => line.includes("PR opened"))).toContain("✓ PR opened");
  expect(view.lines[view.selectedLine][1].tone).toBe("alert");
  expect(view.detail).toEqual(["CI still fails after the repair attempts. Fix the checks on the pull request.", "https://github.com/Tonours/fixture/pull/7"]);
  const http = listView(runs, runs[3].id, NOW).detail;
  expect(http).toHaveLength(1);
  expect(http.join("\n")).not.toContain("example.test");
  expect(listView([], "", NOW).lines).toEqual([]);
});

test("refresh keeps the display order and Up/Down walk it across groups", async () => {
  const f = await fixture();
  const server = await serve(f.core, f.state);
  const model = new TuiModel(f.state, undefined, () => {});
  try {
    const older = await f.core.runs.submit("Tonours/fixture", "older queued", "order-older");
    const newer = await f.core.runs.submit("Tonours/fixture", "newer queued", "order-newer");
    await model.refresh();
    expect(model.runs.map((run) => run.id)).toEqual([older.id, newer.id]);
    expect(model.selectedId).toBe(older.id);
    model.move(1);
    expect(model.selectedId).toBe(newer.id);
    model.move(1);
    expect(model.selectedId).toBe(newer.id);
    model.move(-1);
    expect(model.selectedId).toBe(older.id);
  } finally { model.close(); await server.shutdown(); await f.cleanup(); }
});

test("run view: header, tool argument summary, queued instructions, ended wording and state-aware hints", () => {
  const model = new TuiModel("unused", undefined, () => {});
  const live = row("live", "implementing", { deadline: Date.now() + 90 * 60_000 });
  model.runs = [live];
  model.selectedId = live.id;
  model.mode = "run";
  model.status = "Live";
  const call = fauxAssistantMessage("");
  call.content = [{ type: "toolCall", id: "t", name: "bash", arguments: { command: "x".repeat(300) } }];
  model.entries = [{ id: 2 as EntryId, conversationId: 1 as ConversationId, kind: "fixture", model: [call] }];
  model.docs = { "pi.live": { run: { turns: 3 } }, "pi.agent": { maxTurns: 64 }, "pi.inbox": { items: [{ mode: "write", content: "internal" }, { mode: "steer", content: "use bun" }, { mode: "followUp", content: [{ type: "text", text: "then lint" }] }] } };
  const text = model.transcript();
  expect(text).toMatch(/\[tool bash \{"command":"x{20,}…\]/);
  expect(text).not.toContain("x".repeat(121));
  expect(text).toContain("Instruction queued: use bun");
  expect(text).toContain("Instruction queued: then lint");
  expect(text).not.toContain("internal");
  expect(model.header().join("\n")).toMatch(/Implementing .* Live\nTurn 3 of 64 · 1h (29|30)m left/);
  expect(model.hints()).toContain("s steer · a abort");
  model.docs = {};
  expect(model.queued()).toEqual([]);
  expect(model.transcript()).not.toContain("Instruction queued");
  const blocked = row("blocked", "blocked", { reason: "turn_limit", url: "https://github.com/o/r/pull/1" });
  model.runs = [blocked];
  model.selectedId = blocked.id;
  model.entries = [];
  expect(model.transcript()).toBe("Nothing was recorded for this run.");
  const header = model.header().join("\n");
  expect(header).toContain("! Out of turns");
  expect(header).toContain("Finished");
  expect(header).not.toContain("Live");
  expect(header).toContain("https://github.com/o/r/pull/1");
  expect(header).not.toContain("left");
  for (const status of ["done", "blocked", "aborted"] as const) {
    model.runs = [row("ended", status)];
    model.selectedId = model.runs[0].id;
    expect(model.hints()).not.toMatch(/steer|abort/);
    model.begin("steer");
    model.begin("abort");
    expect(model.mode).toBe("run");
  }
  model.runs = [row("wait", "queued")];
  model.selectedId = model.runs[0].id;
  expect(model.hints()).toContain("a abort");
  expect(model.hints()).not.toContain("steer");
  model.close();
});

test("a run that ends during steer or abort returns to run mode, keeps the draft and drops the controls", async () => {
  const f = await fixture();
  const server = await serve(f.core, f.state);
  const model = new TuiModel(f.state, undefined, () => {});
  try {
    for (const mode of ["steer", "abort"] as const) {
      const target = await f.core.runs.submit("Tonours/fixture", `ends while ${mode}`, `ends-${mode}`);
      await model.refresh();
      model.selectedId = target.id;
      model.mode = mode;
      model.draft = "unsent words";
      await request(f.state, { op: "abort", id: target.id });
      await model.refresh();
      expect<string>(model.mode).toBe("run");
      expect(model.keepInput).toBe(true);
      expect(model.draft).toBe("unsent words");
      expect(model.hints()).not.toMatch(/steer|abort/);
      expect(model.transcript()).toContain("Unsent instruction (the run ended): unsent words");
      if (mode === "steer") {
        model.mode = "steer";
        model.targetId = target.id;
        await model.send();
        expect(model.error).toBe("Not delivered: the run ended. Your message is kept below.");
        expect(model.draft).toBe("unsent words");
        model.mode = "run";
      }
      model.cancel();
      expect<string>(model.mode).toBe("list");
      expect(model.draft).toBe("");
    }
  } finally { model.close(); await server.shutdown(); await f.cleanup(); }
});
