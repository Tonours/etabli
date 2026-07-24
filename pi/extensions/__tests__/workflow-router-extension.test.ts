import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import workflowRouter from "../workflow-router.ts";

type Handler = (event: Record<string, unknown>) => unknown;

function setupExtension(activeTools = ["TaskCreate", "TaskList", "Agent", "get_subagent_result"]) {
  const handlers = new Map<string, Handler[]>();
  const entries: unknown[] = [];

  const pi = {
    on(eventName: string, handler: Handler) {
      handlers.set(eventName, [...(handlers.get(eventName) ?? []), handler]);
    },
    getActiveTools() {
      return activeTools;
    },
    appendEntry(_customType: string, data?: unknown) {
      entries.push(data);
    },
  };

  workflowRouter(pi as unknown as Parameters<typeof workflowRouter>[0]);

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
      version: "0.6.0",
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

  test("injects pending or degraded panel guidance from active tools", () => {
    const pending = setupExtension();
    const pendingResults = pending.emit("before_agent_start", {
      prompt: "Fais un plan d'architecture avec un panel multi-modèle",
      systemPrompt: "Base prompt",
    });
    expect(pendingResults[0]).toEqual({
      systemPrompt: expect.stringContaining("Multi-execution request: pending explicit council"),
    });

    const degraded = setupExtension(["TaskCreate", "TaskList"]);
    const degradedResults = degraded.emit("before_agent_start", {
      prompt: "Fais un plan d'architecture avec un panel multi-modèle",
      systemPrompt: "Base prompt",
    });
    expect(degradedResults[0]).toEqual({
      systemPrompt: expect.stringContaining("Multi-execution request: degraded"),
    });
  });

  test("mechanically bounds Etabli portfolio calls for an active council", () => {
    const runtime = setupExtension();
    runtime.emit("before_agent_start", {
      prompt: "Fais une review de sécurité de cette race condition",
      systemPrompt: "Base prompt",
    });
    runtime.emit("before_agent_start", { prompt: "", systemPrompt: "Base prompt" });

    const call = (toolCallId: string, subagent_type: string, extra: Record<string, unknown> = {}) =>
      runtime.emit("tool_call", { toolName: "Agent", toolCallId, input: { subagent_type, ...extra } })[0];
    const result = (toolCallId: string, subagentType: string, agentId: string, status = "background") =>
      runtime.emit("tool_result", {
        toolName: "Agent",
        toolCallId,
        input: { subagent_type: subagentType },
        content: [],
        details: { subagentType, agentId, status },
        isError: false,
      });
    const retrieve = (agentId: string, status: string) =>
      runtime.emit("tool_result", {
        toolName: "get_subagent_result",
        toolCallId: `get-${agentId}-${status}`,
        input: { agent_id: agentId, wait: true },
        content: [{ type: "text", text: `Agent: ${agentId}\nType: test | Status: ${status}` }],
        isError: false,
      });

    expect(call("start-luna", "etabli-luna-scout")).toBeUndefined();
    result("start-luna", "etabli-luna-scout", "luna-id");
    expect(call("start-glm", "etabli-glm-challenger")).toBeUndefined();
    result("start-glm", "etabli-glm-challenger", "glm-id");
    expect(call("early-sol", "etabli-sol-judge")).toMatchObject({ block: true });
    expect(call("cross-role-resume", "etabli-glm-challenger", { resume: "luna-id" })).toMatchObject({ block: true });
    expect(call("premature-luna", "etabli-luna-scout", { resume: "luna-id" })).toMatchObject({ block: true });
    retrieve("luna-id", "completed");
    retrieve("glm-id", "completed");
    expect(call("resume-luna", "etabli-luna-scout", { resume: "luna-id" })).toBeUndefined();
    expect(call("repeat-luna", "etabli-luna-scout", { resume: "luna-id" })).toMatchObject({ block: true });
    expect(call("resume-glm", "etabli-glm-challenger", { resume: "glm-id" })).toBeUndefined();
    expect(call("sol-before-results", "etabli-sol-judge")).toMatchObject({ block: true });
    result("resume-luna", "etabli-luna-scout", "luna-id", "completed");
    expect(call("sol-before-glm-result", "etabli-sol-judge")).toMatchObject({ block: true });
    result("resume-glm", "etabli-glm-challenger", "glm-id", "completed");
    expect(call("sol", "etabli-sol-judge")).toBeUndefined();
    expect(call("repeat-sol", "etabli-sol-judge")).toMatchObject({ block: true });
    expect(call("healthy-kimi", "etabli-kimi-fallback")).toMatchObject({ block: true });
    expect(call("terra", "etabli-terra-analyst")).toMatchObject({ block: true });
  });

  test("admits Kimi only after an observed primary failure", () => {
    const runtime = setupExtension();
    runtime.emit("before_agent_start", {
      prompt: "Fais une review de sécurité de cette race condition",
      systemPrompt: "Base prompt",
    });

    const call = (toolCallId: string, subagent_type: string, extra: Record<string, unknown> = {}) =>
      runtime.emit("tool_call", { toolName: "Agent", toolCallId, input: { subagent_type, ...extra } })[0];
    const result = (toolCallId: string, subagentType: string, agentId: string, status = "background") =>
      runtime.emit("tool_result", {
        toolName: "Agent",
        toolCallId,
        input: { subagent_type: subagentType },
        content: [],
        details: { subagentType, agentId, status },
        isError: false,
      });
    const retrieve = (agentId: string, status: string) => runtime.emit("tool_result", {
      toolName: "get_subagent_result",
      toolCallId: `get-${agentId}-${status}`,
      input: { agent_id: agentId, wait: true },
      content: [{ type: "text", text: `Agent: ${agentId}\nType: test | Status: ${status}` }],
      isError: false,
    });

    expect(call("start-luna", "etabli-luna-scout")).toBeUndefined();
    result("start-luna", "etabli-luna-scout", "luna-id");
    retrieve("luna-id", "error");
    expect(call("start-kimi", "etabli-kimi-fallback")).toBeUndefined();
    result("start-kimi", "etabli-kimi-fallback", "kimi-id");
    expect(call("repeat-kimi", "etabli-kimi-fallback")).toMatchObject({ block: true });
    expect(call("start-glm", "etabli-glm-challenger")).toBeUndefined();
    result("start-glm", "etabli-glm-challenger", "glm-id");
    retrieve("kimi-id", "completed");
    retrieve("glm-id", "completed");
    expect(call("resume-failed-luna", "etabli-luna-scout", { resume: "luna-id" })).toMatchObject({ block: true });
    expect(call("resume-kimi", "etabli-kimi-fallback", { resume: "kimi-id" })).toBeUndefined();
    expect(call("resume-glm", "etabli-glm-challenger", { resume: "glm-id" })).toBeUndefined();
    result("resume-kimi", "etabli-kimi-fallback", "kimi-id", "completed");
    result("resume-glm", "etabli-glm-challenger", "glm-id", "completed");
    expect(call("sol", "etabli-sol-judge")).toBeUndefined();
  });

  test("blocks Etabli portfolio roles on the unguarded Task RPC surface", () => {
    const runtime = setupExtension();
    runtime.emit("before_agent_start", { prompt: "Fais une review concise", systemPrompt: "Base prompt" });
    const taskCall = (toolName: string, input: Record<string, unknown>) =>
      runtime.emit("tool_call", { toolName, toolCallId: `${toolName}-call`, input })[0];

    expect(taskCall("TaskCreate", { agentType: "etabli-luna-scout" })).toMatchObject({ block: true });
    expect(taskCall("TaskCreate", { metadata: { agentType: "etabli-glm-challenger" } })).toMatchObject({ block: true });
    expect(taskCall("TaskUpdate", { taskId: "1", metadata: { agentType: "etabli-sol-judge" } })).toMatchObject({ block: true });
    expect(taskCall("TaskExecute", { task_ids: ["1"], model: "kimi-coding/k3" })).toMatchObject({ block: true });
    expect(taskCall("TaskCreate", { agentType: "generic-explorer" })).toBeUndefined();
    expect(taskCall("TaskExecute", { task_ids: ["2"], model: "other/model" })).toBeUndefined();
  });

  test("bounds scouts but ignores unrelated generic Agent calls", () => {
    const runtime = setupExtension();
    runtime.emit("before_agent_start", {
      prompt: "Fais un plan d'architecture",
      systemPrompt: "Base prompt",
    });

    let toolCallSequence = 0;
    const emitAgent = (input: Record<string, unknown>) =>
      runtime.emit("tool_call", { toolName: "Agent", toolCallId: `call-${toolCallSequence += 1}`, input })[0];
    expect(emitAgent({ subagent_type: "generic-explorer" })).toBeUndefined();
    expect(emitAgent({ subagent_type: "etabli-terra-analyst" })).toBeUndefined();
    expect(emitAgent({ subagent_type: "etabli-terra-analyst", resume: "terra-id" })).toMatchObject({ block: true });
    expect(emitAgent({ subagent_type: "etabli-glm-challenger" })).toMatchObject({ block: true });
    expect(emitAgent({ subagent_type: "etabli-kimi-fallback" })).toMatchObject({ block: true });
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
      symlinkSync(join(import.meta.dir, "../../../tests/fixtures/obvault-meta"), join(root, "_meta"), "dir");
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

  test("blocks mutating write/bash while PLAN is DRAFT (READY guard parity)", () => {
    const runtime = setupExtension(["Write", "Bash", "Agent"]);
    const cwd = mkdtempSync(join(tmpdir(), "etabli-draft-guard-"));
    try {
      writeFileSync(
        join(cwd, "PLAN.md"),
        ["# PLAN.md", "", "## Meta", "- Status: DRAFT", ""].join("\n"),
      );
      const writeBlock = runtime.emit("tool_call", {
        toolName: "Write",
        toolCallId: "1",
        cwd,
        input: { file_path: join(cwd, "src/x.ts"), content: "x" },
      });
      expect(writeBlock[0]).toMatchObject({ block: true });
      const bashBlock = runtime.emit("tool_call", {
        toolName: "Bash",
        toolCallId: "2",
        cwd,
        input: { command: "rm -rf ./out" },
      });
      expect(bashBlock[0]).toMatchObject({ block: true });
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });

  test("allows write while PLAN is READY", () => {
    const runtime = setupExtension(["Write", "Bash"]);
    const cwd = mkdtempSync(join(tmpdir(), "etabli-ready-guard-"));
    try {
      writeFileSync(
        join(cwd, "PLAN.md"),
        ["# PLAN.md", "", "## Meta", "- Status: READY", ""].join("\n"),
      );
      const writeAllow = runtime.emit("tool_call", {
        toolName: "Write",
        toolCallId: "1",
        cwd,
        input: { file_path: join(cwd, "src/x.ts"), content: "x" },
      });
      expect(writeAllow[0]).toBeUndefined();
    } finally {
      rmSync(cwd, { recursive: true, force: true });
    }
  });
});
