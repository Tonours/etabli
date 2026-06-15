import { describe, expect, test } from "bun:test";
import workflowRouter from "../workflow-router.ts";

type Handler = (event: Record<string, unknown>) => unknown;

function setupExtension() {
  const handlers = new Map<string, Handler[]>();
  const entries: unknown[] = [];

  const pi = {
    on(eventName: string, handler: Handler) {
      handlers.set(eventName, [...(handlers.get(eventName) ?? []), handler]);
    },
    getActiveTools() {
      return ["TaskCreate", "TaskList"];
    },
    appendEntry(_customType: string, data?: unknown) {
      entries.push(data);
    },
  };

  workflowRouter(pi as Parameters<typeof workflowRouter>[0]);

  return {
    entries,
    emit(eventName: string, event: Record<string, unknown>) {
      return (handlers.get(eventName) ?? []).map((handler) => handler(event));
    },
  };
}

describe("workflow router extension", () => {
  test("injects route guidance and records the decision", () => {
    const runtime = setupExtension();

    const results = runtime.emit("before_agent_start", {
      prompt: "Implémente le PLAN.md ready",
      systemPrompt: "Base prompt",
    });

    expect(results[0]).toEqual({
      systemPrompt: expect.stringContaining("Route: implement"),
    });
    expect(runtime.entries[0]).toMatchObject({
      decision: { route: "implement" },
    });
  });

  test("skips explicit slash commands", () => {
    const runtime = setupExtension();

    const results = runtime.emit("before_agent_start", {
      prompt: "/skill:implement",
      systemPrompt: "Base prompt",
    });

    expect(results).toEqual([undefined]);
    expect(runtime.entries).toEqual([]);
  });
});
