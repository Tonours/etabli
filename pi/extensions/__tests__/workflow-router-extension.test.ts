import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import workflowRouter from "../workflow-router.ts";

type Handler = (event: Record<string, unknown>) => unknown;

function setupExtension() {
  const handlers = new Map<string, Handler[]>();
  const entries: unknown[] = [];

  const pi = {
    on(eventName: string, handler: Handler) {
      handlers.set(eventName, [...(handlers.get(eventName) ?? []), handler]);
    },
    getActiveTools() {
      return ["TaskCreate", "TaskList"];
    },
    appendEntry(_customType: string, data?: unknown) {
      entries.push(data);
    },
  };

  workflowRouter(pi as Parameters<typeof workflowRouter>[0]);

  return {
    entries,
    emit(eventName: string, event: Record<string, unknown>) {
      return (handlers.get(eventName) ?? []).map((handler) => handler(event));
    },
  };
}

describe("workflow router extension", () => {
  test("uses actual PLAN.md status before routing to implement", () => {
    const runtime = setupExtension();
    const cwd = mkdtempSync(join(tmpdir(), "etabli-ready-plan-"));

    try {
      writeFileSync(join(cwd, "PLAN.md"), [
        "# PLAN.md",
        "",
        "## Meta",
        "- Status: READY",
        "",
      ].join("\n"));

      const results = runtime.emit("before_agent_start", {
        prompt: "Implémente le PLAN.md ready",
        systemPrompt: "Base prompt",
        cwd,
      });

      expect(results[0]).toEqual({
        systemPrompt: expect.stringContaining("Route: implement"),
      });
      expect(runtime.entries[0]).toMatchObject({
        decision: { route: "implement" },
      });
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  test("does not route prompt-only READY wording directly to implement", () => {
    const runtime = setupExtension();
    const cwd = mkdtempSync(join(tmpdir(), "etabli-missing-plan-"));

    try {
      const results = runtime.emit("before_agent_start", {
        prompt: "Implémente le PLAN.md ready",
        systemPrompt: "Base prompt",
        cwd,
      });

      expect(results[0]).toEqual({
        systemPrompt: expect.stringContaining("Route: plan-implement"),
      });
      expect(runtime.entries[0]).toMatchObject({
        decision: { route: "plan-implement" },
      });
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  test("does not route read-only READY plan prompts to implementation even with READY PLAN.md", () => {
    const runtime = setupExtension();
    const cwd = mkdtempSync(join(tmpdir(), "etabli-read-ready-plan-"));

    try {
      writeFileSync(join(cwd, "PLAN.md"), [
        "# PLAN.md",
        "",
        "## Meta",
        "- Status: READY",
        "",
      ].join("\n"));

      const results = runtime.emit("before_agent_start", {
        prompt: "Résume le PLAN.md ready",
        systemPrompt: "Base prompt",
        cwd,
      });

      expect(results).toEqual([undefined]);
      expect(runtime.entries[0]).toMatchObject({
        decision: { route: "answer", writeAllowed: false },
      });
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  test("skips explicit slash commands", () => {
    const runtime = setupExtension();

    const results = runtime.emit("before_agent_start", {
      prompt: "/skill:implement",
      systemPrompt: "Base prompt",
    });

    expect(results).toEqual([undefined]);
    expect(runtime.entries).toEqual([]);
  });

  test("injects Obvault guidance for a topic-aware answer", () => {
    const runtime = setupExtension();
    const results = runtime.emit("before_agent_start", {
      prompt: "Donne-moi des idées de SaaS",
      systemPrompt: "Base prompt",
    });

    expect(results[0]).toEqual({
      systemPrompt: expect.stringContaining("Knowledge topics: saas"),
    });
    expect(runtime.entries[0]).toMatchObject({
      version: "0.4.0",
      decision: { route: "answer", knowledgeContext: { topics: ["saas"] } },
    });
  });

  test("keeps unrelated answers free of router injection", () => {
    const runtime = setupExtension();
    const results = runtime.emit("before_agent_start", {
      prompt: "Bonjour, comment vas-tu ?",
      systemPrompt: "Base prompt",
    });

    expect(results).toEqual([undefined]);
    expect(runtime.entries[0]).toMatchObject({ decision: { route: "answer" } });
  });

  test("injects a newly discovered Obvault metadata topic", () => {
    const runtime = setupExtension();
    const root = mkdtempSync(join(tmpdir(), "etabli-pi-dynamic-vault-"));
    const previousRoot = process.env.OBVAULT_ROOT;

    try {
      mkdirSync(join(root, "kb"));
      mkdirSync(join(root, "ref"));
      writeFileSync(join(root, "AGENTS.md"), "# Test vault\n");
      writeFileSync(join(root, "kb/_index.md"), "# Index\n\n- [[finops-cost-controls]]\n");
      writeFileSync(join(root, "kb/finops-cost-controls.md"), `---
type: synthesis
status: verified
summary: "Cloud cost controls."
sources:
  - "repo:billing.md"
created: 2026-07-10
updated: 2026-07-10
tags:
  - finops
---
# FinOps Cost Controls
`);
      symlinkSync(join(import.meta.dir, "../../../../obvault/_meta"), join(root, "_meta"), "dir");
      process.env.OBVAULT_ROOT = root;

      const results = runtime.emit("before_agent_start", {
        prompt: "Donne-moi des idées FinOps",
        systemPrompt: "Base prompt",
      });

      expect(results[0]).toEqual({ systemPrompt: expect.stringContaining("Knowledge topics: finops") });
      expect(results[0]).toEqual({ systemPrompt: expect.stringContaining("Knowledge notes: kb/finops-cost-controls.md") });
      expect(runtime.entries[0]).toMatchObject({
        decision: { route: "answer", knowledgeContext: { source: "obvault-metadata" } },
      });
    } finally {
      if (previousRoot === undefined) delete process.env.OBVAULT_ROOT;
      else process.env.OBVAULT_ROOT = previousRoot;
      rmSync(root, { recursive: true, force: true });
    }
  });
});
