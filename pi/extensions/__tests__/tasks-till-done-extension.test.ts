import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
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

function createImplementationCwd(): string {
  const cwd = mkdtempSync(join(tmpdir(), "etabli-task-loop-"));
  mkdirSync(join(cwd, "docs", "plan"), { recursive: true });
  return cwd;
}

function implementedPlanArchivePath(cwd: string): string {
  return join(cwd, "docs", "plan", "20260702-implemented-plan.md");
}

function writeImplementedPlanArchive(cwd: string, mtime?: Date): void {
  const archivePath = implementedPlanArchivePath(cwd);
  writeFileSync(archivePath, "# Implemented plan\n");
  if (mtime) {
    utimesSync(archivePath, mtime, mtime);
  }
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

  test("uses structured TaskList details when text content is not parseable", () => {
    const runtime = setupExtension();

    runtime.emit("before_agent_start", {
      prompt: "Implémente ce changement et valide le résultat",
      systemPrompt: "Base prompt",
    });
    runtime.emit("tool_result", {
      toolName: "TaskList",
      content: [{ type: "text", text: "Task widget rendered without machine-readable lines" }],
      details: {
        tasks: [
          { id: "1", subject: "Patch extension", status: "pending" },
        ],
      },
    });
    runtime.emit("agent_end", {});

    expect(runtime.sentUserMessages).toHaveLength(1);
    expect(runtime.entries[0]).toMatchObject({
      reason: "actionable_tasks",
      summary: {
        evidenceSource: "structured",
        guaranteeStatus: "confirmed",
      },
    });
  });

  test("stops visibly when TaskExecute cannot track subagents", () => {
    const runtime = setupExtension();

    runtime.emit("before_agent_start", {
      prompt: "Implémente ce changement avec un subagent",
      systemPrompt: "Base prompt",
    });
    runtime.emit("tool_result", {
      toolName: "TaskExecute",
      content: [{
        type: "text",
        text: "Subagent execution is currently unavailable (@tintinweb/pi-subagents not loaded or version mismatch). pi-tasks won't track them — status stays pending, cascade won't fire, TaskOutput stays empty.",
      }],
    });
    runtime.emit("agent_end", {});

    expect(runtime.sentUserMessages).toEqual([]);
    expect(runtime.messages).toContainEqual(expect.objectContaining({
      content: "Task loop stopped: runtime_capability_blocked",
      display: true,
      details: expect.objectContaining({
        reason: "runtime_capability_blocked",
        runtimeCapabilityIssue: expect.objectContaining({
          kind: "subagent_execution_unavailable",
          guaranteeStatus: "blocked",
        }),
      }),
    }));
  });

  test("requires adversary, validation, review, archive, and cleanup before completing implementation task loops", () => {
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
    expect(runtime.sentUserMessages[0]).toContain("needs completion evidence");
    expect(runtime.sentUserMessages[0]).toContain("adversarial plan review");
    expect(runtime.sentUserMessages[0]).toContain("implemented-plan archive under docs/plan");
    expect(runtime.entries[0]).toMatchObject({ reason: "completion_evidence_required", workflowRoute: "plan-implement" });
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

  test("does not continue when implementation TaskList has completion evidence", () => {
    const runtime = setupExtension();
    const cwd = createImplementationCwd();

    try {
      runtime.emit("before_agent_start", {
        prompt: "Implémente ce changement et valide le résultat",
        systemPrompt: "Base prompt",
        cwd,
      });
      writeImplementedPlanArchive(cwd);
      runtime.emit("tool_result", {
        toolName: "TaskList",
        content: [{
          type: "text",
          text: [
            "#1 [completed] Inspect settings",
            "#2 [completed] Run adversary plan review",
            "#3 [completed] Run validation tests",
            "#4 [completed] Review diff against PLAN.md",
            "#5 [completed] Archive implemented plan in docs/plan",
            "#6 [completed] Delete root PLAN.md after archive",
          ].join("\n"),
        }],
      });
      runtime.emit("agent_end", {});
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }

    expect(runtime.sentUserMessages).toEqual([]);
  });

  test("continues when completion tasks cite only a stale implemented-plan archive", () => {
    const runtime = setupExtension();
    const cwd = createImplementationCwd();

    try {
      writeImplementedPlanArchive(cwd, new Date(Date.now() - 60_000));
      runtime.emit("before_agent_start", {
        prompt: "Implémente ce changement et valide le résultat",
        systemPrompt: "Base prompt",
        cwd,
      });
      runtime.emit("tool_result", {
        toolName: "TaskList",
        content: [{
          type: "text",
          text: [
            "#1 [completed] Inspect settings",
            "#2 [completed] Run adversary plan review",
            "#3 [completed] Run validation tests",
            "#4 [completed] Review diff against PLAN.md",
            "#5 [completed] Archive implemented plan in docs/plan",
            "#6 [completed] Delete root PLAN.md after archive",
          ].join("\n"),
        }],
      });
      runtime.emit("agent_end", {});
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }

    expect(runtime.sentUserMessages).toHaveLength(1);
    expect(runtime.sentUserMessages[0]).toContain("needs completion evidence");
    expect(runtime.entries[0]).toMatchObject({
      reason: "completion_evidence_required",
      implementationRuntimeEvidence: {
        hasImplementedPlanArchive: false,
        rootPlanDeleted: true,
      },
    });
  });

  test("keeps implemented-plan archive evidence once seen during a loop", () => {
    const runtime = setupExtension();
    const cwd = createImplementationCwd();

    try {
      runtime.emit("before_agent_start", {
        prompt: "Implémente ce changement et valide le résultat",
        systemPrompt: "Base prompt",
        cwd,
      });
      writeImplementedPlanArchive(cwd);
      runtime.emit("tool_result", {
        toolName: "TaskList",
        content: [{
          type: "text",
          text: "#1 [pending] Finish validation",
        }],
      });
      runtime.emit("agent_end", {});
      rmSync(implementedPlanArchivePath(cwd), { force: true });
      runtime.emit("tool_result", {
        toolName: "TaskList",
        content: [{
          type: "text",
          text: [
            "#1 [completed] Inspect settings",
            "#2 [completed] Run adversary plan review",
            "#3 [completed] Run validation tests",
            "#4 [completed] Review diff against PLAN.md",
            "#5 [completed] Archive implemented plan in docs/plan",
            "#6 [completed] Delete root PLAN.md after archive",
          ].join("\n"),
        }],
      });
      runtime.emit("agent_end", {});
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }

    expect(runtime.entries[0]).toMatchObject({
      reason: "actionable_tasks",
      implementationRuntimeEvidence: {
        hasImplementedPlanArchive: true,
      },
    });
    expect(runtime.sentUserMessages).toHaveLength(1);
    expect(runtime.sentUserMessages[0]).toContain("Continue the Task Loop");
  });
});
