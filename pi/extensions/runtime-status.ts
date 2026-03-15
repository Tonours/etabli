import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";

interface RuntimeStatus {
  project: string;
  cwd: string;
  phase: "idle" | "running" | "offline";
  tool?: string;
  model?: string;
  thinking: string;
  updatedAt: string;
}

function statusFileName(cwd: string): string {
  return cwd.replace(/[^a-zA-Z0-9._-]+/g, "_");
}

function makeStatusFile(cwd: string): string {
  return join(homedir(), ".pi", "status", `${statusFileName(cwd)}.json`);
}

function writeStatus(filePath: string, state: RuntimeStatus): void {
  mkdirSync(dirname(filePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(state, null, 2) + "\n", "utf-8");
}

function formatTitle(state: RuntimeStatus): string {
  const base = `π ${state.project}`;
  if (state.phase === "offline") return `${base} · offline`;
  if (state.phase === "idle") return `${base} · idle`;
  return state.tool ? `${base} · ${state.tool}` : `${base} · working`;
}

function formatStatus(state: RuntimeStatus): string {
  const pieces = [state.phase, state.model, state.tool, state.thinking].filter(Boolean);
  return `runtime: ${pieces.join(" · ")}`;
}

export default function (pi: ExtensionAPI) {
  let statusFile = makeStatusFile(process.cwd());
  let state: RuntimeStatus = {
    project: basename(process.cwd()),
    cwd: process.cwd(),
    phase: "idle",
    thinking: "off",
    updatedAt: new Date().toISOString(),
  };

  function sync(ctx: ExtensionContext): void {
    state.updatedAt = new Date().toISOString();
    writeStatus(statusFile, state);
    if (ctx.hasUI) {
      ctx.ui.setTitle(formatTitle(state));
      ctx.ui.setStatus("runtime-status", formatStatus(state));
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    statusFile = makeStatusFile(ctx.cwd);
    state = {
      project: basename(ctx.cwd),
      cwd: ctx.cwd,
      phase: "idle",
      model: ctx.model?.id,
      thinking: pi.getThinkingLevel(),
      updatedAt: new Date().toISOString(),
    };
    sync(ctx);
  });

  pi.on("session_switch", async (_event, ctx) => {
    statusFile = makeStatusFile(ctx.cwd);
    state = {
      project: basename(ctx.cwd),
      cwd: ctx.cwd,
      phase: "idle",
      model: ctx.model?.id,
      thinking: pi.getThinkingLevel(),
      updatedAt: new Date().toISOString(),
    };
    sync(ctx);
  });

  pi.on("model_select", async (event, ctx) => {
    state.model = event.model.id;
    state.thinking = pi.getThinkingLevel();
    sync(ctx);
  });

  pi.on("agent_start", async (_event, ctx) => {
    state.phase = "running";
    state.tool = undefined;
    state.thinking = pi.getThinkingLevel();
    state.model = ctx.model?.id;
    sync(ctx);
  });

  pi.on("tool_execution_start", async (event, ctx) => {
    state.phase = "running";
    state.tool = event.toolName;
    sync(ctx);
  });

  pi.on("tool_execution_end", async (_event, ctx) => {
    state.tool = undefined;
    sync(ctx);
  });

  pi.on("agent_end", async (_event, ctx) => {
    state.phase = "idle";
    state.tool = undefined;
    sync(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    state.phase = "offline";
    state.tool = undefined;
    sync(ctx);
  });
}
