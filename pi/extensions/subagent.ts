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
import { execFileSync, spawn, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const MAX_SUBAGENTS = 5;
const SESSION_DIR = join(homedir(), ".pi", "agent", "sessions", "subagents");

type RoleName = "scout" | "worker" | "reviewer";

type RoleConfig = {
  label: string;
  tools: string[];
  instruction: string;
  extensionPaths?: string[];
};

const DEFAULT_TOOLS = ["read", "bash", "grep", "find", "ls"];

function findPackageFile(packageName: string, relativePath: string): string | undefined {
  const candidates = [
    join(homedir(), ".pi", "npm", "node_modules", packageName, relativePath),
  ];

  try {
    const globalRoot = execFileSync("npm", ["root", "-g"], {
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (globalRoot) {
      candidates.push(join(globalRoot, packageName, relativePath));
    }
  } catch {
    // ignore
  }

  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  return undefined;
}

const WORKER_TODO_EXTENSION = findPackageFile("mitsupi", "pi-extensions/todos.ts");
const WORKER_LSP_EXTENSION = findPackageFile("pi-hooks", "lsp/lsp.ts");
const WORKER_LSP_TOOL_EXTENSION = findPackageFile("pi-hooks", "lsp/lsp-tool.ts");
const WORKER_EXTENSION_PATHS = [
  WORKER_TODO_EXTENSION,
  WORKER_LSP_EXTENSION,
  WORKER_LSP_TOOL_EXTENSION,
].filter((value): value is string => Boolean(value));

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

const ROLE_CONFIGS: Record<RoleName, RoleConfig> = {
  scout: {
    label: "Scout",
    tools: DEFAULT_TOOLS,
    instruction:
      "You are a scout subagent. Explore the codebase fast, stay read-only, gather only the context needed, and return concise findings with exact file paths.",
  },
  worker: {
    label: "Worker",
    tools: ["read", "bash", "write", "edit", "grep", "find", "ls", "todo", "lsp"],
    instruction:
      "You are a worker subagent. Implement the requested change directly in the codebase. Read files before editing, keep changes minimal, use todo to claim/get/update/append/close persistent tasks when relevant, use lsp when it sharpens implementation, verify the result with focused commands, and summarize exactly what changed.",
    extensionPaths: WORKER_EXTENSION_PATHS,
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
  proc?: ChildProcess;
}

export default function (pi: ExtensionAPI) {
  const agents = new Map<number, SubState>();
  let nextId = 1;
  let widgetCtx: ExtensionContext | undefined;

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

  function createSubagent(
    task: string,
    ctx: ExtensionContext,
    options?: { model?: string; role?: RoleName },
  ): { text: string } | { error: string } {
    widgetCtx = ctx;

    if (agents.size >= MAX_SUBAGENTS) {
      return { error: `Error: maximum ${MAX_SUBAGENTS} sub-agents reached. Remove one with subagent_remove first.` };
    }

    const id = nextId++;
    const state: SubState = {
      id,
      status: "running",
      task,
      role: options?.role,
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

    return { text: formatSpawnMessage(state) };
  }

  // ── JSONL stream parsing ─────────────────────────────────────────────

  function processLine(state: SubState, line: string): void {
    if (!line.trim()) return;
    try {
      const event = JSON.parse(line);
      if (event.type === "message_update") {
        const delta = event.assistantMessageEvent;
        if (delta?.type === "text_delta") {
          state.textChunks.push(delta.delta ?? "");
          updateWidgets();
        }
      } else if (event.type === "tool_execution_start") {
        state.toolCount++;
        updateWidgets();
      }
    } catch {
      // ignore non-JSON lines
    }
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

            const fullText = state.textChunks.join("");
            const lastLine = fullText
              .split("\n")
              .filter((l) => l.trim())
              .pop();
            const preview = lastLine
              ? theme.fg("muted", `  ${lastLine.length > width - 10 ? lastLine.slice(0, width - 13) + "..." : lastLine}`)
              : "";

            const lines = [header];
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
    const roleConfig = getRoleConfig(state.role);
    const model =
      state.model ??
      (ctx.model
        ? `${ctx.model.provider}/${ctx.model.id}`
        : "anthropic/claude-sonnet-4-6");

    return new Promise<void>((resolve) => {
      const args = [
        "--mode",
        "json",
        "-p",
        "--session",
        state.sessionFile,
        "--no-extensions",
      ];

      for (const extensionPath of roleConfig?.extensionPaths ?? []) {
        args.push("-e", extensionPath);
      }

      args.push(
        "--model",
        model,
        "--tools",
        buildRoleTools(state.role),
        "--thinking",
        "off",
        buildPrompt(state, prompt),
      );

      const proc = spawn(
        "pi",
        args,
        {
          stdio: ["ignore", "pipe", "pipe"],
          env: { ...process.env },
        },
      );

      state.proc = proc;
      const startTime = Date.now();
      const timer = setInterval(() => {
        state.elapsed = Date.now() - startTime;
        updateWidgets();
      }, 1000);

      let buffer = "";

      proc.stdout!.setEncoding("utf-8");
      proc.stdout!.on("data", (chunk: string) => {
        buffer += chunk;
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? "";
        for (const line of lines) processLine(state, line);
      });

      proc.stderr!.setEncoding("utf-8");
      proc.stderr!.on("data", (chunk: string) => {
        if (chunk.trim()) {
          state.textChunks.push(chunk);
          updateWidgets();
        }
      });

      proc.on("close", (code) => {
        if (buffer.trim()) processLine(state, buffer);
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

        resolve();
      });

      proc.on("error", (err) => {
        clearInterval(timer);
        state.status = "error";
        state.proc = undefined;
        state.textChunks.push(`Error: ${err.message}`);
        updateWidgets();
        resolve();
      });
    });
  }

  // ── Tools for the main agent ─────────────────────────────────────────

  pi.registerTool({
    name: "subagent_create",
    description:
      "Spawn a background sub-agent to perform a task. Optionally set role=scout, role=worker, or role=reviewer for a named preset. Scout and reviewer stay read-only; worker can edit code and use todo/LSP when available. Returns the sub-agent ID immediately while it runs in the background. Results are delivered as a follow-up message when finished.",
    parameters: Type.Object({
      task: Type.String({ description: "The complete task description for the sub-agent" }),
      model: Type.Optional(Type.String({ description: "Optional model override (provider/model-id)" })),
      role: Type.Optional(StringEnum(["scout", "worker", "reviewer"] as const)),
    }),
    execute: async (_callId, args, _signal, _onUpdate, ctx) => {
      const created = createSubagent(args.task, ctx, {
        model: args.model,
        role: normalizeRole(args.role),
      });
      if ("error" in created) {
        return { content: [{ type: "text" as const, text: created.error }] };
      }

      return {
        content: [{ type: "text" as const, text: created.text }],
      };
    },
  });

  pi.registerTool({
    name: "subagent_continue",
    description:
      "Continue an existing sub-agent's conversation with a follow-up prompt. Keeps the current role unless role is overridden. Returns immediately while it runs in the background.",
    parameters: Type.Object({
      id: Type.Number({ description: "The ID of the sub-agent to continue" }),
      prompt: Type.String({ description: "The follow-up prompt or new instructions" }),
      model: Type.Optional(Type.String({ description: "Optional model override (provider/model-id)" })),
      role: Type.Optional(StringEnum(["scout", "worker", "reviewer"] as const)),
    }),
    execute: async (_callId, args, _signal, _onUpdate, ctx) => {
      widgetCtx = ctx;
      const state = agents.get(args.id);
      if (!state) {
        return { content: [{ type: "text" as const, text: `Error: no sub-agent #${args.id} found.` }] };
      }
      if (state.status === "running") {
        return { content: [{ type: "text" as const, text: `Error: sub-agent #${args.id} is still running.` }] };
      }

      state.status = "running";
      state.task = args.prompt;
      state.textChunks = [];
      state.elapsed = 0;
      state.turnCount++;
      const modelOverride = normalizeModel(args.model);
      if (modelOverride) {
        state.model = modelOverride;
      }
      const roleOverride = normalizeRole(args.role);
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
      };
    },
  });

  pi.registerTool({
    name: "subagent_remove",
    description: "Remove a specific sub-agent. Kills it if currently running.",
    parameters: Type.Object({
      id: Type.Number({ description: "The ID of the sub-agent to remove" }),
    }),
    execute: async (_callId, args, _signal, _onUpdate, ctx) => {
      widgetCtx = ctx;
      const state = agents.get(args.id);
      if (!state) {
        return { content: [{ type: "text" as const, text: `Error: no sub-agent #${args.id} found.` }] };
      }

      if (state.proc && state.status === "running") {
        state.proc.kill("SIGTERM");
      }
      ctx.ui.setWidget(`sub-${args.id}`, undefined);
      agents.delete(args.id);
      return {
        content: [{ type: "text" as const, text: `Sub-agent #${args.id} removed.` }],
      };
    },
  });

  pi.registerTool({
    name: "subagent_list",
    description: "List all active sub-agents with their status and task.",
    parameters: Type.Object({}),
    execute: async () => {
      if (agents.size === 0) {
        return { content: [{ type: "text" as const, text: "No sub-agents active." }] };
      }

      const lines = Array.from(agents.values()).map(
        (s) =>
          `#${s.id} [${s.status}]${s.role ? ` [${s.role}]` : ""} Turn ${s.turnCount} | Tools: ${s.toolCount} | ${s.task}`,
      );
      return { content: [{ type: "text" as const, text: lines.join("\n") }] };
    },
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
