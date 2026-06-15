import { describe, expect, test } from "bun:test";
import tasksTillDone from "../tasks-till-done.ts";

type Handler = (event: Record<string, unknown>) => unknown;

function setupExtension() {
  const handlers = new Map<string, Handler[]>();
  const sentUserMessages: string[] = [];
  const entries: unknown[] = [];
  const messages: Array<{ content?: string; display?: boolean; details?: unknown }> = [];

  const pi = {
    on(eventName: string, handler: Handler) {
      handlers.set(eventName, [...(handlers.get(eventName) ?? []), handler]);
    },
    getActiveTools() {
      return ["TaskCreate", "TaskList", "TaskUpdate"];
    },
    appendEntry(_customType: string, data?: unknown) {
      entries.push(data);
    },
    sendMessage(message: { content?: string; display?: boolean; details?: unknown }) {
      messages.push(message);
      return undefined;
    },
    sendUserMessage(content: string) {
      sentUserMessages.push(content);
    },
  };

  tasksTillDone(pi as Parameters<typeof tasksTillDone>[0]);

  return {
    entries,
    messages,
    sentUserMessages,
    emit(eventName: string, event: Record<string, unknown>) {
      return (handlers.get(eventName) ?? []).map((handler) => handler(event));
    },
  };
}

describe("tasks till-done extension", () => {
  test("injects task loop guidance into eligible agent starts", () => {
    const runtime = setupExtension();

    const results = runtime.emit("before_agent_start", {
      prompt: "Implémente ce changement et valide le résultat",
      systemPrompt: "Base prompt",
    });

    expect(results[0]).toEqual({
      systemPrompt: expect.stringContaining("# Etabli Task Loop"),
    });
  });

  test("sends a follow-up when TaskList still has actionable work", () => {
    const runtime = setupExtension();

    runtime.emit("before_agent_start", {
      prompt: "Implémente ce changement et valide le résultat",
      systemPrompt: "Base prompt",
    });
    runtime.emit("tool_result", {
      toolName: "TaskList",
      content: [
        {
          type: "text",
          text: "#1 [completed] Inspect settings\n#2 [pending] Patch extension",
        },
      ],
    });
    runtime.emit("agent_end", {});

    expect(runtime.sentUserMessages).toHaveLength(1);
    expect(runtime.sentUserMessages[0]).toContain("Continue the Task Loop");
    expect(runtime.entries[0]).toMatchObject({ reason: "actionable_tasks" });
  });

  test("requires validation before completing implementation task loops", () => {
    const runtime = setupExtension();

    runtime.emit("before_agent_start", {
      prompt: "Implémente ce changement",
      systemPrompt: "Base prompt",
    });
    runtime.emit("tool_result", {
      toolName: "TaskList",
      content: [{ type: "text", text: "#1 [completed] Patch extension" }],
    });
    runtime.emit("agent_end", {});

    expect(runtime.sentUserMessages).toHaveLength(1);
    expect(runtime.sentUserMessages[0]).toContain("needs validation evidence");
    expect(runtime.entries[0]).toMatchObject({ reason: "validation_required", workflowRoute: "plan-implement" });
  });

  test("sends a visible stop message when blocked", () => {
    const runtime = setupExtension();

    runtime.emit("before_agent_start", {
      prompt: "Implémente ce changement",
      systemPrompt: "Base prompt",
    });
    runtime.emit("tool_result", {
      toolName: "TaskList",
      content: [{ type: "text", text: "#1 [pending] Deploy change [blocked by #2]" }],
    });
    runtime.emit("agent_end", {});

    expect(runtime.sentUserMessages).toEqual([]);
    expect(runtime.messages).toContainEqual(expect.objectContaining({
      content: "Task loop stopped: blocked",
      display: true,
    }));
  });

  test("does not continue when TaskList is complete", () => {
    const runtime = setupExtension();

    runtime.emit("before_agent_start", {
      prompt: "Implémente ce changement et valide le résultat",
      systemPrompt: "Base prompt",
    });
    runtime.emit("tool_result", {
      toolName: "TaskList",
      content: [{ type: "text", text: "#1 [completed] Inspect settings\n#2 [completed] Run validation tests" }],
    });
    runtime.emit("agent_end", {});

    expect(runtime.sentUserMessages).toEqual([]);
  });
});
