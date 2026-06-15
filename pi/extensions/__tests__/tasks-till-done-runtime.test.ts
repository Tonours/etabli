import { describe, expect, test } from "bun:test";
import {
  appendTaskLoopGuidance,
  buildStopSummary,
  decideAutoContinue,
  parseTaskListOutput,
  shouldInjectTaskLoop,
} from "../lib/tasks-till-done-runtime.ts";

describe("tasks till-done runtime", () => {
  test("injects task loop guidance only when task tools are active", () => {
    expect(shouldInjectTaskLoop("Implémente le plan ready", ["TaskCreate"])).toBe(true);
    expect(shouldInjectTaskLoop("Implémente le plan ready", ["bash"])).toBe(false);
    expect(shouldInjectTaskLoop("/tasks", ["TaskCreate"])).toBe(false);
  });

  test("appends guidance once", () => {
    const first = appendTaskLoopGuidance("Base prompt");
    const second = appendTaskLoopGuidance(first);

    expect(first).toContain("# Etabli Task Loop");
    expect(second).toBe(first);
  });

  test("parses task list output into actionable and blocked counts", () => {
    const summary = parseTaskListOutput([
      "#1 [completed] Inspect settings",
      "#2 [in_progress] Patch extension",
      "#3 [pending] Run tests [blocked by #2]",
      "#4 [pending] Update docs",
    ].join("\n"));

    expect(summary).toMatchObject({
      total: 4,
      open: 3,
      actionable: 2,
      blocked: 1,
      hasValidationTask: true,
    });
    expect(summary?.signature).toBe("1:completed:free|2:in_progress:free|3:pending:blocked|4:pending:free");
  });

  test("detects validation tasks", () => {
    const summary = parseTaskListOutput([
      "#1 [completed] Patch extension",
      "#2 [completed] Run validation tests",
    ].join("\n"));

    expect(summary?.hasValidationTask).toBe(true);
  });

  test("treats empty task lists as complete", () => {
    expect(parseTaskListOutput("No tasks found")).toEqual({
      total: 0,
      open: 0,
      actionable: 0,
      blocked: 0,
      hasValidationTask: false,
      signature: "empty",
    });
  });

  test("continues only while the task loop has actionable work", () => {
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: { total: 2, open: 1, actionable: 1, blocked: 0, hasValidationTask: false, signature: "open" },
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
    })).toEqual({ continue: true, reason: "actionable_tasks" });

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: { total: 2, open: 0, actionable: 0, blocked: 0, hasValidationTask: true, signature: "done" },
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
    })).toEqual({ continue: false, reason: "complete" });

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: { total: 2, open: 1, actionable: 0, blocked: 1, hasValidationTask: false, signature: "blocked" },
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
    })).toEqual({ continue: false, reason: "blocked" });
  });

  test("requires validation evidence for implementation routes", () => {
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: { total: 1, open: 0, actionable: 0, blocked: 0, hasValidationTask: false, signature: "done" },
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      validationRequired: true,
    })).toEqual({ continue: true, reason: "validation_required" });
  });

  test("stops when limits or stall guards are reached", () => {
    const summary = { total: 1, open: 1, actionable: 1, blocked: 0, hasValidationTask: false, signature: "same" };

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary,
      autoContinueCount: 12,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
    })).toEqual({ continue: false, reason: "limit" });

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary,
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 2,
      maxStalledRepeats: 2,
    })).toEqual({ continue: false, reason: "stalled" });
  });

  test("builds visible stop summaries", () => {
    expect(buildStopSummary("blocked", {
      total: 2,
      open: 1,
      actionable: 0,
      blocked: 1,
      hasValidationTask: false,
      signature: "blocked",
    })).toBe("Task loop stopped: blocked (open=1, actionable=0, blocked=1).");
  });
});
