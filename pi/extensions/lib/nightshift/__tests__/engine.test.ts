import { describe, expect, test, beforeEach } from "bun:test";
import { mkdtempSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { runEngine, writeTaskFiles } from "../engine.ts";

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), "nightshift-engine-test-"));
});

describe("writeTaskFiles", () => {
  test("creates .nightshift/TASK.md and ENGINE_PROMPT.txt", () => {
    writeTaskFiles(workDir, "my-task", "Fix the bug.", "codex", "main", "night/my-task", "app");

    const taskMd = readFileSync(join(workDir, ".nightshift", "TASK.md"), "utf-8");
    expect(taskMd).toContain("# Night Shift Task: my-task");
    expect(taskMd).toContain("Fix the bug.");
    expect(taskMd).toContain("Repo: app");
    expect(taskMd).toContain("Branch: night/my-task");

    const enginePrompt = readFileSync(join(workDir, ".nightshift", "ENGINE_PROMPT.txt"), "utf-8");
    expect(enginePrompt).toContain("senior engineer");
  });
});

describe("runEngine", () => {
  test("engine=none succeeds immediately", () => {
    const result = runEngine({
      workDir,
      taskId: "test",
      prompt: "test",
      engine: "none",
      logFile: join(workDir, "test.log"),
    });

    expect(result.success).toBe(true);
    expect(result.error).toBeUndefined();
  });

  test("engine=codex checks binary availability upfront", () => {
    // We can't test actual codex execution, but we can verify the
    // binary check runs and the function handles failure gracefully
    const result = runEngine({
      workDir,
      taskId: "test",
      prompt: "test",
      engine: "codex",
      logFile: join(workDir, "test.log"),
    });

    // Either missing binary or engine execution fails — both are handled
    expect(result.success).toBe(false);
    expect(result.error).toBeDefined();
  });
});
