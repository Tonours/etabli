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

describe("workflow ops extensions", () => {
  test("health-check reports repo wiring", async () => {
    const cwd = makeDir("health-check-");
    mkdirSync(join(cwd, "pi", "extensions"), { recursive: true });
    mkdirSync(join(cwd, "pi", "agent"), { recursive: true });
    mkdirSync(join(cwd, "nvim", "lua", "config", "ops"), { recursive: true });
    mkdirSync(join(cwd, "claude", "commands"), { recursive: true });
    mkdirSync(join(homeDir, ".pi", "status"), { recursive: true });

    for (const file of [
      "fast-handoff",
      "tilldone-ops-sync",
      "review-plan-bridge",
      "auto-validate",
      "workflow-metrics",
      "project-switcher",
      "task-templates",
      "auto-resume",
      "scope-guard",
      "pre-flight",
      "smart-context",
      "health-check",
      "error-recovery",
      "context-help",
    ]) {
      writeFileSync(join(cwd, "pi", "extensions", `${file}.ts`), "export default 1;", "utf-8");
    }

    writeFileSync(join(cwd, "pi", "agent", "settings.json"), JSON.stringify({ packages: [{ source: "local:etabli-workflow", extensions: ["fast-handoff.ts"] }], subagents: { scout: { model: "kimi" } } }), "utf-8");
    writeFileSync(join(cwd, "nvim", "lua", "config", "ops", "tilldone.lua"), "return {}", "utf-8");
    writeFileSync(join(cwd, "nvim", "lua", "config", "ops", "init.lua"), 'local tilldone = require("config.ops.tilldone")', "utf-8");
    writeFileSync(join(cwd, "claude", "commands", "ops-status.md"), "ok", "utf-8");
    writeFileSync(join(cwd, "claude", "commands", "ops-pi-status.md"), "ok", "utf-8");
    writeFileSync(join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.ops.json`), "{}", "utf-8");
    writeFileSync(join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.tilldone-ops.json`), "{}", "utf-8");

    const mod = await import("../health-check.ts");
    const report = mod.runHealthCheck(cwd);
    expect(report.summary.error).toBe(0);
    expect(mod.formatReport(report)).toContain("All systems operational");

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.command("health", "", ctx);
    expect(harness.messages.at(-1)?.customType).toBe("health-check");
  });

  test("pre-flight detects risky edits and writes snapshots", async () => {
    const cwd = makeDir("pre-flight-");
    writeFileSync(join(cwd, "PLAN.md"), "plan", "utf-8");

    const mod = await import("../pre-flight.ts");
    expect(mod.isRiskyOperation({ toolName: "bash", input: { command: "rm -rf build" } })).toBe(true);
    expect(mod.isRiskyOperation({ toolName: "bash", input: { command: "echo hi >> build.log" } })).toBe(false);
    expect(mod.isRiskyOperation({ toolName: "write", input: { path: join(cwd, "PLAN.md"), content: "next" } })).toBe(true);
    expect(mod.getFilesToSnapshot(cwd, { toolName: "bash", input: { command: "bun test src/file.ts" } })).toEqual(["src/file.ts"]);
    expect(mod.getFilesToSnapshot(cwd, { toolName: "edit", input: { path: "PLAN.md", oldText: "plan", newText: "next" } })).toEqual(["PLAN.md"]);

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.emit("tool_call", { toolName: "bash", input: { command: "echo ok" } }, ctx);
    await harness.emit("tool_call", { toolName: "write", input: { path: join(cwd, "PLAN.md"), content: "next" } }, ctx);
    expect(ctx.ui.notifications.at(-1)?.message).toContain("Snapshot created");

    await harness.command("snapshots", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("Snapshots");

    await harness.command("snapshot-create", "manual", ctx);
    const toolResult = (await harness.tool("snapshot_create", { reason: "manual", files: ["PLAN.md"] }, ctx)) as {
      details: { fileCount: number };
    };
    expect(toolResult.details.fileCount).toBe(1);
  });

  test("scope-guard parses plan scope and warns on drift", async () => {
    const cwd = makeDir("scope-guard-");
    writeFileSync(
      join(cwd, "PLAN.md"),
      [
        "# Plan",
        "- Status: READY",
        "",
        "## Goal",
        "Ship workflow sync",
        "",
        "## Non-goals",
        "- add analytics dashboard",
        "",
        "## Invariants",
        "- keep docs fresh",
        "",
        "### Slice 1",
        "Touch `pi/extensions/demo.ts`",
      ].join("\n"),
      "utf-8",
    );

    const mod = await import("../scope-guard.ts");
    const scope = mod.readPlanScope(cwd);
    expect(scope?.files).toContain("pi/extensions/demo.ts");
    const checks = mod.checkForScopeCreep({ toolName: "write", input: { path: "other.ts", content: "analytics dashboard" } }, scope);
    expect(checks.length).toBeGreaterThan(0);

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.emit("session_start", {}, ctx);
    for (let index = 0; index < 5; index += 1) {
      await harness.emit("tool_call", { toolName: "write", input: { path: "other.ts", content: "analytics dashboard" } }, ctx);
    }
    expect(harness.messages.at(-1)?.customType).toBe("scope-guard");
  });

  test("smart-context learns tool usage and returns suggestions", async () => {
    const cwd = makeDir("smart-context-");
    const mod = await import("../smart-context.ts");
    expect(mod.extractFilePatterns(["pi/extensions/a.ts", "pi/extensions/b.ts", "docs/readme.md"]).length).toBeGreaterThan(0);

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.emit("tool_call", { toolName: "read", input: { path: "pi/extensions/a.ts" } }, ctx);
    await harness.emit("tool_call", { toolName: "validate", input: {} }, ctx);

    await harness.command("suggest", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("Smart Suggestions");

    const toolResult = (await harness.tool("smart_suggest", { context: "implementation" }, ctx)) as {
      details: { hasHistory: boolean; suggestions: string[] };
    };
    expect(toolResult.details.hasHistory).toBe(true);
    expect(toolResult.details.suggestions).toContain("read");
  });
});
