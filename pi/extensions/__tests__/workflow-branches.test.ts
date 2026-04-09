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

  test("health-check covers missing states", async () => {
    const cwd = makeDir("health-branches-");
    mkdirSync(join(cwd, "pi", "extensions"), { recursive: true });

    const health = await import("../health-check.ts");
    expect(health.checkSettings(cwd)[0]?.status).toBe("error");
    expect(health.formatReport(health.runHealthCheck(cwd))).toContain("Errors:");
  });

  test("review bridge, scope guard, and tilldone sync cover fallback branches", async () => {
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

    const scope = await import("../scope-guard.ts");
    const scopeHarness = createHarness();
    scope.default(scopeHarness.api as never);
    const scopeCtx = createMockContext(makeDir("no-plan-scope-"));
    await scopeHarness.command("scope-check", "", scopeCtx);
    expect(scopeCtx.ui.notifications.at(-1)?.message).toContain("No PLAN.md found");
    const bashChecks = scope.checkForScopeCreep({ toolName: "bash", input: { command: "git reset --hard" } }, { goal: "g", nonGoals: [], slices: [], files: [], invariants: [] });
    expect(bashChecks[0]?.type).toBe("error");

    const sync = await import("../tilldone-ops-sync.ts");
    const syncHarness = createHarness();
    sync.default(syncHarness.api as never);
    const syncCtx = createMockContext(makeDir("empty-tilldone-"), []);
    await syncHarness.command("tilldone-sync", "", syncCtx);
    expect(syncCtx.ui.notifications.at(-1)?.message).toContain("No TillDone state");
    const syncTool = (await syncHarness.tool("tilldone_ops_read", {}, syncCtx)) as { details: { found: boolean } };
    expect(syncTool.details.found).toBe(false);
  });
});
