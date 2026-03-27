/// <reference path="./bun-test.d.ts" />
import { describe, expect, test } from "bun:test";
import tilldone, {
  autoActivateTask,
  nextToggleStatus,
  normalizeTasks,
  setExclusiveInProgress,
  validateTaskText,
  type Task,
} from "../tilldone.ts";

type ToolResult = {
  content: Array<{ type: "text"; text: string }>;
  details: unknown;
};

type BranchEntry = {
  type: "message";
  message: {
    role: "toolResult";
    toolName: "tilldone";
    details: unknown;
  };
};

type EventHandlers = {
  session_start?: (event: unknown, ctx: TestContext) => Promise<void>;
  tool_call?: (event: { toolName: string; input?: unknown }, ctx: TestContext) => Promise<{ block: boolean }>;
};

type RegisteredTool = {
  execute: (
    toolCallId: string,
    params: Record<string, unknown>,
    signal: unknown,
    onUpdate: unknown,
    ctx: TestContext,
  ) => Promise<ToolResult>;
};

type TestContext = {
  hasUI: boolean;
  ui: {
    setWidget(id: string, value: unknown): void;
    setStatus(id: string, value: string): void;
    notify(message: string, level: string): void;
    custom<T>(render: unknown): Promise<T>;
  };
  sessionManager: {
    getBranch(): BranchEntry[];
  };
};

function createHarness(initialBranch: BranchEntry[] = []) {
  const branch = [...initialBranch];
  const handlers: EventHandlers = {};
  let tool: RegisteredTool | null = null;

  const ctx: TestContext = {
    hasUI: false,
    ui: {
      setWidget() {},
      setStatus() {},
      notify() {},
      async custom<T>(): Promise<T> {
        throw new Error("interactive UI not available in tests");
      },
    },
    sessionManager: {
      getBranch() {
        return branch;
      },
    },
  };

  tilldone({
    on(event: keyof EventHandlers, handler: unknown) {
      handlers[event] = handler as never;
    },
    registerTool(definition: unknown) {
      tool = definition as RegisteredTool;
    },
    registerCommand() {},
    sendMessage() {},
  } as never);

  if (!tool) throw new Error("tilldone tool was not registered");
  const registeredTool: RegisteredTool = tool;

  return {
    branch,
    ctx,
    handlers,
    async run(params: Record<string, unknown>) {
      const result = await registeredTool.execute("1", params, undefined, undefined, ctx);
      branch.push({
        type: "message",
        message: {
          role: "toolResult",
          toolName: "tilldone",
          details: result.details,
        },
      });
      return result;
    },
    async reconstruct() {
      if (!handlers.session_start) throw new Error("session_start handler not registered");
      await handlers.session_start(undefined, ctx);
    },
  };
}

describe("nextToggleStatus", () => {
  test("advances idle to inprogress", () => {
    expect(nextToggleStatus("idle")).toBe("inprogress");
  });

  test("advances inprogress to done", () => {
    expect(nextToggleStatus("inprogress")).toBe("done");
  });

  test("does not reopen done tasks implicitly", () => {
    expect(nextToggleStatus("done")).toBeNull();
  });
});

describe("setExclusiveInProgress", () => {
  test("activates the requested task and demotes other active tasks", () => {
    const tasks: Task[] = [
      { id: 1, text: "first", status: "inprogress" },
      { id: 2, text: "second", status: "idle" },
      { id: 3, text: "third", status: "done" },
    ];

    const result = setExclusiveInProgress(tasks, 2);

    expect(result.tasks).toEqual([
      { id: 1, text: "first", status: "idle" },
      { id: 2, text: "second", status: "inprogress" },
      { id: 3, text: "third", status: "done" },
    ]);
    expect(result.demotedIds).toEqual([1]);
  });
});

describe("autoActivateTask", () => {
  test("activates the preferred pending task when nothing is active", () => {
    const tasks: Task[] = [
      { id: 1, text: "first", status: "idle" },
      { id: 2, text: "second", status: "idle" },
    ];

    const result = autoActivateTask(tasks, 2);

    expect(result.activatedId).toBe(2);
    expect(result.tasks).toEqual([
      { id: 1, text: "first", status: "idle" },
      { id: 2, text: "second", status: "inprogress" },
    ]);
  });

  test("leaves tasks unchanged when one is already active", () => {
    const tasks: Task[] = [
      { id: 1, text: "first", status: "inprogress" },
      { id: 2, text: "second", status: "idle" },
    ];

    const result = autoActivateTask(tasks, 2);

    expect(result.activatedId).toBeUndefined();
    expect(result.tasks).toEqual(tasks);
  });
});

describe("normalizeTasks", () => {
  test("auto-activates the first pending task when requested", () => {
    const tasks: Task[] = [
      { id: 1, text: "first", status: "idle" },
      { id: 2, text: "second", status: "done" },
    ];

    const result = normalizeTasks(tasks, { autoActivatePending: true });

    expect(result.activatedId).toBe(1);
    expect(result.tasks).toEqual([
      { id: 1, text: "first", status: "inprogress" },
      { id: 2, text: "second", status: "done" },
    ]);
  });
});

describe("validateTaskText", () => {
  test("rejects broader vague task phrases", () => {
    expect(validateTaskText("fix bug")).toBe("task too vague");
    expect(validateTaskText("investigate issue")).toBe("task too vague");
    expect(validateTaskText("cleanup code")).toBe("task too vague");
    expect(validateTaskText("refactor stuff in app")).toBe("task too vague");
  });

  test("accepts concrete tasks with specific nouns", () => {
    expect(validateTaskText("fix auth token refresh bug")).toBeNull();
    expect(validateTaskText("review onboarding copy in settings modal")).toBeNull();
  });
});

describe("tool behavior", () => {
  test("new-list seeds tasks and auto-starts the first one", async () => {
    const harness = createHarness();

    const result = await harness.run({
      action: "new-list",
      text: "TillDone",
      texts: ["first", "second"],
    });

    expect(result.content[0]?.text).toContain("auto-started #1");
    expect(result.details).toMatchObject({
      tasks: [
        { id: 1, text: "first", status: "inprogress" },
        { id: 2, text: "second", status: "idle" },
      ],
    });
  });

  test("new-list normalizes and dedupes seeded tasks", async () => {
    const harness = createHarness();

    const result = await harness.run({
      action: "new-list",
      text: "  TillDone  ",
      texts: ["  first   task  ", "first task", "second task"],
    });

    expect(result.content[0]?.text).toContain("Skipped duplicates");
    expect(result.details).toMatchObject({
      listTitle: "TillDone",
      tasks: [
        { id: 1, text: "first task", status: "inprogress" },
        { id: 2, text: "second task", status: "idle" },
      ],
    });
  });

  test("new-list still succeeds when optional seed tasks are all invalid", async () => {
    const harness = createHarness();

    const result = await harness.run({
      action: "new-list",
      text: "TillDone",
      texts: ["stuff", "fix things"],
    });

    expect(result.content[0]?.text).toContain('New list: "TillDone"');
    expect(result.content[0]?.text).toContain("Skipped vague/invalid tasks");
    expect(result.details).toMatchObject({
      listTitle: "TillDone",
      tasks: [],
    });
  });

  test("toggle does not reopen done tasks", async () => {
    const harness = createHarness();

    await harness.run({ action: "new-list", text: "TillDone", texts: ["first"] });
    const done = await harness.run({ action: "toggle", id: 1 });
    const blocked = await harness.run({ action: "toggle", id: 1 });

    expect(done.content[0]?.text).toBe("Task #1: inprogress → done");
    expect(blocked.content[0]?.text).toContain("already done");
    expect(blocked.details).toMatchObject({
      tasks: [{ id: 1, text: "first", status: "done" }],
    });
  });

  test("undo preserves the previous undo chain", async () => {
    const harness = createHarness();

    await harness.run({ action: "new-list", text: "TillDone", texts: ["first"] });
    await harness.run({ action: "add", text: "second" });
    await harness.run({ action: "clear" });

    const undoClear = await harness.run({ action: "undo" });
    const undoAdd = await harness.run({ action: "undo" });

    expect(undoClear.details).toMatchObject({
      tasks: [
        { id: 1, text: "first", status: "inprogress" },
        { id: 2, text: "second", status: "idle" },
      ],
    });
    expect(undoAdd.details).toMatchObject({
      tasks: [{ id: 1, text: "first", status: "inprogress" }],
    });
  });

  test("remove auto-starts the next pending task when removing the active one", async () => {
    const harness = createHarness();

    await harness.run({ action: "new-list", text: "TillDone", texts: ["first", "second"] });
    const removed = await harness.run({ action: "remove", id: 1 });

    expect(removed.content[0]?.text).toContain("Auto-started #2");
    expect(removed.details).toMatchObject({
      tasks: [{ id: 2, text: "second", status: "inprogress" }],
    });
  });

  test("add rejects vague tasks when nothing valid remains", async () => {
    const harness = createHarness();

    await harness.run({ action: "new-list", text: "TillDone" });
    const result = await harness.run({
      action: "add",
      texts: ["fix things", "stuff", "fix bug", "investigate issue", "cleanup code"],
    });

    expect(result.content[0]?.text).toContain("Error:");
    expect(result.details).toMatchObject({ error: "no valid tasks" });

    const listed = await harness.run({ action: "list" });
    expect(listed.details).toMatchObject({ tasks: [] });
  });

  test("add enforces the list size cap", async () => {
    const harness = createHarness();

    await harness.run({
      action: "new-list",
      text: "TillDone",
      texts: ["task one", "task two", "task three", "task four", "task five", "task six"],
    });
    const result = await harness.run({ action: "add", texts: ["task seven", "task eight"] });

    expect(result.content[0]?.text).toContain("Too many tasks");
    expect(result.details).toMatchObject({ error: "too many tasks" });
  });

  test("add allows reaching exactly the list size cap", async () => {
    const harness = createHarness();

    await harness.run({
      action: "new-list",
      text: "TillDone",
      texts: ["task one", "task two", "task three", "task four", "task five", "task six"],
    });
    const result = await harness.run({ action: "add", text: "task seven" });

    expect(result.content[0]?.text).toContain("Added task #7");
    expect(result.details).toMatchObject({
      tasks: [
        { id: 1, text: "task one", status: "inprogress" },
        { id: 2, text: "task two", status: "idle" },
        { id: 3, text: "task three", status: "idle" },
        { id: 4, text: "task four", status: "idle" },
        { id: 5, text: "task five", status: "idle" },
        { id: 6, text: "task six", status: "idle" },
        { id: 7, text: "task seven", status: "idle" },
      ],
    });
  });

  test("update normalizes text and rejects duplicates", async () => {
    const harness = createHarness();

    await harness.run({ action: "new-list", text: "TillDone", texts: ["first task", "second task"] });
    const duplicate = await harness.run({ action: "update", id: 2, text: "  first   task " });
    const updated = await harness.run({ action: "update", id: 2, text: "  third   task  " });

    expect(duplicate.content[0]?.text).toContain("duplicate");
    expect(updated.details).toMatchObject({
      tasks: [
        { id: 1, text: "first task", status: "inprogress" },
        { id: 2, text: "third task", status: "idle" },
      ],
    });
  });

  test("update is a no-op when normalized text does not change", async () => {
    const harness = createHarness();

    await harness.run({ action: "new-list", text: "TillDone", texts: ["first task"] });
    const updated = await harness.run({ action: "update", id: 1, text: "  first   task  " });

    expect(updated.content[0]?.text).toBe("No change for #1");
    expect(updated.details).toMatchObject({
      tasks: [{ id: 1, text: "first task", status: "inprogress" }],
    });
  });

  test("reconstruction normalizes old states with no active task", async () => {
    const harness = createHarness([
      {
        type: "message",
        message: {
          role: "toolResult",
          toolName: "tilldone",
          details: {
            action: "list",
            tasks: [
              { id: 1, text: "first", status: "idle" },
              { id: 2, text: "second", status: "idle" },
            ],
            nextId: 3,
            listTitle: "Recovered",
          },
        },
      },
    ]);

    await harness.reconstruct();
    const listed = await harness.run({ action: "list" });

    expect(listed.details).toMatchObject({
      tasks: [
        { id: 1, text: "first", status: "inprogress" },
        { id: 2, text: "second", status: "idle" },
      ],
    });
  });
});
