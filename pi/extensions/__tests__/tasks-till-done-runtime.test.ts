import { describe, expect, test } from "bun:test";
import {
  appendTaskLoopGuidance,
  buildStopSummary,
  decideAutoContinue,
  detectTaskRuntimeCapabilityIssue,
  hasImplementationCompletionEvidence,
  parseStructuredTaskState,
  parseTaskListOutput,
  parseTaskToolResult,
  shouldInjectTaskLoop,
} from "../lib/tasks-till-done-runtime.ts";

describe("tasks till-done runtime", () => {
  test("injects task loop guidance only when task tools are active", () => {
    expect(shouldInjectTaskLoop("Implémente le plan ready", ["TaskCreate"])).toBe(true);
    expect(shouldInjectTaskLoop("Implémente le plan ready", ["bash"])).toBe(false);
    expect(shouldInjectTaskLoop("/tasks", ["TaskCreate"])).toBe(false);
    // Bare fix/update/go must not arm the auto-continue loop.
    expect(shouldInjectTaskLoop("fix typo in README", ["TaskCreate"])).toBe(false);
    expect(shouldInjectTaskLoop("go", ["TaskCreate"])).toBe(false);
    expect(shouldInjectTaskLoop("update the docs", ["TaskCreate"])).toBe(false);
    expect(shouldInjectTaskLoop("create a todo list for this feature", ["TaskCreate"])).toBe(true);
    expect(shouldInjectTaskLoop("Continue the Task Loop. TaskList again.", ["TaskCreate"])).toBe(true);
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
      hasAdversaryTask: false,
      hasReviewTask: false,
      hasArchiveTask: false,
      hasPlanCleanupTask: false,
      evidenceSource: "text",
      guaranteeStatus: "proxy_supported",
    });
    expect(summary?.signature).toBe("1:completed:free|2:in_progress:free|3:pending:blocked|4:pending:free");
  });

  test("parses structured task state without TaskList text", () => {
    const summary = parseStructuredTaskState({
      tasks: [
        {
          id: "1",
          subject: "Run adversary plan review",
          description: "Challenge the READY plan before implementation",
          status: "completed",
          metadata: { kind: "adversary" },
        },
        {
          id: "2",
          subject: "Run validation tests",
          description: "Validate the changed orchestration",
          status: "in_progress",
          blockedBy: ["1"],
        },
        {
          id: "3",
          subject: "Archive implemented plan in docs/plan",
          description: "Archive after validation",
          status: "pending",
          blockedBy: ["2"],
        },
      ],
    });

    expect(summary).toMatchObject({
      total: 3,
      open: 2,
      actionable: 1,
      blocked: 1,
      hasAdversaryTask: true,
      hasValidationTask: true,
      hasArchiveTask: true,
      evidenceSource: "structured",
      guaranteeStatus: "confirmed",
    });
    expect(summary?.signature).toBe("1:completed:free|2:in_progress:free|3:pending:blocked");
  });

  test("prefers structured task details over parseable TaskList text", () => {
    const summary = parseTaskToolResult({
      details: {
        data: {
          tasks: [
            { id: "1", subject: "Structured task", status: "pending" },
            { id: "2", subject: "Structured blocked task", status: "pending", blockedBy: ["1"] },
          ],
        },
      },
      text: "#1 [completed] Text task",
    });

    expect(summary).toMatchObject({
      total: 2,
      open: 2,
      actionable: 1,
      blocked: 1,
      evidenceSource: "structured",
      guaranteeStatus: "confirmed",
    });
    expect(summary?.signature).toBe("1:pending:free|2:pending:blocked");
  });

  test("falls back to TaskList text when structured details are unavailable", () => {
    const summary = parseTaskToolResult({
      details: undefined,
      text: "#1 [pending] Run tests",
    });

    expect(summary).toMatchObject({
      total: 1,
      evidenceSource: "text",
      guaranteeStatus: "proxy_supported",
      fallbackReason: "TaskList tool result did not expose structured task details.",
    });
  });

  test("detects unavailable TaskExecute tracking as a blocked runtime capability", () => {
    const issue = detectTaskRuntimeCapabilityIssue(
      "TaskExecute",
      "Subagent execution is currently unavailable (@tintinweb/pi-subagents not loaded or version mismatch). pi-tasks won't track them — status stays pending, cascade won't fire, TaskOutput stays empty.",
    );

    expect(issue).toEqual({
      kind: "subagent_execution_unavailable",
      guaranteeStatus: "blocked",
      message: "TaskExecute subagent tracking is unavailable. Do not retry TaskExecute until the subagents:rpc protocol is confirmed.",
    });
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: undefined,
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      runtimeCapabilityIssue: issue,
    })).toEqual({ continue: false, reason: "runtime_capability_blocked" });
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
      hasAdversaryTask: false,
      hasReviewTask: false,
      hasArchiveTask: false,
      hasPlanCleanupTask: false,
      signature: "empty",
      evidenceSource: "text",
      guaranteeStatus: "proxy_supported",
    });
  });

  test("continues only while the task loop has actionable work", () => {
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: { total: 2, open: 1, actionable: 1, blocked: 0, hasValidationTask: false, hasAdversaryTask: false, hasReviewTask: false, hasArchiveTask: false, hasPlanCleanupTask: false, signature: "open" },
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
    })).toEqual({ continue: true, reason: "actionable_tasks" });

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: { total: 2, open: 0, actionable: 0, blocked: 0, hasValidationTask: true, hasAdversaryTask: false, hasReviewTask: false, hasArchiveTask: false, hasPlanCleanupTask: false, signature: "done" },
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
    })).toEqual({ continue: false, reason: "complete" });

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: { total: 2, open: 1, actionable: 0, blocked: 1, hasValidationTask: false, hasAdversaryTask: false, hasReviewTask: false, hasArchiveTask: false, hasPlanCleanupTask: false, signature: "blocked" },
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
      summary: { total: 1, open: 0, actionable: 0, blocked: 0, hasValidationTask: false, hasAdversaryTask: false, hasReviewTask: false, hasArchiveTask: false, hasPlanCleanupTask: false, signature: "done" },
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      validationRequired: true,
    })).toEqual({ continue: true, reason: "validation_required" });
  });

  test("requires full implementation completion evidence before autonomous plan completion", () => {
    const verifiedRuntimeEvidence = {
      hasImplementedPlanArchive: true,
      rootPlanDeleted: true,
    };

    const incompleteSummary = parseTaskListOutput([
      "#1 [completed] Implement READY plan steps",
      "#2 [completed] Run validation tests",
    ].join("\n"));

    expect(incompleteSummary).toBeDefined();
    expect(hasImplementationCompletionEvidence(incompleteSummary!)).toBe(false);
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: incompleteSummary,
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      implementationCompletionRequired: true,
    })).toEqual({ continue: true, reason: "completion_evidence_required" });

    const genericCleanupSummary = parseTaskListOutput([
      "#1 [completed] Implement READY plan steps",
      "#2 [completed] Run adversary plan review",
      "#3 [completed] Run validation tests",
      "#4 [completed] Review diff against PLAN.md",
      "#5 [completed] Archive implemented plan in docs/plan",
      "#6 [completed] Cleanup imports",
    ].join("\n"));

    expect(genericCleanupSummary).toBeDefined();
    expect(genericCleanupSummary!.hasPlanCleanupTask).toBe(false);
    expect(hasImplementationCompletionEvidence(genericCleanupSummary!)).toBe(false);
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: genericCleanupSummary,
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      implementationCompletionRequired: true,
    })).toEqual({ continue: true, reason: "completion_evidence_required" });

    const adversaryOnlyReviewSummary = parseTaskListOutput([
      "#1 [completed] Implement READY plan steps",
      "#2 [completed] Run adversary plan review",
      "#3 [completed] Run validation tests",
      "#4 [completed] Archive implemented plan in docs/plan",
      "#5 [completed] Delete root PLAN.md after archive",
    ].join("\n"));

    expect(adversaryOnlyReviewSummary).toBeDefined();
    expect(adversaryOnlyReviewSummary!.hasAdversaryTask).toBe(true);
    expect(adversaryOnlyReviewSummary!.hasReviewTask).toBe(false);
    expect(hasImplementationCompletionEvidence(adversaryOnlyReviewSummary!)).toBe(false);
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: adversaryOnlyReviewSummary,
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      implementationCompletionRequired: true,
    })).toEqual({ continue: true, reason: "completion_evidence_required" });

    const weakEvidenceSummary = parseTaskListOutput([
      "#1 [completed] Implement READY plan steps",
      "#2 [completed] Run adversarial code review",
      "#3 [completed] Run validation tests",
      "#4 [completed] Review diff against PLAN.md",
      "#5 [completed] Archive terminal logs",
      "#6 [completed] Remove PLAN.md references from docs",
    ].join("\n"));

    expect(weakEvidenceSummary).toBeDefined();
    expect(weakEvidenceSummary!.hasAdversaryTask).toBe(false);
    expect(weakEvidenceSummary!.hasArchiveTask).toBe(false);
    expect(weakEvidenceSummary!.hasPlanCleanupTask).toBe(false);
    expect(hasImplementationCompletionEvidence(weakEvidenceSummary!)).toBe(false);
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: weakEvidenceSummary,
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      implementationCompletionRequired: true,
    })).toEqual({ continue: true, reason: "completion_evidence_required" });

    const completeSummary = parseTaskListOutput([
      "#1 [completed] Implement READY plan steps",
      "#2 [completed] Run adversary plan review",
      "#3 [completed] Run validation tests",
      "#4 [completed] Review diff against PLAN.md",
      "#5 [completed] Archive implemented plan in docs/plan",
      "#6 [completed] Delete root PLAN.md after archive",
    ].join("\n"));

    expect(completeSummary).toBeDefined();
    expect(hasImplementationCompletionEvidence(completeSummary!)).toBe(false);
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: completeSummary,
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      implementationCompletionRequired: true,
    })).toEqual({ continue: true, reason: "completion_evidence_required" });
    expect(hasImplementationCompletionEvidence(completeSummary!, verifiedRuntimeEvidence)).toBe(true);
    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: completeSummary,
      autoContinueCount: 0,
      maxAutoContinues: 12,
      stalledCount: 0,
      maxStalledRepeats: 2,
      implementationCompletionRequired: true,
      implementationRuntimeEvidence: verifiedRuntimeEvidence,
    })).toEqual({ continue: false, reason: "complete" });
  });

  test("stops when limits or stall guards are reached", () => {
    const summary = { total: 1, open: 1, actionable: 1, blocked: 0, hasValidationTask: false, hasAdversaryTask: false, hasReviewTask: false, hasArchiveTask: false, hasPlanCleanupTask: false, signature: "same" };

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary,
      autoContinueCount: 6,
      maxAutoContinues: 6,
      stalledCount: 0,
      maxStalledRepeats: 1,
    })).toEqual({ continue: false, reason: "limit" });

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary,
      autoContinueCount: 0,
      maxAutoContinues: 6,
      stalledCount: 1,
      maxStalledRepeats: 1,
    })).toEqual({ continue: false, reason: "stalled" });
  });

  test("caps forced validation and completion-evidence continues", () => {
    const empty = {
      total: 0,
      open: 0,
      actionable: 0,
      blocked: 0,
      hasValidationTask: false,
      hasAdversaryTask: false,
      hasReviewTask: false,
      hasArchiveTask: false,
      hasPlanCleanupTask: false,
      signature: "empty",
    };

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: empty,
      autoContinueCount: 0,
      maxAutoContinues: 6,
      stalledCount: 0,
      maxStalledRepeats: 1,
      validationRequired: true,
      validationContinueCount: 0,
      maxValidationContinues: 1,
    })).toEqual({ continue: true, reason: "validation_required" });

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: empty,
      autoContinueCount: 1,
      maxAutoContinues: 6,
      stalledCount: 0,
      maxStalledRepeats: 1,
      validationRequired: true,
      validationContinueCount: 1,
      maxValidationContinues: 1,
    })).toEqual({ continue: false, reason: "limit" });

    expect(decideAutoContinue({
      active: true,
      taskToolUsed: true,
      summary: empty,
      autoContinueCount: 2,
      maxAutoContinues: 6,
      stalledCount: 0,
      maxStalledRepeats: 1,
      implementationCompletionRequired: true,
      completionEvidenceContinueCount: 2,
      maxCompletionEvidenceContinues: 2,
    })).toEqual({ continue: false, reason: "limit" });
  });

  test("builds visible stop summaries", () => {
    expect(buildStopSummary("blocked", {
      total: 2,
      open: 1,
      actionable: 0,
      blocked: 1,
      hasValidationTask: false,
      hasAdversaryTask: false,
      hasReviewTask: false,
      hasArchiveTask: false,
      hasPlanCleanupTask: false,
      signature: "blocked",
    })).toBe("Task loop stopped: blocked (open=1, actionable=0, blocked=1).");
  });
});
