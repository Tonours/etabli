/**
 * Subagent — Spawn child Pi processes as background sub-agents.
 *
 * Each sub-agent runs in its own process with a persistent JSONL session,
 * enabling conversation continuations. Results are injected back into the
 * main agent's conversation.
 *
 * Commands:
 *   /sub <prompt>           — spawn a new generic sub-agent
 *   /scout <prompt>         — spawn a scout sub-agent
 *   /worker <prompt>        — spawn a worker sub-agent
 *   /reviewer <prompt>      — spawn a reviewer sub-agent
 *   /subcont <id> <prompt>  — continue an existing sub-agent
 *   /subrm <id>             — remove a sub-agent
 *   /subclear               — clear all sub-agents
 *
 * Usage: `pi -e extensions/subagent.ts`
 */

import { StringEnum } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { DynamicBorder } from "@mariozechner/pi-coding-agent";
import { Container, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { join, resolve } from "node:path";
import {
  FALLBACK_MODEL,
  FALLBACK_THINKING,
  findPackageFile,
  getAgentDir,
  getAgentSettingsPath,
  getExtensionDirFromModule,
  getSafeSubagentExtensionPaths,
  getWorkerPackageExtensionPaths,
  mergeSubagentExtensionPaths,
  resolveSubagentModel,
  resolveSubagentThinking,
  type SubagentRole,
} from "./lib/pi-runtime.ts";
import {
  buildAutomationInstruction,
  createWorkflowAutomationState,
  detectWorkflowInput,
  hasPlanFile,
  readPlanStatus,
  readWorkflowAutomationSettings,
  shouldSpawnWorker,
  type WorkflowAutomationState,
} from "./lib/subagent-automation.ts";
import { canSpawnRole } from "./lib/subagent-orchestration.ts";

const MAX_SUBAGENTS = 5;
const SESSION_DIR = join(getAgentDir(), "sessions", "subagents");
const EXTENSION_DIR = getExtensionDirFromModule(import.meta.url);
const SETTINGS_PATH = getAgentSettingsPath();
const PLAN_STATE_EXTENSION_PATH = join(EXTENSION_DIR, "plan-state.ts");
const WORKER_LOCAL_EXTENSION_PATHS = existsSync(PLAN_STATE_EXTENSION_PATH) ? [PLAN_STATE_EXTENSION_PATH] : [];
const WORKER_PLAN_STATE_TOOLS = WORKER_LOCAL_EXTENSION_PATHS.length > 0 ? ["plan_state_read", "plan_state_update"] : [];

type RoleName = SubagentRole;

type RoleConfig = {
  label: string;
  tools: string[];
  instruction: string;
  extensionPaths?: string[];
};

type SubagentRuntime = {
  start(args: {
    state: SubState;
    prompt: string;
    ctx: ExtensionContext;
    model: string;
    thinking: string;
    toolList: string;
    extensionPaths: string[];
    fullPrompt: string;
    onText: (chunk: string) => void;
    onToolStart: () => void;
    onComplete: (code: number) => void;
    onError: (error: Error) => void;
  }): void;
};

const DEFAULT_TOOLS = ["read", "bash", "grep", "find", "ls"];
const SAFE_EXTENSION_PATHS = getSafeSubagentExtensionPaths(EXTENSION_DIR);
const WORKER_EXTENSION_PATHS = getWorkerPackageExtensionPaths(findPackageFile);
const WORKER_TODO_EXTENSION = WORKER_EXTENSION_PATHS[0];
const WORKER_LSP_EXTENSION = WORKER_EXTENSION_PATHS[1];
const WORKER_LSP_TOOL_EXTENSION = WORKER_EXTENSION_PATHS[2];

function buildRoleTools(role: RoleName | undefined): string {
  const tools = [...(role ? ROLE_CONFIGS[role].tools : DEFAULT_TOOLS)];
  if (role === "worker" && !WORKER_TODO_EXTENSION) {
    const index = tools.indexOf("todo");
    if (index !== -1) tools.splice(index, 1);
  }
  if (role === "worker" && (!WORKER_LSP_EXTENSION || !WORKER_LSP_TOOL_EXTENSION)) {
    const index = tools.indexOf("lsp");
    if (index !== -1) tools.splice(index, 1);
  }
  return tools.join(",");
}

function buildRoleExtensionPaths(role: RoleName | undefined): string[] {
  const roleConfig = role ? ROLE_CONFIGS[role] : undefined;
  return mergeSubagentExtensionPaths(roleConfig?.extensionPaths ?? [], SAFE_EXTENSION_PATHS);
}

const ROLE_CONFIGS: Record<RoleName, RoleConfig> = {
  scout: {
    label: "Scout",
    tools: DEFAULT_TOOLS,
    instruction:
      "You are a scout subagent. Explore the codebase fast, stay read-only, gather only the context needed, and return concise findings with exact file paths.",
  },
  worker: {
    label: "Worker",
    tools: ["read", "bash", "write", "edit", "grep", "find", "ls", "todo", "lsp", ...WORKER_PLAN_STATE_TOOLS],
    instruction:
      "You are a worker subagent. Implement one bounded slice at a time. Read files before editing, keep changes minimal, load only the context needed for the current slice, use todo to claim/get/update/append/close persistent tasks when relevant, use lsp when it sharpens implementation, use plan_state_read/plan_state_update when it helps keep PLAN.md tracking accurate, verify the result with focused commands, and summarize whether the next action is continue, correct, or replan.",
    extensionPaths: [...WORKER_EXTENSION_PATHS, ...WORKER_LOCAL_EXTENSION_PATHS],
  },
  reviewer: {
    label: "Reviewer",
    tools: DEFAULT_TOOLS,
    instruction:
      "You are a reviewer subagent. Stay read-only, inspect the requested scope carefully, focus on correctness, regressions, safety, and missing validation, and return concise findings.",
  },
};

interface SubState {
  id: number;
  status: "running" | "done" | "error";
  task: string;
  role?: RoleName;
  textChunks: string[];
  toolCount: number;
  elapsed: number;
  sessionFile: string;
  turnCount: number;
  model?: string;
  automationId?: number;
  resolvedModel?: string;
  resolvedThinking?: string;
  proc?: ChildProcess;
}

const defaultRuntime: SubagentRuntime = {
  start(args) {
    const procArgs = [
      "--mode",
      "json",
      "-p",
      "--session",
      args.state.sessionFile,
      "--no-extensions",
    ];

    for (const extensionPath of args.extensionPaths) {
      procArgs.push("-e", extensionPath);
    }

    procArgs.push(
      "--model",
      args.model,
      "--tools",
      args.toolList,
      "--thinking",
      args.thinking,
      args.fullPrompt,
    );

    const proc = spawn("pi", procArgs, {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env },
    });

    args.state.proc = proc;
    let buffer = "";

    proc.stdout!.setEncoding("utf-8");
    proc.stdout!.on("data", (chunk: string) => {
      buffer += chunk;
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const event = JSON.parse(line);
          if (event.type === "message_update") {
            const delta = event.assistantMessageEvent;
            if (delta?.type === "text_delta") {
              args.onText(delta.delta ?? "");
            }
          } else if (event.type === "tool_execution_start") {
            args.onToolStart();
          }
        } catch {
          // ignore non-JSON lines
        }
      }
    });

    proc.stderr!.setEncoding("utf-8");
    proc.stderr!.on("data", (chunk: string) => {
      if (chunk.trim()) {
        args.onText(chunk);
      }
    });

    proc.on("close", (code) => {
      if (buffer.trim()) {
        args.onText(buffer);
      }
      args.onComplete(code ?? 1);
    });

    proc.on("error", (error) => {
      args.onError(error);
    });
  },
};

export default function (pi: ExtensionAPI, runtime: SubagentRuntime = defaultRuntime) {
  const agents = new Map<number, SubState>();
  let nextId = 1;
  let nextAutomationRunId = 1;
  let widgetCtx: ExtensionContext | undefined;
  let automation: WorkflowAutomationState | null = null;
  let agentEndCount = 0;

  // ── Session file helpers ─────────────────────────────────────────────

  function makeSessionFile(id: number): string {
    mkdirSync(SESSION_DIR, { recursive: true });
    return join(SESSION_DIR, `subagent-${id}-${Date.now()}.jsonl`);
  }

  function normalizeModel(value: unknown): string | undefined {
    if (typeof value !== "string") {
      return undefined;
    }
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }

  function normalizeRole(value: unknown): RoleName | undefined {
    if (value !== "scout" && value !== "worker" && value !== "reviewer") {
      return undefined;
    }
    return value;
  }

  function getRoleConfig(role: RoleName | undefined): RoleConfig | undefined {
    if (!role) return undefined;
    return ROLE_CONFIGS[role];
  }

  function buildPrompt(state: SubState, prompt: string): string {
    const roleConfig = getRoleConfig(state.role);
    if (!roleConfig) return prompt;
    return `${roleConfig.instruction}\n\nTask:\n${prompt}`;
  }

  function buildTargetLabel(state: SubState): string {
    const roleConfig = getRoleConfig(state.role);
    const roleLabel = roleConfig ? `${roleConfig.label} ` : "";
    return `${roleLabel}Subagent #${state.id}`;
  }

  function formatSpawnMessage(state: SubState): string {
    const roleConfig = getRoleConfig(state.role);
    return roleConfig
      ? `${roleConfig.label} subagent #${state.id} spawned and running in background.`
      : `Subagent #${state.id} spawned and running in background.`;
  }

  function formatRuntimeSpec(state: SubState): string {
    const parts = [state.resolvedModel, state.resolvedThinking ? `thinking=${state.resolvedThinking}` : undefined].filter(
      (value): value is string => Boolean(value),
    );
    return parts.length > 0 ? parts.join(" | ") : "runtime pending";
  }

  function resetAutomationState(): void {
    automation = null;
    agentEndCount = 0;
  }

  function buildScoutTask(): string {
    if (!automation) {
      return "Explore the relevant codebase area, identify likely files, constraints, risks, and focused validation needed for the active workflow.";
    }

    const scope = automation.task.length > 0
      ? `Original task:\n${automation.task}`
      : "No explicit task text was supplied. Use the current repo state and any existing PLAN.md to infer the active scope.";

    return [
      `Workflow: ${automation.workflow}`,
      scope,
      "Explore the relevant codebase area, identify likely files, constraints, edge cases, risks, and focused checks.",
      "Return concise findings that help the planning pass move faster.",
    ].join("\n\n");
  }

  function buildReviewerTask(): string {
    if (!automation) {
      return "Review the current PLAN.md draft, challenge scope and execution, and return concise findings.";
    }

    const scope = automation.task.length > 0
      ? `Original task:\n${automation.task}`
      : "No explicit task text was supplied. Review the current PLAN.md in repo context.";

    const implementationNote = automation.workflow === "plan-implement"
      ? "This review gates implementation. Be strict about blocking issues before the worker is allowed to start."
      : "This review should harden PLAN.md from v1 draft to a proper reviewed v2 plan.";

    return [
      `Workflow: ${automation.workflow}`,
      scope,
      "Read the current PLAN.md and challenge measurement contract, scope, ordered slices, validations, invariants, rollback points, and key risks.",
      implementationNote,
      "Return concise findings with the highest-impact changes needed in PLAN.md.",
    ].join("\n\n");
  }

  function buildWorkerTask(): string {
    return [
      "Implement the current READY PLAN.md in this repository.",
      "Follow slices in order, keep PLAN.md implementation tracking current, run focused checks, and keep changes minimal.",
      "If new facts invalidate the plan, stop implementation, update PLAN.md first, and restore READY before continuing.",
    ].join("\n\n");
  }

  function spawnAutomatedRole(role: RoleName, task: string, ctx: ExtensionContext): void {
    if (!automation) return;

    const created = createSubagent(task, ctx, {
      role,
      automationId: automation.runId,
    });
    if ("error" in created) {
      ctx.ui.notify(created.error, "error");
      return;
    }

    if (role === "scout") automation.scoutId = created.id;
    if (role === "reviewer") automation.reviewerId = created.id;
    if (role === "worker") automation.workerId = created.id;
    ctx.ui.notify(`${created.text} [auto]`, "info");
  }

  function maybeSpawnReviewer(ctx: ExtensionContext): void {
    if (!automation) return;
    const config = readWorkflowAutomationSettings(SETTINGS_PATH)[automation.workflow];
    if (!config.enabled || !config.autoReviewer || automation.reviewerId || !hasPlanFile(ctx.cwd)) return;
    spawnAutomatedRole("reviewer", buildReviewerTask(), ctx);
  }

  function maybeSpawnWorker(ctx: ExtensionContext): void {
    if (!automation) return;
    const config = readWorkflowAutomationSettings(SETTINGS_PATH)[automation.workflow];
    const planStatus = readPlanStatus(ctx.cwd);

    if (!shouldSpawnWorker({ automation, config, agentEndCount, planStatus })) {
      return;
    }

    spawnAutomatedRole("worker", buildWorkerTask(), ctx);
  }

  function isPlanPath(cwd: string, value: unknown): boolean {
    if (typeof value !== "string" || value.trim().length === 0) return false;
    return resolve(cwd, value) === join(cwd, "PLAN.md");
  }

  function createSubagent(
    task: string,
    ctx: ExtensionContext,
    options?: { model?: string; role?: RoleName; allowParallelWorkers?: boolean; automationId?: number },
  ): { text: string; id: number } | { error: string } {
    widgetCtx = ctx;

    if (agents.size >= MAX_SUBAGENTS) {
      return { error: `Error: maximum ${MAX_SUBAGENTS} sub-agents reached. Remove one with subagent_remove first.` };
    }

    const roleConflict = canSpawnRole(
      Array.from(agents.values()).map((state) => ({ status: state.status, role: state.role })),
      options?.role,
      options?.allowParallelWorkers === true,
    );
    if (roleConflict) {
      return { error: roleConflict };
    }

    const id = nextId++;
    const state: SubState = {
      id,
      status: "running",
      task,
      role: options?.role,
      automationId: options?.automationId,
      textChunks: [],
      toolCount: 0,
      elapsed: 0,
      sessionFile: makeSessionFile(id),
      turnCount: 1,
      model: normalizeModel(options?.model),
    };
    agents.set(id, state);
    updateWidgets();

    spawnAgent(state, task, ctx).catch((e) => {
      ctx.ui.notify(`Subagent #${id} error: ${e}`, "error");
    });

    return { text: formatSpawnMessage(state), id };
  }

  // ── Widget rendering ─────────────────────────────────────────────────

  function updateWidgets(): void {
    if (!widgetCtx) return;

    for (const [id, state] of agents.entries()) {
      const key = `sub-${id}`;
      if (state.status !== "running") {
        widgetCtx.ui.setWidget(key, undefined);
        continue;
      }

      widgetCtx.ui.setWidget(key, (_tui, theme) => {
        const container = new Container();
        const borderFn = (s: string) => theme.fg("dim", s);
        container.addChild(new Text("", 0, 0));
        container.addChild(new DynamicBorder(borderFn));
        const content = new Text("", 1, 0);
        container.addChild(content);
        container.addChild(new DynamicBorder(borderFn));

        return {
          render(width: number): string[] {
            const roleConfig = getRoleConfig(state.role);

            const taskPreview =
              state.task.length > 40 ? state.task.slice(0, 37) + "..." : state.task;

            const turnLabel =
              state.turnCount > 1 ? theme.fg("dim", ` · Turn ${state.turnCount}`) : "";

            const header =
              theme.fg("accent", `● ${buildTargetLabel(state)}`) +
              (roleConfig ? theme.fg("dim", ` [${state.role}]`) : "") +
              turnLabel +
              theme.fg("dim", `  ${taskPreview}`) +
              theme.fg("dim", `  (${Math.round(state.elapsed / 1000)}s)`) +
              theme.fg("dim", ` | Tools: ${state.toolCount}`);
            const runtimeLine = theme.fg("dim", `  ${formatRuntimeSpec(state)}`);

            const fullText = state.textChunks.join("");
            const lastLine = fullText
              .split("\n")
              .filter((l) => l.trim())
              .pop();
            const preview = lastLine
              ? theme.fg("muted", `  ${lastLine.length > width - 10 ? lastLine.slice(0, width - 13) + "..." : lastLine}`)
              : "";

            const lines = [header, runtimeLine];
            if (preview) lines.push(preview);

            content.setText(lines.join("\n"));
            return container.render(width);
          },
          invalidate() {
            container.invalidate();
          },
        };
      });
    }
  }

  // ── Spawn a sub-agent process ────────────────────────────────────────

  function spawnAgent(state: SubState, prompt: string, ctx: ExtensionContext): Promise<void> {
    const model = resolveSubagentModel({
      override: state.model,
      role: state.role,
      currentModel: ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined,
      settingsPath: SETTINGS_PATH,
      fallback: FALLBACK_MODEL,
    });
    const thinking = resolveSubagentThinking({
      role: state.role,
      settingsPath: SETTINGS_PATH,
      fallback: FALLBACK_THINKING,
    });
    state.resolvedModel = model;
    state.resolvedThinking = thinking;
    updateWidgets();

    return new Promise<void>((resolve) => {
      const toolList = buildRoleTools(state.role);
      const extensionPaths = buildRoleExtensionPaths(state.role);
      const fullPrompt = buildPrompt(state, prompt);
      const startTime = Date.now();
      const timer = setInterval(() => {
        state.elapsed = Date.now() - startTime;
        updateWidgets();
      }, 1000);

      runtime.start({
        state,
        prompt,
        ctx,
        model,
        thinking,
        toolList,
        extensionPaths,
        fullPrompt,
        onText: (chunk) => {
          state.textChunks.push(chunk);
          updateWidgets();
        },
        onToolStart: () => {
          state.toolCount++;
          updateWidgets();
        },
        onComplete: (code) => {
          clearInterval(timer);
          state.elapsed = Date.now() - startTime;
          state.status = code === 0 ? "done" : "error";
          state.proc = undefined;
          updateWidgets();

          const result = state.textChunks.join("");
          ctx.ui.notify(
            `${buildTargetLabel(state)} ${state.status} in ${Math.round(state.elapsed / 1000)}s`,
            state.status === "done" ? "info" : "error",
          );

          pi.sendMessage(
            {
              customType: "subagent-result",
              content:
                `${buildTargetLabel(state)}${state.turnCount > 1 ? ` (Turn ${state.turnCount})` : ""} finished "${prompt}" in ${Math.round(state.elapsed / 1000)}s.\n\nResult:\n${result.slice(0, 8000)}${result.length > 8000 ? "\n\n... [truncated]" : ""}`,
              display: true,
            },
            { deliverAs: "followUp", triggerTurn: true },
          );

          if (automation && state.automationId === automation.runId && automation.reviewerId === state.id) {
            automation.reviewerDone = code === 0;
            if (code === 0) {
              automation.reviewerReadyAfterAgentEndCount = agentEndCount + (ctx.isIdle() ? 1 : 2);
            }
          }

          resolve();
        },
        onError: (err) => {
          clearInterval(timer);
          state.status = "error";
          state.proc = undefined;
          state.textChunks.push(`Error: ${err.message}`);
          updateWidgets();
          resolve();
        },
      });
    });
  }

  // ── Tools for the main agent ─────────────────────────────────────────

  pi.registerTool({
    name: "subagent_create",
    label: "Subagent Create",
    description:
      "Spawn a background sub-agent to perform a task. Optionally set role=scout, role=worker, or role=reviewer for a named preset. Scout and reviewer stay read-only; worker can edit code and use todo/LSP when available. Only one worker runs by default unless allowParallelWorkers=true is explicitly set for isolated work. Returns the sub-agent ID immediately while it runs in the background. Results are delivered as a follow-up message when finished.",
    parameters: Type.Object({
      task: Type.String({ description: "The complete task description for the sub-agent" }),
      model: Type.Optional(Type.String({ description: "Optional model override (provider/model-id)" })),
      role: Type.Optional(StringEnum(["scout", "worker", "reviewer"] as const)),
      allowParallelWorkers: Type.Optional(
        Type.Boolean({
          description:
            "Allow spawning a second worker while another worker is running. Use only when work is explicitly isolated outside this runtime.",
        }),
      ),
    }),
    execute: async (_callId, args, _signal, _onUpdate, ctx) => {
      const created = createSubagent(args.task, ctx, {
        model: args.model,
        role: normalizeRole(args.role),
        allowParallelWorkers: args.allowParallelWorkers,
      });
      if ("error" in created) {
        return { content: [{ type: "text" as const, text: created.error }], details: {} };
      }

      return {
        content: [{ type: "text" as const, text: created.text }],
        details: {},
      };
    },
  });

  pi.registerTool({
    name: "subagent_continue",
    label: "Subagent Continue",
    description:
      "Continue an existing sub-agent's conversation with a follow-up prompt. Keeps the current role unless role is overridden. Worker continuations still respect the one-worker-by-default rule unless allowParallelWorkers=true is explicitly set for isolated work. Returns immediately while it runs in the background.",
    parameters: Type.Object({
      id: Type.Number({ description: "The ID of the sub-agent to continue" }),
      prompt: Type.String({ description: "The follow-up prompt or new instructions" }),
      model: Type.Optional(Type.String({ description: "Optional model override (provider/model-id)" })),
      role: Type.Optional(StringEnum(["scout", "worker", "reviewer"] as const)),
      allowParallelWorkers: Type.Optional(
        Type.Boolean({
          description:
            "Allow continuing or spawning a worker in parallel with another running worker. Use only when work is explicitly isolated outside this runtime.",
        }),
      ),
    }),
    execute: async (_callId, args, _signal, _onUpdate, ctx) => {
      widgetCtx = ctx;
      const state = agents.get(args.id);
      if (!state) {
        return { content: [{ type: "text" as const, text: `Error: no sub-agent #${args.id} found.` }], details: {} };
      }
      if (state.status === "running") {
        return { content: [{ type: "text" as const, text: `Error: sub-agent #${args.id} is still running.` }], details: {} };
      }

      const roleOverride = normalizeRole(args.role);
      const targetRole = roleOverride ?? state.role;
      const roleConflict = canSpawnRole(
        Array.from(agents.values())
          .filter((candidate) => candidate.id !== state.id)
          .map((candidate) => ({ status: candidate.status, role: candidate.role })),
        targetRole,
        args.allowParallelWorkers === true,
      );
      if (roleConflict) {
        return {
          content: [{ type: "text" as const, text: roleConflict }],
          details: {},
        };
      }

      state.status = "running";
      state.task = args.prompt;
      state.textChunks = [];
      state.elapsed = 0;
      state.turnCount++;
      state.resolvedModel = undefined;
      state.resolvedThinking = undefined;
      const modelOverride = normalizeModel(args.model);
      if (modelOverride) {
        state.model = modelOverride;
      }
      if (roleOverride) {
        state.role = roleOverride;
      }
      updateWidgets();

      ctx.ui.notify(`Continuing ${buildTargetLabel(state)} (Turn ${state.turnCount})`, "info");
      spawnAgent(state, args.prompt, ctx).catch((e) => {
        ctx.ui.notify(`Subagent #${args.id} error: ${e}`, "error");
      });

      return {
        content: [{ type: "text" as const, text: `Sub-agent #${args.id} continuing in background.` }],
        details: {},
      };
    },
  });

  pi.registerTool({
    name: "subagent_remove",
    label: "Subagent Remove",
    description: "Remove a specific sub-agent. Kills it if currently running.",
    parameters: Type.Object({
      id: Type.Number({ description: "The ID of the sub-agent to remove" }),
    }),
    execute: async (_callId, args, _signal, _onUpdate, ctx) => {
      widgetCtx = ctx;
      const state = agents.get(args.id);
      if (!state) {
        return { content: [{ type: "text" as const, text: `Error: no sub-agent #${args.id} found.` }], details: {} };
      }

      if (state.proc && state.status === "running") {
        state.proc.kill("SIGTERM");
      }
      if (automation && state.automationId === automation.runId) {
        if (automation.scoutId === state.id) automation.scoutId = undefined;
        if (automation.reviewerId === state.id) {
          automation.reviewerId = undefined;
          automation.reviewerDone = false;
          automation.reviewerReadyAfterAgentEndCount = Number.POSITIVE_INFINITY;
        }
        if (automation.workerId === state.id) automation.workerId = undefined;
      }
      ctx.ui.setWidget(`sub-${args.id}`, undefined);
      agents.delete(args.id);
      return {
        content: [{ type: "text" as const, text: `Sub-agent #${args.id} removed.` }],
        details: {},
      };
    },
  });

  pi.registerTool({
    name: "subagent_list",
    label: "Subagent List",
    description: "List all active sub-agents with their status and task.",
    parameters: Type.Object({}),
    execute: async () => {
      if (agents.size === 0) {
        return { content: [{ type: "text" as const, text: "No sub-agents active." }], details: {} };
      }

      const lines = Array.from(agents.values()).map(
        (s) =>
          `#${s.id} [${s.status}]${s.role ? ` [${s.role}]` : ""} Turn ${s.turnCount} | ${formatRuntimeSpec(s)} | Tools: ${s.toolCount} | ${s.task}`,
      );
      return { content: [{ type: "text" as const, text: lines.join("\n") }], details: {} };
    },
  });

  pi.on("input", async (event, ctx) => {
    if (event.source === "extension") {
      return { action: "continue" as const };
    }

    const detected = detectWorkflowInput(event.text);
    if (!detected) {
      resetAutomationState();
      return { action: "continue" as const };
    }

    const config = readWorkflowAutomationSettings(SETTINGS_PATH)[detected.workflow];
    if (!config.enabled) {
      resetAutomationState();
      return { action: "continue" as const };
    }

    resetAutomationState();
    automation = createWorkflowAutomationState(detected.workflow, detected.task, nextAutomationRunId++);

    if (config.autoScout) {
      spawnAutomatedRole("scout", buildScoutTask(), ctx);
    }

    if (detected.workflow === "plan-implement" && detected.task.length === 0 && hasPlanFile(ctx.cwd)) {
      maybeSpawnReviewer(ctx);
    }

    return {
      action: "transform" as const,
      text: `${event.text}\n\n${buildAutomationInstruction(detected.workflow)}`,
    };
  });

  pi.on("tool_result", async (event, ctx) => {
    if (!automation || event.isError) {
      return;
    }

    if ((event.toolName === "write" || event.toolName === "edit") && isPlanPath(ctx.cwd, event.input?.path)) {
      maybeSpawnReviewer(ctx);
    }
  });

  pi.on("agent_end", async (_event, ctx) => {
    agentEndCount++;
    if (automation?.workflow === "plan-implement") {
      maybeSpawnReviewer(ctx);
    }
    maybeSpawnWorker(ctx);
  });

  // ── Slash commands ───────────────────────────────────────────────────

  pi.registerCommand("sub", {
    description: "Spawn a new sub-agent: /sub <prompt>",
    handler: async (args, ctx) => {
      const prompt = args.trim();
      if (!prompt) {
        ctx.ui.notify("Usage: /sub <prompt>", "warning");
        return;
      }
      pi.sendUserMessage(`Use subagent_create to run this task in background: ${prompt}`, { deliverAs: "followUp" });
    },
  });

  pi.registerCommand("scout", {
    description: "Spawn a scout sub-agent: /scout <prompt>",
    handler: async (args, ctx) => {
      const prompt = args.trim();
      if (!prompt) {
        ctx.ui.notify("Usage: /scout <prompt>", "warning");
        return;
      }
      const created = createSubagent(prompt, ctx, { role: "scout" });
      if ("error" in created) {
        ctx.ui.notify(created.error, "error");
        return;
      }
      ctx.ui.notify(created.text, "info");
    },
  });

  pi.registerCommand("worker", {
    description: "Spawn a worker sub-agent: /worker <prompt>",
    handler: async (args, ctx) => {
      const prompt = args.trim();
      if (!prompt) {
        ctx.ui.notify("Usage: /worker <prompt>", "warning");
        return;
      }
      const created = createSubagent(prompt, ctx, { role: "worker" });
      if ("error" in created) {
        ctx.ui.notify(created.error, "error");
        return;
      }
      ctx.ui.notify(created.text, "info");
    },
  });

  pi.registerCommand("reviewer", {
    description: "Spawn a reviewer sub-agent: /reviewer <prompt>",
    handler: async (args, ctx) => {
      const prompt = args.trim();
      if (!prompt) {
        ctx.ui.notify("Usage: /reviewer <prompt>", "warning");
        return;
      }
      const created = createSubagent(prompt, ctx, { role: "reviewer" });
      if ("error" in created) {
        ctx.ui.notify(created.error, "error");
        return;
      }
      ctx.ui.notify(created.text, "info");
    },
  });

  pi.registerCommand("subcont", {
    description: "Continue a sub-agent: /subcont <id> <prompt>",
    handler: async (args, ctx) => {
      const parts = args.trim().split(/\s+/);
      const id = parseInt(parts[0] ?? "", 10);
      const prompt = parts.slice(1).join(" ");
      if (isNaN(id) || !prompt) {
        ctx.ui.notify("Usage: /subcont <id> <prompt>", "warning");
        return;
      }
      pi.sendUserMessage(`Use subagent_continue to continue sub-agent #${id}: ${prompt}`, { deliverAs: "followUp" });
    },
  });

  pi.registerCommand("subrm", {
    description: "Remove a sub-agent: /subrm <id>",
    handler: async (args, ctx) => {
      const id = parseInt(args.trim(), 10);
      if (isNaN(id)) {
        ctx.ui.notify("Usage: /subrm <id>", "warning");
        return;
      }
      pi.sendUserMessage(`Use subagent_remove to remove sub-agent #${id}`, { deliverAs: "followUp" });
    },
  });

  pi.registerCommand("subclear", {
    description: "Clear all sub-agents",
    handler: async (_args, ctx) => {
      for (const [id, state] of agents.entries()) {
        if (state.proc && state.status === "running") {
          state.proc.kill("SIGTERM");
        }
        ctx.ui.setWidget(`sub-${id}`, undefined);
      }
      agents.clear();
      ctx.ui.notify("All sub-agents cleared.", "info");
    },
  });
}
