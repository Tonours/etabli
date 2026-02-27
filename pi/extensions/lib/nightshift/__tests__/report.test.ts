import { describe, expect, test } from "bun:test";
import { generateMarkdownReport, generateJsonReport } from "../report.ts";
import type { RunReport } from "../types.ts";

const sampleReport: RunReport = {
  runId: "20240101120000-42",
  startedAt: "2024-01-01T12:00:00Z",
  finishedAt: "2024-01-01T12:30:00Z",
  verifyOnly: false,
  requireVerify: false,
  tasksFile: "/tmp/tasks.md",
  summary: { done: 1, failed: 1, skipped: 0 },
  tasks: [
    {
      taskId: "fix-login",
      status: "done",
      verify: "ok",
      branch: "night/fix-login",
      engine: "codex",
      repoDir: "/projects/app",
      worktree: "/worktrees/app-fix-login",
      startedAt: "2024-01-01T12:00:00Z",
      endedAt: "2024-01-01T12:10:00Z",
      error: "",
      logFile: "/logs/fix-login.log",
    },
    {
      taskId: "broken-task",
      status: "failed",
      verify: "failed",
      branch: "night/broken-task",
      engine: "codex",
      repoDir: "/projects/app",
      worktree: "/worktrees/app-broken-task",
      startedAt: "2024-01-01T12:10:00Z",
      endedAt: "2024-01-01T12:20:00Z",
      error: "verify failed",
      logFile: "/logs/broken-task.log",
    },
  ],
};

describe("generateMarkdownReport", () => {
  test("contains header with run metadata", () => {
    const md = generateMarkdownReport(sampleReport);
    expect(md).toContain("# Nightshift Run Report");
    expect(md).toContain("Run ID: 20240101120000-42");
    expect(md).toContain("Started at: 2024-01-01T12:00:00Z");
    expect(md).toContain("Verify only: false");
    expect(md).toContain("Require verify commands: false");
    expect(md).toContain("Tasks file: /tmp/tasks.md");
  });

  test("contains table with task rows", () => {
    const md = generateMarkdownReport(sampleReport);
    expect(md).toContain("| Task | Status | Verify | Branch | Error | Log |");
    expect(md).toContain("| fix-login | done | ok | night/fix-login | - |");
    expect(md).toContain("| broken-task | failed | failed | night/broken-task | verify failed |");
  });

  test("contains summary section", () => {
    const md = generateMarkdownReport(sampleReport);
    expect(md).toContain("## Summary");
    expect(md).toContain("Done: 1");
    expect(md).toContain("Failed: 1");
    expect(md).toContain("Skipped: 0");
    expect(md).toContain("Finished at: 2024-01-01T12:30:00Z");
  });
});

describe("generateJsonReport", () => {
  test("produces valid JSON matching report structure", () => {
    const json = generateJsonReport(sampleReport);
    const parsed = JSON.parse(json);

    expect(parsed.runId).toBe("20240101120000-42");
    expect(parsed.summary.done).toBe(1);
    expect(parsed.summary.failed).toBe(1);
    expect(parsed.tasks).toHaveLength(2);
    expect(parsed.tasks[0].taskId).toBe("fix-login");
    expect(parsed.tasks[1].error).toBe("verify failed");
  });

  test("is indented with 2 spaces and ends with newline", () => {
    const json = generateJsonReport(sampleReport);
    expect(json).toContain("  ");
    expect(json.endsWith("\n")).toBe(true);
  });

  test("handles empty tasks array", () => {
    const empty: RunReport = {
      ...sampleReport,
      summary: { done: 0, failed: 0, skipped: 0 },
      tasks: [],
    };
    const json = generateJsonReport(empty);
    const parsed = JSON.parse(json);
    expect(parsed.tasks).toEqual([]);
    expect(parsed.summary.done).toBe(0);
  });
});
