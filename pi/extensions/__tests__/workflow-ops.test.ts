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

describe("workflow ops extensions", () => {
  test("health-check reports repo wiring for the minimal core", async () => {
    const cwd = makeDir("health-check-");
    mkdirSync(join(cwd, "pi", "extensions"), { recursive: true });
    mkdirSync(join(cwd, "pi", "agent"), { recursive: true });
    mkdirSync(join(cwd, "nvim", "lua", "config", "ops"), { recursive: true });
    mkdirSync(join(cwd, "claude", "commands"), { recursive: true });
    mkdirSync(join(homeDir, ".pi", "status"), { recursive: true });

    for (const file of [
      "fast-handoff",
      "review-plan-bridge",
      "scope-guard",
      "health-check",
      "rtk",
      "subagent",
      "tilldone",
      "tilldone-ops-sync",
    ]) {
      writeFileSync(join(cwd, "pi", "extensions", `${file}.ts`), "export default 1;", "utf-8");
    }

    writeFileSync(
      join(cwd, "pi", "agent", "settings.json"),
      JSON.stringify({
        packages: [{
          source: "local:etabli-workflow",
          extensions: [
            "fast-handoff.ts",
            "review-plan-bridge.ts",
            "scope-guard.ts",
            "health-check.ts",
            "rtk.ts",
            "subagent.ts",
            "tilldone.ts",
            "tilldone-ops-sync.ts",
          ],
        }],
        subagents: { scout: { model: "kimi" } },
        rtk: { enabled: true, mode: "always", timeoutMs: 2500, maxCacheEntries: 256, maxCommandLength: 4000, dangerousCommandBypass: true },
      }),
      "utf-8",
    );
    writeFileSync(join(cwd, "nvim", "lua", "config", "ops", "tilldone.lua"), "return {}", "utf-8");
    writeFileSync(join(cwd, "nvim", "lua", "config", "ops", "init.lua"), 'local tilldone = require("config.ops.tilldone")', "utf-8");
    writeFileSync(join(cwd, "claude", "commands", "ops-status.md"), "ok", "utf-8");
    writeFileSync(join(cwd, "claude", "commands", "ops-pi-status.md"), "ok", "utf-8");
    writeFileSync(join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.ops.json`), "{}", "utf-8");
    writeFileSync(join(homeDir, ".pi", "status", `${cwd.replace(/[^a-zA-Z0-9._-]+/g, "_")}.tilldone-ops.json`), "{}", "utf-8");

    const mod = await import("../health-check.ts");
    const report = mod.runHealthCheck(cwd);
    expect(report.summary.error).toBe(0);
    expect(mod.formatReport(report)).toContain("Summary:");

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);
    await harness.command("health", "", ctx);
    expect(harness.messages.at(-1)?.customType).toBe("health-check");
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
});
