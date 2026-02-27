/**
 * Nightshift extension for pi — native TypeScript orchestrator.
 *
 * Commands:
 *   /nightshift init [--force]                      — Create tasks template
 *   /nightshift list                                — List parsed tasks with status
 *   /nightshift run [--dry-run] [--verify-only]     — Execute tasks
 *            [--require-verify] [--only id] [--limit N]
 *   /nightshift status                              — Show task status from state.json
 *   /nightshift clean                               — Purge stale worktrees
 *   /nightshift-quick --repo <name> --prompt "..."  — Quick task add
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseCommandArgs, getFlagValue, toBoolean, toOptionalString, notifyBlock } from "./lib/args.ts";
import { resolveConfig } from "./lib/nightshift/config.ts";
import { parseTasks, normalizeTaskId } from "./lib/nightshift/parse-tasks.ts";
import { readState } from "./lib/nightshift/state.ts";
import { cleanWorktrees } from "./lib/nightshift/worktree.ts";
import { cmdRun } from "./lib/nightshift/runner.ts";
import type { NightshiftConfig } from "./lib/nightshift/types.ts";

type Subcommand = "init" | "list" | "run" | "status" | "clean";
const SUBCOMMANDS = new Set<Subcommand>(["init", "list", "run", "status", "clean"]);

function ensureDirs(config: NightshiftConfig): void {
  mkdirSync(config.stateDir, { recursive: true });
  mkdirSync(config.logDir, { recursive: true });
  mkdirSync(config.worktreeRoot, { recursive: true });

  if (!existsSync(config.stateFile)) {
    writeFileSync(config.stateFile, '{"version":1,"tasks":{}}\n', "utf-8");
  }
  if (!existsSync(config.historyFile)) {
    writeFileSync(config.historyFile, "", "utf-8");
  }
}

const TEMPLATE = `# Night Shift Tasks

Prep session (17:00-17:30):
- add 1-3 tasks max
- keep them execution-oriented (bugfix / small feature)
- include verify commands

## TASK example-fix-login-redirect
repo: my-repo
base: main
branch: night/example-fix-login-redirect
engine: codex
verify:
- bun test
- bun run lint
prompt:
Fix the login redirect loop.

Context:
- Users on /app are redirected back to /login even after auth.

DoD:
- tests pass
- no new lints
- minimal diff

Notes:
- likely in src/auth/* and middleware
ENDPROMPT
`;

function cmdInit(config: NightshiftConfig, force: boolean): string {
  ensureDirs(config);
  const out = config.tasksFile;

  if (existsSync(out) && !force) {
    return `Tasks file already exists: ${out} (use --force to overwrite)`;
  }

  writeFileSync(out, TEMPLATE, "utf-8");
  return `Created: ${out}`;
}

function cmdList(config: NightshiftConfig): string {
  if (!existsSync(config.tasksFile)) {
    return `No tasks file found: ${config.tasksFile}\nRun /nightshift init to create one.`;
  }
  const content = readFileSync(config.tasksFile, "utf-8");
  const tasks = parseTasks(content);

  if (tasks.length === 0) return "No tasks found.";

  const state = readState(config.stateFile);
  const lines: string[] = [];

  for (const task of tasks) {
    const taskState = state.tasks[task.id];
    const status = taskState?.status ?? "pending";
    const repo = task.path ?? task.repo ?? "";
    lines.push(`${task.id}\t${status}\tengine=${task.engine}\trepo=${repo}\tbranch=${task.branch}`);
  }

  return lines.join("\n");
}

function cmdStatus(config: NightshiftConfig): string {
  ensureDirs(config);
  const state = readState(config.stateFile);
  const entries = Object.entries(state.tasks).sort(([a], [b]) => a.localeCompare(b));

  if (entries.length === 0) return "No task state recorded yet.";

  const lines: string[] = [];
  for (const [tid, meta] of entries) {
    const parts = [tid, meta.status ?? "", meta.branch ?? "", meta.worktree ?? "", meta.lastRunAt ?? ""];
    if (meta.lastError) parts.push(meta.lastError);
    lines.push(parts.join("\t"));
  }
  return lines.join("\n");
}

function cmdClean(config: NightshiftConfig): string {
  if (!existsSync(config.tasksFile)) {
    return `No tasks file found: ${config.tasksFile}\nRun /nightshift init to create one.`;
  }
  const content = readFileSync(config.tasksFile, "utf-8");
  const tasks = parseTasks(content);

  const repoDirs = new Set<string>();
  for (const task of tasks) {
    if (task.path) {
      repoDirs.add(task.path);
    } else if (task.repo) {
      repoDirs.add(join(config.projectRoot, task.repo));
    }
  }

  let totalCleaned = 0;
  for (const repoDir of repoDirs) {
    if (!existsSync(join(repoDir, ".git"))) continue;
    totalCleaned += cleanWorktrees(repoDir);
  }

  return `Cleaned ${totalCleaned} stale worktree(s).`;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("nightshift", {
    description: "Overnight batch task runner (native)",
    handler: async (args, ctx) => {
      const parsed = parseCommandArgs(args);
      const firstPositional = parsed.positional[0];
      const subcommand = SUBCOMMANDS.has(firstPositional as Subcommand)
        ? (firstPositional as Subcommand)
        : undefined;

      if (!subcommand) {
        ctx.ui.notify("Usage: /nightshift <init|list|run|status|clean> [--flags]", "warning");
        return;
      }

      const config = resolveConfig();

      try {
        if (subcommand === "init") {
          const force = toBoolean(getFlagValue(parsed.flags, ["force"]), false);
          notifyBlock(ctx, cmdInit(config, force), "info");
          return;
        }

        if (subcommand === "list") {
          notifyBlock(ctx, cmdList(config), "info");
          return;
        }

        if (subcommand === "status") {
          notifyBlock(ctx, cmdStatus(config), "info");
          return;
        }

        if (subcommand === "clean") {
          notifyBlock(ctx, cmdClean(config), "info");
          return;
        }

        if (subcommand === "run") {
          const dryRun = toBoolean(getFlagValue(parsed.flags, ["dry-run", "dryRun"]), false);
          const verifyOnly = toBoolean(getFlagValue(parsed.flags, ["verify-only", "verifyOnly"]), false);
          const requireVerify = toBoolean(getFlagValue(parsed.flags, ["require-verify", "requireVerify"]), false);
          const only = toOptionalString(getFlagValue(parsed.flags, ["only"]));
          const limitRaw = toOptionalString(getFlagValue(parsed.flags, ["limit"]));
          const limit = limitRaw !== undefined ? Math.max(0, Math.trunc(Number(limitRaw)) || 0) : 0;

          ensureDirs(config);
          const result = await cmdRun(config, { dryRun, verifyOnly, requireVerify, only, limit });
          notifyBlock(ctx, result, "info");
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        notifyBlock(ctx, `Nightshift ${subcommand} failed: ${msg}`, "error");
      }
    },
  });

  pi.registerCommand("nightshift-quick", {
    description: "Quickly add a nightshift task",
    handler: async (args, ctx) => {
      const parsed = parseCommandArgs(args);
      const repoFromFlag = toOptionalString(getFlagValue(parsed.flags, ["repo"]));
      const promptFromFlag = toOptionalString(getFlagValue(parsed.flags, ["prompt"]));
      const verify = toOptionalString(getFlagValue(parsed.flags, ["verify"]));
      const base = toOptionalString(getFlagValue(parsed.flags, ["base"])) ?? "main";
      const engineRaw = (toOptionalString(getFlagValue(parsed.flags, ["engine"])) ?? "codex").toLowerCase();
      const engine = engineRaw === "none" ? "none" : engineRaw === "codex" ? "codex" : undefined;

      const repo = repoFromFlag ?? parsed.positional[0];
      const promptPositional = parsed.positional.slice(1).join(" ").trim();
      const prompt = promptFromFlag ?? (promptPositional.length > 0 ? promptPositional : undefined);

      if (!repo || !prompt) {
        ctx.ui.notify('Usage: /nightshift-quick --repo <name> --prompt "..." [--verify "..."] [--engine codex|none] [--base main]', "warning");
        return;
      }
      if (!engine) {
        ctx.ui.notify("Invalid engine. Allowed values: codex, none.", "warning");
        return;
      }

      const config = resolveConfig();
      const taskId = normalizeTaskId(prompt.slice(0, 40));
      const branch = `night/${taskId}`;

      const taskBlock = `## TASK ${taskId}
repo: ${repo}
base: ${base}
branch: ${branch}
engine: ${engine}${verify ? "\nverify:\n- " + verify : ""}
prompt:
${prompt}
ENDPROMPT

`;

      const validated = parseTasks(taskBlock);
      if (validated.length === 0) {
        ctx.ui.notify("Failed to generate valid task block. Check your input.", "error");
        return;
      }

      ensureDirs(config);
      let existing = "";
      try {
        existing = readFileSync(config.tasksFile, "utf-8");
      } catch {
        existing = "# Night Shift Tasks\n\n";
      }

      writeFileSync(config.tasksFile, existing + taskBlock, "utf-8");

      notifyBlock(
        ctx,
        `Added nightshift task: ${taskId}\nBranch: ${branch}\n\nRun with: /nightshift run --only ${taskId}`,
        "info",
      );
    },
  });
}
