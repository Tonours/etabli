/**
 * Subagent — Spawn child Pi processes as background sub-agents.
 *
 * Each sub-agent runs in its own process with a persistent JSONL session,
 * enabling conversation continuations. Results are injected back into the
 * main agent's conversation.
 *
 * Commands:
 *   /sub <prompt>           — spawn a new sub-agent
 *   /subcont <id> <prompt>  — continue an existing sub-agent
 *   /subrm <id>             — remove a sub-agent
 *   /subclear               — clear all sub-agents
 *
 * Usage: `pi -e extensions/subagent.ts`
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { DynamicBorder } from "@mariozechner/pi-coding-agent";
import { Container, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const MAX_SUBAGENTS = 5;
const SESSION_DIR = join(homedir(), ".pi", "agent", "sessions", "subagents");

interface SubState {
  id: number;
  status: "running" | "done" | "error";
  task: string;
  textChunks: string[];
  toolCount: number;
  elapsed: number;
  sessionFile: string;
  turnCount: number;
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
            const statusColor =
              state.status === "running"
                ? "accent"
                : state.status === "done"
                  ? "success"
                  : "error";
            const statusIcon =
              state.status === "running" ? "●" : state.status === "done" ? "✓" : "✗";

            const taskPreview =
              state.task.length > 40 ? state.task.slice(0, 37) + "..." : state.task;

            const turnLabel =
              state.turnCount > 1 ? theme.fg("dim", ` · Turn ${state.turnCount}`) : "";

            const header =
              theme.fg(statusColor, `${statusIcon} Subagent #${state.id}`) +
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
    const model = ctx.model
      ? `${ctx.model.provider}/${ctx.model.id}`
      : "anthropic/claude-sonnet-4-6";

    return new Promise<void>((resolve) => {
      const proc = spawn(
        "pi",
        [
          "--mode",
          "json",
          "-p",
          "--session",
          state.sessionFile,
          "--no-extensions",
          "--model",
          model,
          "--tools",
          "read,bash,grep,find,ls",
          "--thinking",
          "off",
          prompt,
        ],
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
          `Subagent #${state.id} ${state.status} in ${Math.round(state.elapsed / 1000)}s`,
          state.status === "done" ? "info" : "error",
        );

        pi.sendMessage(
          {
            customType: "subagent-result",
            content:
              `Subagent #${state.id}${state.turnCount > 1 ? ` (Turn ${state.turnCount})` : ""} finished "${prompt}" in ${Math.round(state.elapsed / 1000)}s.\n\nResult:\n${result.slice(0, 8000)}${result.length > 8000 ? "\n\n... [truncated]" : ""}`,
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
      "Spawn a background sub-agent to perform a task. Returns the sub-agent ID immediately while it runs in the background. Results are delivered as a follow-up message when finished.",
    parameters: Type.Object({
      task: Type.String({ description: "The complete task description for the sub-agent" }),
    }),
    execute: async (_callId, args, _signal, _onUpdate, ctx) => {
      widgetCtx = ctx;

      if (agents.size >= MAX_SUBAGENTS) {
        return {
          content: [
            {
              type: "text" as const,
              text: `Error: maximum ${MAX_SUBAGENTS} sub-agents reached. Remove one with subagent_remove first.`,
            },
          ],
        };
      }

      const id = nextId++;
      const state: SubState = {
        id,
        status: "running",
        task: args.task,
        textChunks: [],
        toolCount: 0,
        elapsed: 0,
        sessionFile: makeSessionFile(id),
        turnCount: 1,
      };
      agents.set(id, state);
      updateWidgets();

      spawnAgent(state, args.task, ctx).catch((e) => {
        ctx.ui.notify(`Subagent #${id} error: ${e}`, "error");
      });

      return {
        content: [{ type: "text" as const, text: `Subagent #${id} spawned and running in background.` }],
      };
    },
  });

  pi.registerTool({
    name: "subagent_continue",
    description:
      "Continue an existing sub-agent's conversation with a follow-up prompt. Returns immediately while it runs in the background.",
    parameters: Type.Object({
      id: Type.Number({ description: "The ID of the sub-agent to continue" }),
      prompt: Type.String({ description: "The follow-up prompt or new instructions" }),
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
      updateWidgets();

      ctx.ui.notify(`Continuing sub-agent #${args.id} (Turn ${state.turnCount})`, "info");
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
          `#${s.id} [${s.status}] Turn ${s.turnCount} | Tools: ${s.toolCount} | ${s.task}`,
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
      pi.sendUserMessage(`Use subagent_create to run this task in background: ${prompt}`);
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
      pi.sendUserMessage(`Use subagent_continue to continue sub-agent #${id}: ${prompt}`);
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
      pi.sendUserMessage(`Use subagent_remove to remove sub-agent #${id}`);
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
