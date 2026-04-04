/// <reference path="./bun-test.d.ts" />
import { afterEach, describe, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
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

describe("workflow branch coverage", () => {
  test("auto-validate covers warn, skip, and command branches", async () => {
    const cwd = makeDir("auto-validate-branches-");
    writeFileSync(join(cwd, "PLAN.md"), ["# Plan", "- Status: DRAFT", "", "## Goal", "Ship it"].join("\n"), "utf-8");
    writeFileSync(join(cwd, "large.bin"), "x".repeat(600000), "utf-8");

    const mod = await import("../auto-validate.ts");
    expect(mod.checks.planExists(cwd).status).toBe("warn");
    expect(mod.checks.gitState(cwd).status).toBe("skip");
    expect(mod.checks.mergeConflicts(cwd).status).toBe("pass");
    expect(mod.checks.tsCompilation(cwd).status).toBe("skip");
    expect(mod.checks.largeFiles(cwd).status).toBe("warn");
    expect(mod.formatValidationReport(mod.runAllValidations(cwd))).toContain("Warnings present");

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.command("validate", "", ctx);
    expect(harness.messages.at(-1)?.customType).toBe("validation-report");
    process.env.PI_AUTO_VALIDATE = "1";
    await harness.emit("agent_end", {}, ctx);
    delete process.env.PI_AUTO_VALIDATE;
  });

  test("context-help covers no-match and auto-detect branches", async () => {
    const cwd = makeDir("context-help-branches-");
    const mod = await import("../context-help.ts");
    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);

    expect(mod.findHelpTopic("")).toBeNull();
    expect(mod.detectContext(cwd)).toBe("getting-started");
    await harness.emit("session_start", {}, ctx);
    expect(harness.messages.at(-1)?.customType).toBe("context-help");

    await harness.command("help", "unknown-topic", ctx);
    expect(ctx.ui.notifications.at(-1)?.level).toBe("warning");

    const toolResult = (await harness.tool("help_get", {}, ctx)) as { details: { found: boolean; autoDetected: boolean } };
    expect(toolResult.details.found).toBe(true);
    expect(toolResult.details.autoDetected).toBe(true);
  });

  test("error-recovery covers fallback, compact, and unknown errors", async () => {
    const cwd = makeDir("error-recovery-branches-");
    const mod = await import("../error-recovery.ts");
    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);

    await harness.emit("tool_result", { toolName: "bash", isError: true, content: [{ type: "text", text: "503 service unavailable" }] }, ctx);
    expect(harness.messages.at(-1)?.content).toContain("fallback");

    await harness.emit("tool_result", { toolName: "bash", isError: true, content: [{ type: "text", text: "maximum context exceeded" }] }, ctx);
    expect(harness.messages.at(-1)?.content).toContain("/compact");

    await harness.emit("tool_result", { toolName: "bash", isError: true, content: [{ type: "text", text: "weird failure" }] }, ctx);
    expect(ctx.ui.notifications.at(-1)?.level).toBe("error");
  });

  test("fast-handoff helper branches cover defaults and fallback states", async () => {
    const cwd = makeDir("fast-handoff-branches-");
    mkdirSync(join(homeDir, ".pi", "status"), { recursive: true });
    const mod = await import("../fast-handoff.ts");

    expect(mod.extractGoalFromPlan("## Goal\n\n")).toBe("Continue current implementation");
    expect(mod.extractConstraintsFromPlan("")).toEqual(["Follow existing code patterns", "Keep changes minimal"]);
    expect(mod.extractDecisionsFromPlan("## Decisions\n- no colon")).toEqual([]);
    expect(mod.extractOpenIssuesFromPlan("## Open Issues\n- (none)")).toEqual([]);
    expect(mod.resolveOutputPath(cwd, "", true)).toContain("handoff-implement.md");

    const data = {
      goal: "demo",
      currentState: "running",
      activeSlice: null,
      completedSlices: [],
      pendingChecks: [],
      lastValidatedState: null,
      nextRecommendedAction: null,
      planStatus: "READY",
      reviewActionable: 0,
      mode: "standard",
      lifecycleState: "running",
    };
    expect(mod.buildFastHandoff(data, null)).toContain("Select next slice to implement");
    expect(mod.buildFastHandoff({ ...data, pendingChecks: ["bun test"], planStatus: "DRAFT" }, null)).toContain("Run pending checks");
    expect(mod.generateFastHandoff(cwd, false)).toBeNull();

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.command("fast-handoff-implement", "", ctx);
    expect(ctx.ui.notifications.at(-1)?.message).toContain("requires READY plan");

    process.env.PI_AUTO_HANDOFF = "1";
    await harness.emit("agent_end", {}, ctx);
    delete process.env.PI_AUTO_HANDOFF;
  });

  test("health-check and project-switcher cover missing states", async () => {
    const cwd = makeDir("health-project-branches-");
    mkdirSync(join(cwd, "pi", "extensions"), { recursive: true });

    const health = await import("../health-check.ts");
    expect(health.checkSettings(cwd)[0]?.status).toBe("error");
    expect(health.checkClaudeCommands(cwd).every((item: { status: string }) => item.status === "warn")).toBe(true);
    expect(health.formatReport(health.runHealthCheck(cwd))).toContain("Warnings:");

    const projects = await import("../project-switcher.ts");
    const harness = createHarness();
    projects.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.command("projects", "", ctx);
    expect(harness.messages.at(-1)?.customType).toBe("project-list");
    await harness.command("switch", "", ctx);
    expect(ctx.ui.notifications.at(-1)?.message).toContain("Usage");
    await harness.command("favorite", "", ctx);
    const missing = (await harness.tool("project_switch", { query: "missing" }, ctx)) as { details: { found: boolean } };
    expect(missing.details.found).toBe(false);
  });

  test("review bridge, scope guard, smart context, and templates cover fallback branches", async () => {
    const cwd = makeDir("bridge-scope-branches-");
    writeFileSync(join(cwd, "PLAN.md"), ["# Plan", "- Status: READY", "", "## Goal", "Do work"].join("\n"), "utf-8");

    const bridge = await import("../review-plan-bridge.ts");
    const bridgeHarness = createHarness();
    bridge.default(bridgeHarness.api as never);
    const bridgeCtx = createMockContext(cwd);
    await bridgeHarness.command("review-to-tilldone", "", bridgeCtx);
    expect(bridgeCtx.ui.notifications.at(-1)?.message).toContain("No review state found");
    await bridgeHarness.command("review-to-plan", "", bridgeCtx);
    expect(bridgeCtx.ui.notifications.at(-1)?.message).toContain("No review state found");
    expect(bridge.generatePlanSliceFromReview([])).toBe("");

    mkdirSync(join(homeDir, ".local", "share", "nvim", "etabli", "review"), { recursive: true });
    writeFileSync(
      join(homeDir, ".local", "share", "nvim", "etabli", "review", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.json`),
      JSON.stringify({ entries: [{ id: "1", filePath: "a.ts", hunkHeader: "@@", status: "question", note: null, scope: "WORKING", patchHash: "p" }], updatedAt: new Date().toISOString() }),
      "utf-8",
    );
    mkdirSync(join(homeDir, ".pi", "status"), { recursive: true });
    writeFileSync(join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.ops.json`), JSON.stringify({ plan: { status: "READY" }, review: { actionable: 1 } }), "utf-8");
    await bridgeHarness.emit("session_start", {}, bridgeCtx);
    expect(bridgeHarness.messages.at(-1)?.customType).toBe("review-bridge-warning");

    const reviewRead = (await bridgeHarness.tool("review_state_read", {}, bridgeCtx)) as { details: { found: boolean; actionableCount: number } };
    expect(reviewRead.details.found).toBe(true);
    expect(reviewRead.details.actionableCount).toBe(1);

    await bridgeHarness.command("review-to-plan", "", bridgeCtx);
    expect(bridgeHarness.messages.at(-1)?.content).toContain("Proposed PLAN.md slice");
    const reviewTasks = (await bridgeHarness.tool("review_to_tilldone", {}, bridgeCtx)) as { details: { created: number } };
    expect(reviewTasks.details.created).toBe(1);

    const scope = await import("../scope-guard.ts");
    const scopeHarness = createHarness();
    scope.default(scopeHarness.api as never);
    const scopeCtx = createMockContext(makeDir("no-plan-scope-"));
    await scopeHarness.command("scope-check", "", scopeCtx);
    expect(scopeCtx.ui.notifications.at(-1)?.message).toContain("No PLAN.md found");
    const bashChecks = scope.checkForScopeCreep({ toolName: "bash", input: { command: "git reset --hard" } }, { goal: "g", nonGoals: [], slices: [], files: [], invariants: [] });
    expect(bashChecks[0]?.type).toBe("error");

    const smart = await import("../smart-context.ts");
    const smartHarness = createHarness();
    smart.default(smartHarness.api as never);
    const smartCtx = createMockContext(makeDir("no-history-smart-"));
    await smartHarness.command("suggest", "", smartCtx);
    expect(smartCtx.ui.notifications.at(-1)?.message).toContain("No history yet");

    const templates = await import("../task-templates.ts");
    const templateHarness = createHarness();
    templates.default(templateHarness.api as never);
    const templateCtx = createMockContext(cwd);
    await templateHarness.command("template-use", "", templateCtx);
    await templateHarness.command("template-use", "missing", templateCtx);
    const listResult = (await templateHarness.tool("task_template_list", {}, templateCtx)) as { details: { templates: Array<unknown> } };
    expect(listResult.details.templates.length).toBeGreaterThan(0);
  });

  test("tilldone sync and workflow metrics cover empty-state branches", async () => {
    const cwd = makeDir("tilldone-metrics-branches-");
    mkdirSync(join(homeDir, ".pi", "metrics"), { recursive: true });

    const sync = await import("../tilldone-ops-sync.ts");
    const syncHarness = createHarness();
    sync.default(syncHarness.api as never);
    const syncCtx = createMockContext(cwd, []);
    await syncHarness.command("tilldone-sync", "", syncCtx);
    expect(syncCtx.ui.notifications.at(-1)?.message).toContain("No TillDone state");
    const syncTool = (await syncHarness.tool("tilldone_ops_read", {}, syncCtx)) as { details: { found: boolean } };
    expect(syncTool.details.found).toBe(false);

    const metrics = await import("../workflow-metrics.ts");
    const metricsHarness = createHarness();
    metrics.default(metricsHarness.api as never);
    const metricsCtx = createMockContext(cwd);
    await metricsHarness.command("metrics-today", "", metricsCtx);
    await metricsHarness.command("metrics-summary", "", metricsCtx);
    const noData = (await metricsHarness.tool("workflow_metrics_read", { days: 2 }, metricsCtx)) as { details: { found: boolean } };
    expect(noData.details.found).toBe(false);
    expect(metrics.generateSummary([
      { date: "2026-01-01", sessions: [], totalTimeMs: 1000, phaseBreakdown: {}, toolUsage: {} },
      { date: "2026-01-02", sessions: [], totalTimeMs: 2000, phaseBreakdown: {}, toolUsage: {} },
    ]).trend).toBe("up");
  });
});
