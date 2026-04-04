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

describe("workflow helper extensions", () => {
  test("auto-resume surfaces recent handoff state and tasks", async () => {
    const cwd = makeDir("auto-resume-");
    mkdirSync(join(cwd, ".pi"), { recursive: true });
    writeFileSync(
      join(cwd, ".pi", "handoff-implement.md"),
      ["# Handoff", "- Active slice: Wire sync", "- Next recommended action: Run focused tests"].join("\n"),
      "utf-8",
    );

    const mod = await import("../auto-resume.ts");
    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);

    await harness.emit("session_start", {}, ctx);
    expect(harness.messages[0]?.content).toContain("Handoff detected");

    await harness.command("resume-from-handoff", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("Suggested tasks");
    expect(ctx.ui.notifications.at(-1)?.message).toContain("resume task");

    await harness.command("handoff-show", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("Wire sync");
  });

  test("context-help detects planning context and serves help topics", async () => {
    const cwd = makeDir("context-help-");
    writeFileSync(join(cwd, "PLAN.md"), ["# Plan", "- Status: READY", "", "## Goal", "Ship feature", "", "Active slice: Build UI"].join("\n"), "utf-8");

    const mod = await import("../context-help.ts");
    expect(mod.detectContext(cwd)).toBe("implementation");
    expect(mod.findHelpTopic("please help with review")?.id).toBe("review");

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);

    await harness.command("help", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("auto-detected");

    const toolResult = (await harness.tool("help_get", { topic: "planning" }, ctx)) as { details: { found: boolean; topic: string } };
    expect(toolResult.details.found).toBe(true);
    expect(toolResult.details.topic).toBe("planning");
  });

  test("error-recovery classifies tool failures and tracks retry status", async () => {
    const cwd = makeDir("error-recovery-");
    const mod = await import("../error-recovery.ts");
    expect(mod.classifyError("429 too many requests")?.action).toBe("retry");
    expect(mod.getFallbackModel("claude-3-opus-2024")).toBe("claude-3-sonnet");

    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);

    await harness.emit(
      "tool_result",
      {
        toolName: "bash",
        isError: true,
        content: [{ type: "text", text: "429 too many requests" }],
      },
      ctx,
    );
    expect(ctx.ui.notifications.at(-1)?.level).toBe("warning");

    await harness.command("error-status", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("Current retries: 1/3");

    await harness.emit("agent_end", {}, ctx);
    await harness.command("error-status", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("Current retries: 0/3");
  });

  test("project-switcher tracks projects and returns switch instructions", async () => {
    const first = makeDir("project-one-");
    const second = makeDir("project-two-");
    mkdirSync(join(homeDir, ".pi", "status"), { recursive: true });
    writeFileSync(join(homeDir, ".pi", "status", `${second.replace(/[^a-zA-Z0-9._-]+/g, "_")}.ops.json`), "{}", "utf-8");

    const mod = await import("../project-switcher.ts");
    const harness = createHarness();
    mod.default(harness.api as never);

    const firstCtx = createMockContext(first);
    const secondCtx = createMockContext(second);
    await harness.emit("session_start", {}, firstCtx);
    await harness.emit("session_start", {}, secondCtx);
    expect(mod.getRecentProjects(5).length).toBeGreaterThanOrEqual(2);

    await harness.command("favorite", "", secondCtx);
    expect(mod.getFavoriteProjects()[0]?.path).toBe(second);

    const toolResult = (await harness.tool("project_switch", { query: second.split("/").pop() || "" }, secondCtx)) as {
      details: { found: boolean; instructions: string[] };
    };
    expect(toolResult.details.found).toBe(true);
    expect(toolResult.details.instructions[0]).toContain("cd ");

    await harness.command("switch", second.split("/").pop() || "", firstCtx);
    expect(harness.messages.at(-1)?.content).toContain("OPS snapshot found");
  });

  test("task-templates list and return ready-made TillDone commands", async () => {
    const cwd = makeDir("task-templates-");
    const mod = await import("../task-templates.ts");
    const harness = createHarness();
    mod.default(harness.api as never);
    const ctx = createMockContext(cwd);

    await harness.command("templates", "", ctx);
    expect(harness.messages.at(-1)?.content).toContain("Task Templates");

    await harness.command("template-use", "pi-extension", ctx);
    expect(harness.messages.at(-1)?.content).toContain("tilldone new-list");

    const toolResult = (await harness.tool("task_template_get", { name: "bug" }, ctx)) as {
      details: { found: boolean; tilldoneCommand: string };
    };
    expect(toolResult.details.found).toBe(true);
    expect(toolResult.details.tilldoneCommand).toContain("bug-fix");
  });
});
