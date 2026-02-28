import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { join } from "node:path";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { parseCommandArgs, getFlagValue, toBoolean, toOptionalString, notifyBlock } from "./lib/args.ts";
import {
  getRepoName,
  createRepoKey,
  getSessionKey,
  isShipResult,
  summarizeLast7Days,
  appendHistory,
  readHistory,
  pruneHistory,
  formatStartResponse,
  formatFinalizeResponse,
  type ShipStatePaths,
  type ShipCurrentRun,
  type ShipResult,
} from "./lib/ship-utils.ts";

type ShipSubcommand = "start" | "mark" | "status" | "finalize";

const SHIP_BASE_STATE_DIR = join(homedir(), ".local", "state", "pi-ship");
const SHIP_SUBCOMMANDS = new Set<ShipSubcommand>(["start", "mark", "status", "finalize"]);

function nowIso(): string {
  return new Date().toISOString();
}

function getRepoPath(): string {
  return process.cwd();
}

function getStatePaths(repoPath: string, sessionKey: string): ShipStatePaths {
  const repoKey = createRepoKey(repoPath);
  const dir = join(SHIP_BASE_STATE_DIR, repoKey);
  return {
    dir,
    currentFile: join(dir, `current-${sessionKey}.json`),
    historyFile: join(dir, "history.jsonl"),
    sessionKey,
  };
}

function ensureStateDir(paths: ShipStatePaths): void {
  mkdirSync(paths.dir, { recursive: true });
  if (!existsSync(paths.historyFile)) {
    writeFileSync(paths.historyFile, "", "utf-8");
  }
  // Fix I-3: prune on startup
  pruneHistory(paths);
}

function createRunId(): string {
  const rand = Math.random().toString(16).slice(2, 8);
  return `${Date.now()}-${rand}`;
}

function readCurrentRun(paths: ShipStatePaths): ShipCurrentRun | null {
  if (!existsSync(paths.currentFile)) return null;
  try {
    const raw = JSON.parse(readFileSync(paths.currentFile, "utf-8")) as ShipCurrentRun;
    // Fix M-4: ensure completedSteps exists for older state files
    if (!raw.completedSteps) raw.completedSteps = [];
    return raw;
  } catch {
    return null;
  }
}

function writeCurrentRun(paths: ShipStatePaths, run: ShipCurrentRun): void {
  writeFileSync(paths.currentFile, `${JSON.stringify(run, null, 2)}\n`, "utf-8");
}

function clearCurrentRun(paths: ShipStatePaths): void {
  if (existsSync(paths.currentFile)) {
    rmSync(paths.currentFile, { force: true });
  }
}

async function interactiveStart(
  pi: ExtensionAPI,
  ctx: import("@mariozechner/pi-coding-agent").ExtensionCommandContext,
  statePaths: ShipStatePaths,
  repoPath: string,
  repoName: string,
  sessionKey: string,
): Promise<void> {
  const task = await ctx.ui.input("Ship — task description", "What are you shipping?");
  if (!task?.trim()) return;

  const auto = await ctx.ui.confirm("Ship — auto-run", "Queue /skill:plan + /skill:plan-review?");

  const run: ShipCurrentRun = {
    runId: createRunId(),
    task: task.trim(),
    startedAt: nowIso(),
    auto,
    repoPath,
    repoName,
    sessionKey,
    completedSteps: [],
  };

  writeCurrentRun(statePaths, run);
  appendHistory(statePaths, {
    runId: run.runId, status: "started", task: run.task,
    startedAt: run.startedAt, repoPath, repoName, sessionKey,
  });

  if (auto) {
    pi.sendUserMessage(`/skill:plan ${run.task}`, { deliverAs: "steer" });
    pi.sendUserMessage("/skill:plan-review", { deliverAs: "followUp" });
  }

  notifyBlock(ctx, formatStartResponse(run, auto), "info");
}

async function interactiveMark(
  ctx: import("@mariozechner/pi-coding-agent").ExtensionCommandContext,
  statePaths: ShipStatePaths,
  repoPath: string,
  repoName: string,
  sessionKey: string,
): Promise<void> {
  const current = readCurrentRun(statePaths);
  const taskName = current?.task ?? "(unknown task)";

  const choice = await ctx.ui.select(`Ship — mark result for: ${taskName}`, ["🟢 go", "🔴 block"]);
  if (!choice) return;
  const result: ShipResult = choice.includes("go") ? "go" : "block";

  const notes = await ctx.ui.input("Ship — notes (optional)", "Any notes?");

  const startedAt = current?.startedAt ?? nowIso();
  const runId = current?.runId ?? createRunId();

  appendHistory(statePaths, {
    runId, status: result, task: taskName, startedAt,
    endedAt: nowIso(), notes: notes?.trim(), repoPath, repoName, sessionKey,
  });

  if (current) clearCurrentRun(statePaths);
  ctx.ui.notify(`Recorded SHIP_${result.toUpperCase()} for: ${taskName}`, "info");
}

function handleFinalize(
  pi: ExtensionAPI,
  ctx: import("@mariozechner/pi-coding-agent").ExtensionCommandContext,
  statePaths: ShipStatePaths,
  current: ShipCurrentRun,
  runChecks: boolean,
): void {
  if (runChecks) {
    const completed = new Set(current.completedSteps);
    if (!completed.has("verify")) {
      pi.sendUserMessage("/skill:verify", { deliverAs: "steer" });
    }
    if (!completed.has("review")) {
      pi.sendUserMessage("/skill:review", { deliverAs: "followUp" });
    }
  }
  notifyBlock(ctx, formatFinalizeResponse(current, runChecks), "info");
}

function handleStatus(
  ctx: import("@mariozechner/pi-coding-agent").ExtensionCommandContext,
  statePaths: ShipStatePaths,
  repoName: string,
  sessionKey: string,
): void {
  const current = readCurrentRun(statePaths);
  const summary = summarizeLast7Days(readHistory(statePaths), sessionKey);
  const currentText = current
    ? `Current run: ${current.runId}\nTask: ${current.task}\nRepo: ${current.repoName}\nSession: ${current.sessionKey}\nStarted: ${current.startedAt}\n`
    : `Current run: none\nRepo: ${repoName}\nSession: ${sessionKey}\n`;
  notifyBlock(ctx, `${currentText}\n${summary}`, "info");
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("ship", {
    description: "Orchestrate plan->verify->review pipeline with GO/BLOCK tracking",
    handler: async (args, ctx) => {
      const repoPath = getRepoPath();
      const repoName = getRepoName(repoPath);
      const sessionKey = getSessionKey();
      const statePaths = getStatePaths(repoPath, sessionKey);
      ensureStateDir(statePaths);

      const parsed = parseCommandArgs(args);
      const firstPositional = parsed.positional[0];
      let subcommand = SHIP_SUBCOMMANDS.has(firstPositional as ShipSubcommand)
        ? (firstPositional as ShipSubcommand)
        : undefined;

      // Interactive mode: no subcommand → show picker
      if (!subcommand) {
        const current = readCurrentRun(statePaths);
        const options = current
          ? ["📊 status", "🏁 finalize", "✅ mark go/block", "🚀 start new"]
          : ["🚀 start", "📊 status"];

        const choice = await ctx.ui.select("Ship — what do you want to do?", options);
        if (!choice) return;

        if (choice.includes("start")) subcommand = "start";
        else if (choice.includes("mark")) subcommand = "mark";
        else if (choice.includes("finalize")) subcommand = "finalize";
        else if (choice.includes("status")) subcommand = "status";
        else return;
      }

      if (subcommand === "start") {
        const taskFromFlag = toOptionalString(getFlagValue(parsed.flags, ["task"]));
        const taskFromPositionals = parsed.positional.slice(1).join(" ").trim();
        const task = taskFromFlag ?? (taskFromPositionals.length > 0 ? taskFromPositionals : undefined);

        if (!task) {
          await interactiveStart(pi, ctx, statePaths, repoPath, repoName, sessionKey);
          return;
        }

        const auto = toBoolean(getFlagValue(parsed.flags, ["auto"]), true);
        const run: ShipCurrentRun = {
          runId: createRunId(), task: task.trim(), startedAt: nowIso(),
          auto, repoPath, repoName, sessionKey, completedSteps: [],
        };

        writeCurrentRun(statePaths, run);
        appendHistory(statePaths, {
          runId: run.runId, status: "started", task: run.task,
          startedAt: run.startedAt, repoPath, repoName, sessionKey,
        });

        if (auto) {
          pi.sendUserMessage(`/skill:plan ${run.task}`, { deliverAs: "steer" });
          pi.sendUserMessage("/skill:plan-review", { deliverAs: "followUp" });
        }

        notifyBlock(ctx, formatStartResponse(run, auto), "info");
        return;
      }

      if (subcommand === "finalize") {
        const current = readCurrentRun(statePaths);
        if (!current) {
          ctx.ui.notify('No active /ship run. Start one with /ship start --task "..."', "warning");
          return;
        }
        const runChecks = toBoolean(getFlagValue(parsed.flags, ["run-checks", "runChecks"]), true);
        handleFinalize(pi, ctx, statePaths, current, runChecks);
        return;
      }

      if (subcommand === "mark") {
        const resultFromFlag = toOptionalString(getFlagValue(parsed.flags, ["result"]));
        const positionalResult = parsed.positional[1];
        const result = resultFromFlag ?? positionalResult;

        if (!isShipResult(result)) {
          await interactiveMark(ctx, statePaths, repoPath, repoName, sessionKey);
          return;
        }

        const notesFromFlag = toOptionalString(getFlagValue(parsed.flags, ["notes"]));
        const positionalNotes = parsed.positional.slice(2).join(" ").trim();
        const notes = notesFromFlag ?? (positionalNotes.length > 0 ? positionalNotes : undefined);

        const current = readCurrentRun(statePaths);
        const startedAt = current?.startedAt ?? nowIso();
        const taskName = current?.task ?? toOptionalString(getFlagValue(parsed.flags, ["task"]))?.trim() ?? "(unknown task)";
        const runId = current?.runId ?? createRunId();

        appendHistory(statePaths, {
          runId, status: result, task: taskName, startedAt,
          endedAt: nowIso(), notes: notes?.trim(), repoPath, repoName, sessionKey,
        });

        if (current) clearCurrentRun(statePaths);
        ctx.ui.notify(`Recorded SHIP_${result.toUpperCase()} for: ${taskName}`, "info");
        return;
      }

      handleStatus(ctx, statePaths, repoName, sessionKey);
    },
  });
}
