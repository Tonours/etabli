import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { readFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fixture, until } from "./helpers.ts";
import { dispatch, serve } from "../src/daemon.ts";
import { request } from "../src/cli.ts";

test("native run commits in an isolated worktree, persists metadata and idempotent admission", async () => {
  const f = await fixture();
  try {
    f.faux.setResponses([
      fauxAssistantMessage(fauxToolCall("bash", { command: "printf 'finished\\n' > result.txt && bash check.sh && git -c user.name=Fixture -c user.email=fixture@example.invalid add result.txt && git -c user.name=Fixture -c user.email=fixture@example.invalid commit -m 'finish fixture'" }), { stopReason: "toolUse" }),
      fauxAssistantMessage("done"),
    ]);
    const run = await f.core.runs.submit("Tonours/fixture", "small no-plan fixture", "once");
    expect((await f.core.runs.submit("Tonours/fixture", "small no-plan fixture", "once")).id).toBe(run.id);
    await expect(f.core.runs.submit("Tonours/fixture", "different", "once")).rejects.toThrow("different input");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    expect((await f.core.runs.show(run.id)).status).toBe("done");
    expect(await readFile(join(run.worktree, "result.txt"), "utf8")).toBe("finished\n");
    expect(execFileSync("git", ["-C", run.worktree, "log", "-1", "--format=%s"], { encoding: "utf8" }).trim()).toBe("finish fixture");
    await f.reopen();
    expect((await f.core.runs.list()).map((run) => run.status)).toEqual(["done"]);
    expect((await stat(f.state)).mode & 0o777).toBe(0o700);
    expect((await stat(join(f.state, "store.sqlite"))).mode & 0o777).toBe(0o600);
  } finally { await f.cleanup(); }
});

test("two native runs busy, third queued across reopen, abort releases a slot", async () => {
  const f = await fixture();
  let release: () => void = () => undefined;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  const waiting = async (_input: unknown, options: { signal?: AbortSignal } | undefined) => {
    await Promise.race([gate, new Promise<void>((resolve) => options?.signal?.addEventListener("abort", () => resolve(), { once: true }))]);
    return fauxAssistantMessage("done");
  };
  f.faux.setResponses(Array.from({ length: 10 }, () => waiting));
  try {
    const runs = await Promise.all([0, 1, 2].map((n) => f.core.runs.submit("Tonours/fixture", `fixture ${n}`, `request-${n}`)));
    await f.core.runs.tick();
    expect((await f.core.runs.list()).map((run) => run.status)).toEqual(["implementing", "implementing", "queued"]);
    await f.reopen();
    expect((await f.core.runs.list()).map((run) => run.status)).toEqual(["implementing", "implementing", "queued"]);
    await f.core.runs.abort(runs[0].id);
    await f.core.runs.tick();
    expect((await f.core.runs.list()).map((run) => run.status)).toEqual(["aborted", "implementing", "implementing"]);
    const record = await f.core.harness.conversation(runs[0].conversationId, context);
    await record?.waitForIdle(context);
    release();
    await f.core.harness.waitForIdle(context);
  } finally { release(); await f.cleanup(); }
});

test("persisted wall-clock and turn caps block with exactly one notification", async () => {
  let now = 10_000;
  const f = await fixture({ wallMs: 200, now: () => now, maxTurns: 1 });
  try {
    f.faux.setResponses([fauxAssistantMessage(fauxToolCall("bash", { command: "printf ok" }), { stopReason: "toolUse" })]);
    const turn = await f.core.runs.submit("Tonours/fixture", "one turn", "turn");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    expect(await f.core.runs.show(turn.id)).toMatchObject({ status: "blocked", reason: "turn_limit", notified: true });
    f.faux.setResponses([async () => { await new Promise((resolve) => setTimeout(resolve, 100)); return fauxAssistantMessage("done"); }]);
    const wall = await f.core.runs.submit("Tonours/fixture", "wall", "wall");
    await f.core.runs.tick();
    const deadline = (await f.core.runs.show(wall.id)).deadline;
    now += 50;
    await f.reopen();
    expect((await f.core.runs.show(wall.id)).deadline).toBe(deadline);
    now += 200;
    await f.core.runs.tick();
    expect(await f.core.runs.show(wall.id)).toMatchObject({ status: "blocked", reason: "wall_clock_limit", notified: true });
    await f.core.runs.tick();
  } finally { await f.cleanup(); }
});

test("local socket drives run, ls, show, steer and abort with private permissions", async () => {
  const f = await fixture();
  const server = await serve(f.core, f.state);
  try {
    f.faux.setResponses([
      fauxAssistantMessage(fauxToolCall("bash", { command: "printf started > steering-start; sleep 0.2; printf safe" }), { stopReason: "toolUse" }),
      fauxAssistantMessage("done"),
    ]);
    const run = await f.core.runs.submit("Tonours/fixture", "socket fixture", "socket");
    await f.core.runs.tick();
    await until(() => stat(join(run.worktree, "steering-start")).then(() => true, () => false));
    expect((await stat(join(f.state, "daemon.sock"))).mode & 0o777).toBe(0o600);
    await expect(request(f.state, { op: "run", repo: "Tonours/fixture", prompt: "invalid id", requestId: {} })).rejects.toThrow("must be strings");
    expect((await request(f.state, { op: "ls" }) as unknown[]).length).toBe(1);
    await request(f.state, { op: "steer", id: run.id, content: "take care", requestId: "steer-once" });
    await f.core.harness.waitForIdle(context);
    const shown = await dispatch(f.core, { op: "show", id: run.id }) as { entries: { kind: string; model?: { content: unknown } }[] };
    const toolIndex = shown.entries.findIndex((entry) => entry.kind === "pi.tool-result");
    const steerIndex = shown.entries.findIndex((entry) => entry.kind === "pi.user" && JSON.stringify(entry).includes("take care"));
    expect(toolIndex).toBeGreaterThanOrEqual(0);
    expect(steerIndex).toBeGreaterThan(toolIndex);
    await request(f.state, { op: "abort", id: run.id });
    await f.core.harness.waitForIdle(context);
  } finally { server.close(); await f.cleanup(); }
});

test("wall cap interrupts a busy run while another repository preparation waits", async () => {
  const f = await fixture({ wallMs: 200 });
  let release = () => {};
  let preparing: Promise<void> | undefined;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  try {
    f.faux.setResponses(Array.from({ length: 4 }, () => async (_input: unknown, options: { signal?: AbortSignal } | undefined) => {
      await Promise.race([gate, new Promise<void>((resolve) => options?.signal?.addEventListener("abort", () => resolve(), { once: true }))]);
      return fauxAssistantMessage("done");
    }));
    const first = await f.core.runs.submit("Tonours/fixture", "first", "cap-first");
    await f.core.runs.tick();
    const second = await f.core.runs.submit("Tonours/fixture", "second", "cap-second");
    const prepare = f.core.runs.repositories.prepare.bind(f.core.runs.repositories);
    let entered = false;
    Object.assign(f.core.runs.repositories, { prepare: async (id: string, repo: string, branch: string) => { if (id === second.id) { entered = true; await gate; } return prepare(id, repo, branch); } });
    preparing = f.core.runs.tick();
    await until(async () => entered);
    await until(async () => (await f.core.runs.show(first.id)).status === "blocked", 1000);
    expect((await f.core.runs.show(first.id)).reason).toBe("wall_clock_limit");
  } finally { release(); await preparing; await f.cleanup(); }
});

test("abort bypasses slow preparation and cannot revive the cancelled queued run", async () => {
  const f = await fixture();
  let release = () => {};
  let preparing: Promise<void> | undefined;
  let aborting: Promise<boolean> | undefined;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  try {
    f.faux.setResponses(Array.from({ length: 4 }, () => async () => { await gate; return fauxAssistantMessage("done"); }));
    const first = await f.core.runs.submit("Tonours/fixture", "first", "abort-first");
    await f.core.runs.tick();
    const second = await f.core.runs.submit("Tonours/fixture", "second", "abort-second");
    const prepare = f.core.runs.repositories.prepare.bind(f.core.runs.repositories);
    let entered = false;
    Object.assign(f.core.runs.repositories, { prepare: async (id: string, repo: string, branch: string) => { if (id === second.id) { entered = true; await gate; } return prepare(id, repo, branch); } });
    preparing = f.core.runs.tick();
    await until(async () => entered);
    aborting = f.core.runs.abort(second.id);
    await until(async () => (await f.core.runs.show(second.id)).status === "aborted", 300);
    release();
    await preparing;
    await aborting;
    expect((await f.core.runs.show(second.id)).status).toBe("aborted");
    expect((await f.core.runs.show(first.id)).status).toBe("implementing");
  } finally { release(); await preparing; await aborting; await f.cleanup(); }
});
