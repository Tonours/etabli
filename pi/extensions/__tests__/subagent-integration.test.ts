/// <reference path="./bun-test.d.ts" />
/// <reference path="../lib/node-runtime.d.ts" />
import { describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { resetRuntimeCaches } from "../lib/pi-runtime.ts";
import subagent from "../subagent.ts";

type Level = "info" | "warning" | "error";

type Notification = {
  message: string;
  level: Level;
};

type RuntimeController = {
  complete(code: number): void;
  error(message: string): void;
};

type RuntimeStart = {
  id: number;
  role: string | undefined;
  prompt: string;
  model: string;
  thinking: string;
};

type EventHandlers = {
  input?: (event: { text: string; source: string }, ctx: TestContext) => Promise<{ action: string; text?: string }>;
  tool_result?: (event: { toolName: string; input?: { path?: string }; isError?: boolean }, ctx: TestContext) => Promise<void>;
  agent_end?: (event: unknown, ctx: TestContext) => Promise<void>;
};

type TestContext = {
  cwd: string;
  hasUI: boolean;
  model?: { provider: string; id: string };
  ui: {
    notifications: Notification[];
    setWidget(id: string, value: unknown): void;
    notify(message: string, level: Level): void;
  };
  isIdle(): boolean;
};

function createHarness() {
  resetRuntimeCaches();
  const cwd = mkdtempSync(join(tmpdir(), "subagent-integration-"));
  const agentDir = mkdtempSync(join(tmpdir(), "subagent-agent-"));
  process.env.PI_CODING_AGENT_DIR = agentDir;
  writeFileSync(
    join(agentDir, "settings.json"),
    JSON.stringify({
      defaultProvider: "openai-codex",
      defaultModel: "gpt-5.4",
      subagents: {
        scout: { model: "kimi-coding/k2p5", thinking: "high" },
        worker: { model: "openai-codex/gpt-5.4", thinking: "high" },
        reviewer: { model: "github-copilot/claude-sonnet-4.6", thinking: "high" },
      },
    }),
    "utf-8",
  );
  const handlers: EventHandlers = {};
  const runtimeControllers = new Map<number, RuntimeController>();
  const starts: RuntimeStart[] = [];
  const notifications: Notification[] = [];

  const ctx: TestContext = {
    cwd,
    hasUI: false,
    model: { provider: "openai-codex", id: "gpt-5.4" },
    ui: {
      notifications,
      setWidget() {},
      notify(message: string, level: Level) {
        notifications.push({ message, level });
      },
    },
    isIdle() {
      return true;
    },
  };

  subagent(
    {
      on(event: keyof EventHandlers, handler: unknown) {
        handlers[event] = handler as never;
      },
      registerTool() {},
      registerCommand() {},
      sendMessage() {},
      sendUserMessage() {},
    } as never,
    {
      start(args) {
        starts.push({
          id: args.state.id,
          role: args.state.role,
          prompt: args.prompt,
          model: args.model,
          thinking: args.thinking,
        });
        runtimeControllers.set(args.state.id, {
          complete(code: number) {
            args.onComplete(code);
          },
          error(message: string) {
            args.onError(new Error(message));
          },
        });
      },
    },
  );

  return {
    cwd,
    ctx,
    notifications,
    starts,
    runtimeControllers,
    async input(text: string) {
      if (!handlers.input) throw new Error("input handler not registered");
      return await handlers.input({ text, source: "interactive" }, ctx);
    },
    async toolResult(path: string) {
      if (!handlers.tool_result) throw new Error("tool_result handler not registered");
      await handlers.tool_result({ toolName: "write", input: { path }, isError: false }, ctx);
    },
    async agentEnd() {
      if (!handlers.agent_end) throw new Error("agent_end handler not registered");
      await handlers.agent_end({}, ctx);
    },
    writePlan(status: string) {
      writeFileSync(join(cwd, "PLAN.md"), `# Plan\n- Status: ${status}\n`, "utf-8");
    },
    countRole(role: string) {
      return starts.filter((start) => start.role === role).length;
    },
    latestRole(role: string) {
      const matches = starts.filter((start) => start.role === role);
      return matches.length > 0 ? matches[matches.length - 1] : undefined;
    },
  };
}

describe("subagent automation integration", () => {
  test("plan-loop spawns scout once and reviewer once", async () => {
    const harness = createHarness();

    const transformed = await harness.input("/skill:plan-loop tighten automation");

    expect(transformed?.action).toBe("transform");
    expect(transformed?.text).toContain("Subagent automation active");
    expect(harness.countRole("scout")).toBe(1);
    expect(harness.latestRole("scout")?.model).toBeTruthy();
    expect(harness.latestRole("scout")?.thinking).toBeTruthy();

    harness.writePlan("DRAFT");
    await harness.toolResult(join(harness.cwd, "PLAN.md"));
    await harness.toolResult(join(harness.cwd, "PLAN.md"));
    await harness.agentEnd();

    expect(harness.countRole("reviewer")).toBe(1);
    expect(harness.latestRole("reviewer")?.model).toBe("github-copilot/claude-sonnet-4.6");
  });

  test("plan-implement waits for reviewer completion before worker", async () => {
    const harness = createHarness();

    await harness.input("/skill:plan-implement ship feature");
    expect(harness.countRole("scout")).toBe(1);

    harness.writePlan("DRAFT");
    await harness.toolResult(join(harness.cwd, "PLAN.md"));
    const reviewer = harness.latestRole("reviewer");
    if (!reviewer) throw new Error("reviewer missing");

    harness.writePlan("READY");
    await harness.agentEnd();
    expect(harness.countRole("worker")).toBe(0);

    harness.runtimeControllers.get(reviewer.id)?.complete(0);
    await harness.agentEnd();

    expect(harness.countRole("worker")).toBe(1);
    expect(harness.latestRole("worker")?.model).toBe("openai-codex/gpt-5.4");
  });

  test("stale reviewer completion from previous workflow is ignored", async () => {
    const harness = createHarness();

    await harness.input("/skill:plan-implement first workflow");
    harness.writePlan("DRAFT");
    await harness.toolResult(join(harness.cwd, "PLAN.md"));
    const firstReviewer = harness.latestRole("reviewer");
    if (!firstReviewer) throw new Error("first reviewer missing");

    await harness.input("/skill:plan-implement second workflow");
    await harness.agentEnd();
    const secondReviewer = harness.latestRole("reviewer");
    if (!secondReviewer || secondReviewer.id === firstReviewer.id) {
      throw new Error("second reviewer missing");
    }

    harness.writePlan("READY");
    harness.runtimeControllers.get(firstReviewer.id)?.complete(0);
    await harness.agentEnd();
    expect(harness.countRole("worker")).toBe(0);

    harness.runtimeControllers.get(secondReviewer.id)?.complete(0);
    await harness.agentEnd();
    expect(harness.countRole("worker")).toBe(1);
  });
});
