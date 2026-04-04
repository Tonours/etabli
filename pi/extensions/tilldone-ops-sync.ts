/**
 * TillDone ↔ OPS Sync
 * 
 * Synchronise l'état TillDone avec l'OPS snapshot pour une vue unifiée
 * des "next actions" entre Pi et Neovim.
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { homedir } from "node:os";

function getHomeDir(): string {
  return process.env.HOME || process.env.USERPROFILE || homedir();
}

interface TillDoneOpsState {
  tasks: Array<{
    id: number;
    text: string;
    status: "idle" | "inprogress" | "done";
  }>;
  activeTaskId: number | null;
  listTitle: string | null;
  listDescription: string | null;
  updatedAt: string;
  revision: number;
}

interface OpsTaskProjection {
  taskId: string;
  title: string;
  repo: string;
  workspacePath: string;
  branch: string | null;
  identitySource: string;
  titleSource: string;
  lifecycleState: string;
  mode: string;
  planStatus: string | null;
  runtimePhase: string | null;
  reviewSummary: string;
  nextAction: string;
  activeSlice: string | null;
  completedSlices: string[];
  pendingChecks: string[];
  lastValidatedState: string | null;
  revision: number | null;
  updatedAt: string;
  // Extension TillDone
  tilldone?: {
    activeTaskId: number | null;
    taskCount: number;
    remainingCount: number;
    activeTaskText: string | null;
    listTitle: string | null;
  };
}

const TILLDONE_OPS_FILENAME = "tilldone-ops.json";

function sanitizeCwd(cwd: string): string {
  return cwd.replace(/[^a-zA-Z0-9._-]+/g, "_");
}

function getTillDoneOpsPath(cwd: string): string {
  return join(getHomeDir(), ".pi", "status", `${sanitizeCwd(cwd)}.${TILLDONE_OPS_FILENAME}`);
}

function getOpsTaskPath(cwd: string): string {
  return join(getHomeDir(), ".pi", "status", `${sanitizeCwd(cwd)}.task.json`);
}

function readTillDoneOpsState(cwd: string): TillDoneOpsState | null {
  const path = getTillDoneOpsPath(cwd);
  if (!existsSync(path)) return null;
  
  try {
    const content = readFileSync(path, "utf-8");
    return JSON.parse(content) as TillDoneOpsState;
  } catch {
    return null;
  }
}

function writeTillDoneOpsState(cwd: string, state: TillDoneOpsState): void {
  const path = getTillDoneOpsPath(cwd);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(state, null, 2), "utf-8");
}

function updateOpsTaskWithTillDone(cwd: string, tilldoneState: TillDoneOpsState): void {
  const taskPath = getOpsTaskPath(cwd);
  if (!existsSync(taskPath)) return;

  try {
    const content = readFileSync(taskPath, "utf-8");
    const task = JSON.parse(content) as OpsTaskProjection;
    const activeTask = tilldoneState.tasks.find((entry) => entry.id === tilldoneState.activeTaskId);
    const remainingTasks = tilldoneState.tasks.filter((entry) => entry.status !== "done");

    task.tilldone = {
      activeTaskId: tilldoneState.activeTaskId,
      taskCount: tilldoneState.tasks.length,
      remainingCount: remainingTasks.length,
      activeTaskText: activeTask?.text ?? null,
      listTitle: tilldoneState.listTitle,
    };

    if (activeTask) {
      task.nextAction = `${activeTask.text} (#${activeTask.id})`;
    }

    writeFileSync(taskPath, JSON.stringify(task, null, 2), "utf-8");
  } catch {
    return;
  }
}

function syncTillDoneToOps(ctx: ExtensionContext): void {
  // Reconstruct TillDone state from session history
  const tasks: TillDoneOpsState["tasks"] = [];
  let activeTaskId: number | null = null;
  let listTitle: string | null = null;
  let listDescription: string | null = null;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message") continue;
    const msg = entry.message;
    if (msg.role !== "toolResult" || msg.toolName !== "tilldone") continue;

    const details = msg.details as {
      tasks?: Array<{ id: number; text: string; status: string }>;
      nextId?: number;
      listTitle?: string;
      listDescription?: string;
    } | undefined;
    
    if (details?.tasks) {
      const normalizedTasks = details.tasks.filter(
        (task): task is { id: number; text: string; status: string } =>
          typeof task.id === "number" && typeof task.text === "string" && typeof task.status === "string",
      );
      if (normalizedTasks.length === 0) {
        continue;
      }

      tasks.length = 0;
      for (const t of normalizedTasks) {
        tasks.push({
          id: t.id,
          text: t.text,
          status: t.status as "idle" | "inprogress" | "done",
        });
        if (t.status === "inprogress") {
          activeTaskId = t.id;
        }
      }
      if (details.listTitle) {
        listTitle = details.listTitle;
      }
      if (details.listDescription) {
        listDescription = details.listDescription;
      }
    }
  }

  if (tasks.length === 0) return;

  const existingState = readTillDoneOpsState(ctx.cwd);
  const revision = (existingState?.revision ?? 0) + 1;

  const state: TillDoneOpsState = {
    tasks,
    activeTaskId,
    listTitle,
    listDescription,
    updatedAt: new Date().toISOString(),
    revision,
  };

  writeTillDoneOpsState(ctx.cwd, state);
  updateOpsTaskWithTillDone(ctx.cwd, state);
}

export default function (pi: ExtensionAPI) {
  // Sync on key events
  pi.on("agent_end", async (_event, ctx) => {
    syncTillDoneToOps(ctx);
  });

  pi.on("session_start", async (_event, ctx) => {
    syncTillDoneToOps(ctx);
  });

  pi.on("session_switch", async (_event, ctx) => {
    syncTillDoneToOps(ctx);
  });

  // Command to force sync
  pi.registerCommand("tilldone-sync", {
    description: "Sync TillDone state to OPS snapshot",
    handler: async (_args, ctx) => {
      syncTillDoneToOps(ctx);
      const state = readTillDoneOpsState(ctx.cwd);
      if (state) {
        const activeTask = state.tasks.find(t => t.id === state.activeTaskId);
        const remaining = state.tasks.filter(t => t.status !== "done").length;
        ctx.ui.notify(
          `Synced ${state.tasks.length} tasks (${remaining} remaining)${activeTask ? `, active: #${activeTask.id}` : ""}`,
          "info"
        );
      } else {
        ctx.ui.notify("No TillDone state to sync", "info");
      }
    },
  });

  // Tool to read TillDone state from OPS (for other agents)
  pi.registerTool({
    name: "tilldone_ops_read",
    label: "TillDone OPS Read",
    description: "Read the TillDone state from OPS storage. Use this to see active tasks and next actions from another session.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _args, _signal, _onUpdate, ctx) {
      const state = readTillDoneOpsState(ctx.cwd);
      if (!state) {
        return {
          content: [{ type: "text" as const, text: "No TillDone state found for this cwd" }],
          details: { found: false },
        };
      }

      const activeTask = state.tasks.find(t => t.id === state.activeTaskId);
      const remaining = state.tasks.filter(t => t.status !== "done");

      const lines: string[] = [];
      lines.push(`List: ${state.listTitle ?? "Untitled"}`);
      if (state.listDescription) {
        lines.push(`Description: ${state.listDescription}`);
      }
      lines.push("");
      lines.push(`Tasks (${remaining.length}/${state.tasks.length} remaining):`);
      
      for (const task of state.tasks) {
        const icon = task.status === "done" ? "✓" : task.status === "inprogress" ? "●" : "○";
        const active = task.id === state.activeTaskId ? " [ACTIVE]" : "";
        lines.push(`  ${icon} #${task.id}: ${task.text}${active}`);
      }

      if (activeTask) {
        lines.push("");
        lines.push(`Next action: ${activeTask.text} (#${activeTask.id})`);
      }

      return {
        content: [{ type: "text" as const, text: lines.join("\n") }],
        details: { 
          found: true, 
          state,
          activeTaskId: state.activeTaskId,
          remainingCount: remaining.length,
        },
      };
    },
  });
}
