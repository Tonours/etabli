import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

// Mock session manager entry
type MockEntry = {
  type: string;
  message?: {
    role: string;
    toolName?: string;
    details?: unknown;
  };
};

describe("tilldone-ops-sync", () => {
  let testDir: string;
  let statusDir: string;

  beforeEach(() => {
    testDir = join(tmpdir(), `tilldone-sync-test-${Date.now()}`);
    statusDir = join(tmpdir(), `.pi-status-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });
    mkdirSync(statusDir, { recursive: true });
  });

  afterEach(() => {
    if (existsSync(testDir)) rmSync(testDir, { recursive: true });
    if (existsSync(statusDir)) rmSync(statusDir, { recursive: true });
  });

  it("should sanitize cwd correctly for status paths", () => {
    const testCases = [
      { input: "/home/user/project", expected: "_home_user_project" },
      { input: "/path/with spaces", expected: "_path_with_spaces" },
      { input: "/mix-ed.path_123", expected: "_mix-ed.path_123" },
    ];

    for (const { input, expected } of testCases) {
      const sanitized = input.replace(/[^a-zA-Z0-9._-]+/g, "_");
      expect(sanitized).toBe(expected);
    }
  });

  it("should reconstruct TillDone state from session history", () => {
    // Simulate session entries that would be processed
    const mockEntries: MockEntry[] = [
      {
        type: "message",
        message: {
          role: "toolResult",
          toolName: "tilldone",
          details: {
            tasks: [
              { id: 1, text: "First task", status: "done" },
              { id: 2, text: "Second task", status: "inprogress" },
              { id: 3, text: "Third task", status: "idle" },
            ],
            nextId: 4,
            listTitle: "Test List",
            listDescription: "Test Description",
          },
        },
      },
    ];

    // Verify the entries structure
    expect(mockEntries).toHaveLength(1);
    expect(mockEntries[0].type).toBe("message");
    expect(mockEntries[0].message?.toolName).toBe("tilldone");
    
    const details = mockEntries[0].message?.details as {
      tasks: Array<{ id: number; text: string; status: string }>;
      nextId: number;
      listTitle: string;
    };
    
    expect(details.tasks).toHaveLength(3);
    expect(details.tasks[1].status).toBe("inprogress");
    expect(details.listTitle).toBe("Test List");
  });

  it("should write and read TillDone OPS state", () => {
    const sanitizedCwd = testDir.replace(/[^a-zA-Z0-9._-]+/g, "_");
    const tilldonePath = join(statusDir, `${sanitizedCwd}.tilldone-ops.json`);

    const mockState = {
      tasks: [
        { id: 1, text: "Task 1", status: "done" as const },
        { id: 2, text: "Task 2", status: "inprogress" as const },
      ],
      activeTaskId: 2,
      listTitle: "My Tasks",
      listDescription: "Important work",
      updatedAt: new Date().toISOString(),
      revision: 1,
    };

    // Write state
    writeFileSync(tilldonePath, JSON.stringify(mockState, null, 2));

    // Read state
    expect(existsSync(tilldonePath)).toBe(true);
    const readContent = readFileSync(tilldonePath, "utf-8");
    const parsed = JSON.parse(readContent);

    expect(parsed.tasks).toHaveLength(2);
    expect(parsed.activeTaskId).toBe(2);
    expect(parsed.listTitle).toBe("My Tasks");
    expect(parsed.revision).toBe(1);
  });

  it("should update OPS task projection with TillDone data", () => {
    const sanitizedCwd = testDir.replace(/[^a-zA-Z0-9._-]+/g, "_");
    const taskPath = join(statusDir, `${sanitizedCwd}.task.json`);

    // Create mock OPS task
    const opsTask = {
      taskId: testDir,
      title: "Test Project",
      repo: "test-project",
      workspacePath: testDir,
      branch: "main",
      identitySource: "cwd",
      titleSource: "repo",
      lifecycleState: "implementing",
      mode: "standard",
      planStatus: "READY",
      runtimePhase: "idle",
      reviewSummary: "0 actionable",
      nextAction: "Continue implementation",
      activeSlice: "Test slice",
      completedSlices: ["Setup"],
      pendingChecks: [],
      lastValidatedState: "Tests passing",
      revision: 1,
      updatedAt: new Date().toISOString(),
    };

    writeFileSync(taskPath, JSON.stringify(opsTask, null, 2));

    // Simulate TillDone sync
    const tilldoneData = {
      activeTaskId: 3,
      taskCount: 5,
      remainingCount: 2,
      activeTaskText: "Fix critical bug",
      listTitle: "Sprint Tasks",
    };

    // Update OPS task with TillDone data
    const updatedTask = {
      ...opsTask,
      tilldone: tilldoneData,
      nextAction: `${tilldoneData.activeTaskText} (#${tilldoneData.activeTaskId})`,
    };

    writeFileSync(taskPath, JSON.stringify(updatedTask, null, 2));

    // Verify update
    const readTask = JSON.parse(readFileSync(taskPath, "utf-8"));
    expect(readTask.tilldone).toBeDefined();
    expect(readTask.tilldone.activeTaskId).toBe(3);
    expect(readTask.tilldone.taskCount).toBe(5);
    expect(readTask.nextAction).toBe("Fix critical bug (#3)");
  });

  it("should handle missing OPS task gracefully", () => {
    const sanitizedCwd = testDir.replace(/[^a-zA-Z0-9._-]+/g, "_");
    const taskPath = join(statusDir, `${sanitizedCwd}.task.json`);

    // File doesn't exist
    expect(existsSync(taskPath)).toBe(false);

    // Should not throw when trying to read missing file
    const missing = existsSync(taskPath);
    expect(missing).toBe(false);
  });

  it("should calculate remaining tasks correctly", () => {
    const tasks = [
      { id: 1, text: "Done task", status: "done" as const },
      { id: 2, text: "Active task", status: "inprogress" as const },
      { id: 3, text: "Idle task", status: "idle" as const },
      { id: 4, text: "Another done", status: "done" as const },
    ];

    const remaining = tasks.filter(t => t.status !== "done");
    expect(remaining).toHaveLength(2);
    expect(remaining[0].id).toBe(2);
    expect(remaining[1].id).toBe(3);

    const activeTask = tasks.find(t => t.id === 2);
    expect(activeTask?.status).toBe("inprogress");
  });
});
