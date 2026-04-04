/// <reference path="./bun-test.d.ts" />
import { afterEach, describe, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createHarness, createMockContext } from "./workflow-harness.ts";

const homeDir = join(tmpdir(), "workflow-shared-home");
mkdirSync(homeDir, { recursive: true });
process.env.HOME = homeDir;

const tempDirs: string[] = [];

function makeDir(prefix: string): string {
  const dir = mkdtempSync(join(tmpdir(), prefix));
  tempDirs.push(dir);
  return dir;
}

afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    if (existsSync(dir)) rmSync(dir, { recursive: true, force: true });
  }
  if (existsSync(join(homeDir, ".pi"))) rmSync(join(homeDir, ".pi"), { recursive: true, force: true });
  if (existsSync(join(homeDir, ".local"))) rmSync(join(homeDir, ".local"), { recursive: true, force: true });
});

describe("workflow runtime extensions", () => {
  test("auto-validate formats validation results and warns on challenged plans", async () => {
    const cwd = makeDir("auto-validate-");
    writeFileSync(join(cwd, "PLAN.md"), ["# Plan", "- Status: CHALLENGED", "", "## Goal", "Fix ops"].join("\n"), "utf-8");

    const mod = await import("../auto-validate.ts");
    const suite = mod.runAllValidations(cwd);
    expect(suite.summary.fail).toBeGreaterThanOrEqual(1);
    expect(mod.formatValidationReport(suite)).toContain("Summary:");

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.emit("session_start", {}, ctx);
    expect(harness.messages.at(-1)?.content).toContain("CHALLENGED");

    const toolResult = (await harness.tool("validate", {}, ctx)) as { details: { canContinue: boolean } };
    expect(toolResult.details.canContinue).toBe(false);
  });

  test("fast-handoff writes handoff files from local OPS state", async () => {
    const cwd = makeDir("fast-handoff-");
    mkdirSync(join(homeDir, ".pi", "status"), { recursive: true });
    writeFileSync(
      join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.ops.json`),
      JSON.stringify({
        kind: "ops-snapshot",
        version: 1,
        project: "demo",
        cwd,
        generatedAt: new Date().toISOString(),
        revision: 1,
        paths: {
          snapshot: join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.ops.json`),
          task: join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.task.json`),
          plan: join(cwd, "PLAN.md"),
          runtime: join(cwd, ".pi", "runtime.json"),
          handoffImplement: join(cwd, ".pi", "handoff-implement.md"),
          handoffGeneric: join(cwd, ".pi", "handoff.md"),
        },
        plan: {
          state: "available",
          path: join(cwd, "PLAN.md"),
          status: "READY",
          plannedSlice: null,
          activeSlice: "Sync OPS",
          completedSlices: ["Plan"],
          pendingChecks: ["bun test"],
          lastValidatedState: "clean",
          nextRecommendedAction: "Run bun test",
          warnings: [],
        },
        review: { state: "available", source: "stored", mayBeStale: false, refreshedAt: null, actionable: 1, line: "1 actionable", warnings: [] },
        runtime: { state: "available", source: null, phase: "idle", tool: null, model: null, thinking: null, updatedAt: null, warnings: [] },
        handoff: { state: "missing", kind: null, path: null },
        mode: { state: "available", mode: "standard", explicit: false, hint: { roles: "main", review: "parallel", scope: "single" }, warnings: [] },
        nextAction: { value: "Run bun test", reason: "pending checks", derivedFrom: "plan" },
        task: {
          taskId: "demo",
          title: "demo",
          repo: "demo",
          workspacePath: cwd,
          branch: null,
          identitySource: "cwd",
          titleSource: "plan",
          lifecycleState: "running",
          mode: "standard",
          planStatus: "READY",
          runtimePhase: "idle",
          reviewSummary: "1 actionable",
          nextAction: "Run bun test",
          activeSlice: "Sync OPS",
          completedSlices: ["Plan"],
          pendingChecks: ["bun test"],
          lastValidatedState: "clean",
          revision: 1,
          updatedAt: new Date().toISOString(),
        },
      }),
      "utf-8",
    );
    writeFileSync(join(cwd, "PLAN.md"), ["## Goal", "Ship fast handoff", "", "## Constraints", "- Keep it local"].join("\n"), "utf-8");

    const mod = await import("../fast-handoff.ts");
    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);

    await harness.command("fast-handoff", "", ctx);
    expect(readFileSync(join(cwd, ".pi", "handoff.md"), "utf-8")).toContain("Ship fast handoff");

    await harness.command("fast-handoff-implement", "", ctx);
    expect(readFileSync(join(cwd, ".pi", "handoff-implement.md"), "utf-8")).toContain("Sync OPS");
  });

  test("review bridge converts inbox data into tasks and plan slices", async () => {
    const cwd = makeDir("review-bridge-");
    mkdirSync(join(homeDir, ".local", "share", "nvim", "etabli", "review"), { recursive: true });
    writeFileSync(join(cwd, "PLAN.md"), "# Plan", "utf-8");
    writeFileSync(
      join(homeDir, ".local", "share", "nvim", "etabli", "review", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.json`),
      JSON.stringify({ entries: [{ id: "1", filePath: "a.ts", hunkHeader: "@@", status: "needs-rework", note: "Fix edge case", scope: "WORKING", patchHash: "x" }], updatedAt: new Date().toISOString() }),
      "utf-8",
    );

    const mod = await import("../review-plan-bridge.ts");
    expect(mod.generateTillDoneTasksFromReview(mod.buildBridgeActions({ entries: [{ id: "1", filePath: "a.ts", hunkHeader: "@@", status: "needs-rework", note: "Fix edge case", scope: "WORKING", patchHash: "x" }], updatedAt: "now" }))).toHaveLength(1);

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.command("review-to-tilldone", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("Ready to create");

    const toolResult = (await harness.tool("review_to_tilldone", {}, ctx)) as { details: { created: number } };
    expect(toolResult.details.created).toBe(1);
  });

  test("tilldone sync exports task state and workflow metrics read summaries", async () => {
    const cwd = makeDir("tilldone-sync-");
    mkdirSync(join(homeDir, ".pi", "status"), { recursive: true });
    writeFileSync(join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.task.json`), JSON.stringify({ nextAction: "old" }), "utf-8");

    const syncMod = await import("../tilldone-ops-sync.ts");
    const syncHarness = createHarness();
    syncMod.default(syncHarness.api as never);
    const branch = [
      {
        type: "message",
        message: {
          role: "toolResult",
          toolName: "tilldone",
          details: {
            tasks: [
              { id: 1, text: "Plan change", status: "done" },
              { id: 2, text: "Run tests", status: "inprogress" },
            ],
            listTitle: "Workflow",
            listDescription: "Tasks",
          },
        },
      },
    ];
    const syncCtx = createMockContext(cwd, branch);
    await syncHarness.emit("agent_end", {}, syncCtx);
    const state = JSON.parse(readFileSync(join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.tilldone-ops.json`), "utf-8")) as { activeTaskId: number };
    expect(state.activeTaskId).toBe(2);

    const toolResult = (await syncHarness.tool("tilldone_ops_read", {}, syncCtx)) as { details: { found: boolean; remainingCount: number } };
    expect(toolResult.details.found).toBe(true);
    expect(toolResult.details.remainingCount).toBe(1);

    const metricsMod = await import("../workflow-metrics.ts");
    expect(metricsMod.calculatePhaseBreakdown([{ sessionId: "1", cwd, startTime: 0, phases: [{ phase: "plan", startTime: 0, durationMs: 60000 }], toolsUsed: [] }])).toEqual({ plan: 60000 });
    const summary = metricsMod.generateSummary([{ date: "2026-01-01", sessions: [], totalTimeMs: 60000, phaseBreakdown: { plan: 60000 }, toolUsage: { read: 1 } }]);
    expect(summary.totalTimeHours).toBe(0);

    const metricsHarness = createHarness();
    metricsMod.default(metricsHarness.api as never);
    const metricsCtx = createMockContext(cwd);
    await metricsHarness.emit("session_start", {}, metricsCtx);
    await metricsHarness.emit("tool_call", { toolName: "read" }, metricsCtx);
    await metricsHarness.emit("tool_call", { toolName: "edit" }, metricsCtx);
    await metricsHarness.emit("agent_end", {}, metricsCtx);
    await metricsHarness.command("metrics-today", "", metricsCtx);
    await metricsHarness.command("metrics-summary", "", metricsCtx);
    const metricsResult = (await metricsHarness.tool("workflow_metrics_read", { days: 1 }, metricsCtx)) as {
      details: { found: boolean; summary: { totalSessions: number } | null };
    };
    expect(metricsResult.details.found).toBe(true);
    expect(metricsResult.details.summary?.totalSessions).toBeGreaterThan(0);
  });
});
