import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
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
  detectStepFromInput,
  type ShipStatePaths,
  type ShipCurrentRun,
  type ShipResult,
  type PipelineStep,
} from "./lib/ship-utils.ts";

type ShipSubcommand = "start" | "mark" | "status" | "finalize";

interface ShipEnv {
  pi: ExtensionAPI;
  ctx: ExtensionCommandContext;
  paths: ShipStatePaths;
  repoPath: string;
  repoName: string;
  sessionKey: string;
}

const SHIP_BASE_STATE_DIR = join(homedir(), ".local", "state", "pi-ship");
const SHIP_SUBCOMMANDS = new Set<ShipSubcommand>(["start", "mark", "status", "finalize"]);

function nowIso(): string {
  return new Date().toISOString();
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
  pruneHistory(paths);
}

function createRunId(): string {
  return `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
}

function readCurrentRun(paths: ShipStatePaths): ShipCurrentRun | null {
  if (!existsSync(paths.currentFile)) return null;
  try {
    const raw = JSON.parse(readFileSync(paths.currentFile, "utf-8")) as ShipCurrentRun;
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
  if (existsSync(paths.currentFile)) rmSync(paths.currentFile, { force: true });
}

function startRun(env: ShipEnv, task: string, auto: boolean): void {
  const run: ShipCurrentRun = {
    runId: createRunId(),
    task,
    startedAt: nowIso(),
    auto,
    repoPath: env.repoPath,
    repoName: env.repoName,
    sessionKey: env.sessionKey,
    completedSteps: [],
  };

  writeCurrentRun(env.paths, run);
  appendHistory(env.paths, {
    runId: run.runId, status: "started", task: run.task,
    startedAt: run.startedAt, repoPath: env.repoPath, repoName: env.repoName, sessionKey: env.sessionKey,
  });

  if (auto) {
    env.pi.sendUserMessage(`/skill:plan ${run.task}`, { deliverAs: "steer" });
    env.pi.sendUserMessage("/skill:plan-review", { deliverAs: "followUp" });
  }

  notifyBlock(env.ctx, formatStartResponse(run, auto), "info");
}

function markRun(env: ShipEnv, result: ShipResult, notes: string | undefined, taskOverride?: string): void {
  const current = readCurrentRun(env.paths);
  const taskName = current?.task ?? taskOverride ?? "(unknown task)";

  appendHistory(env.paths, {
    runId: current?.runId ?? createRunId(),
    status: result,
    task: taskName,
    startedAt: current?.startedAt ?? nowIso(),
    endedAt: nowIso(),
    notes: notes?.trim(),
    repoPath: env.repoPath,
    repoName: env.repoName,
    sessionKey: env.sessionKey,
  });

  if (current) clearCurrentRun(env.paths);
  env.ctx.ui.notify(`Recorded SHIP_${result.toUpperCase()} for: ${taskName}`, "info");
}

// -- Step tracking --

function addCompletedStep(paths: ShipStatePaths, step: PipelineStep): void {
  const current = readCurrentRun(paths);
  if (!current) return;
  if (current.completedSteps.includes(step)) return;
  current.completedSteps.push(step);
  writeCurrentRun(paths, current);
}

// -- Subcommand handlers --

async function handleStart(env: ShipEnv, args: ReturnType<typeof parseCommandArgs>): Promise<void> {
  const taskFromFlag = toOptionalString(getFlagValue(args.flags, ["task"]));
  const taskFromPositionals = args.positional.slice(1).join(" ").trim();
  const task = taskFromFlag ?? (taskFromPositionals.length > 0 ? taskFromPositionals : undefined);

  if (!task) {
    const input = await env.ctx.ui.input("Ship — task description", "What are you shipping?");
    if (!input?.trim()) return;
    const auto = await env.ctx.ui.confirm("Ship — auto-run", "Queue /skill:plan + /skill:plan-review?");
    startRun(env, input.trim(), auto);
    return;
  }

  const auto = toBoolean(getFlagValue(args.flags, ["auto"]), true);
  startRun(env, task.trim(), auto);
}

async function handleMark(env: ShipEnv, args: ReturnType<typeof parseCommandArgs>): Promise<void> {
  const resultFromFlag = toOptionalString(getFlagValue(args.flags, ["result"]));
  const result = resultFromFlag ?? args.positional[1];

  if (!isShipResult(result)) {
    const current = readCurrentRun(env.paths);
    const taskName = current?.task ?? "(unknown task)";
    const choice = await env.ctx.ui.select(`Ship — mark result for: ${taskName}`, ["🟢 go", "🔴 block"]);
    if (!choice) return;
    const picked: ShipResult = choice.includes("go") ? "go" : "block";
    const notes = await env.ctx.ui.input("Ship — notes (optional)", "Any notes?");
    markRun(env, picked, notes);
    return;
  }

  const notesFromFlag = toOptionalString(getFlagValue(args.flags, ["notes"]));
  const positionalNotes = args.positional.slice(2).join(" ").trim();
  const notes = notesFromFlag ?? (positionalNotes.length > 0 ? positionalNotes : undefined);
  const taskOverride = toOptionalString(getFlagValue(args.flags, ["task"]))?.trim();
  markRun(env, result, notes, taskOverride);
}

function handleFinalize(env: ShipEnv, args: ReturnType<typeof parseCommandArgs>): void {
  const current = readCurrentRun(env.paths);
  if (!current) {
    env.ctx.ui.notify("No active /ship run. Use /ship start or /ship → 🚀 start.", "warning");
    return;
  }

  const runChecks = toBoolean(getFlagValue(args.flags, ["run-checks", "runChecks"]), true);
  if (runChecks) {
    const completed = new Set(current.completedSteps);
    if (!completed.has("verify")) env.pi.sendUserMessage("/skill:verify", { deliverAs: "steer" });
    if (!completed.has("review")) env.pi.sendUserMessage("/skill:review", { deliverAs: "followUp" });
  }
  notifyBlock(env.ctx, formatFinalizeResponse(current, runChecks), "info");
}

function handleStatus(env: ShipEnv): void {
  const current = readCurrentRun(env.paths);
  const summary = summarizeLast7Days(readHistory(env.paths), env.sessionKey);

  const lines: string[] = [];
  if (current) {
    const completed = current.completedSteps.length > 0 ? current.completedSteps.join(", ") : "none";
    lines.push(`Current: ${current.task}`, `Run: ${current.runId} | Steps: ${completed}`, `Started: ${current.startedAt}`);
  } else {
    lines.push(`No active run | Repo: ${env.repoName}`);
  }
  lines.push("", summary);
  notifyBlock(env.ctx, lines.join("\n"), "info");
}

// -- Extension entry point --

export default function (pi: ExtensionAPI) {
  // Track pending step to mark as completed when the agent finishes processing it
  let pendingStep: PipelineStep | undefined;
  let activeStatePaths: ShipStatePaths | undefined;

  pi.on("input", async (event) => {
    const step = detectStepFromInput(event.text);
    if (!step || !activeStatePaths) return;
    const current = readCurrentRun(activeStatePaths);
    if (!current) return;
    pendingStep = step;
  });

  pi.on("agent_end", async () => {
    if (!pendingStep || !activeStatePaths) return;
    addCompletedStep(activeStatePaths, pendingStep);
    pendingStep = undefined;
  });

  pi.registerCommand("ship", {
    description: "Orchestrate plan→verify→review pipeline with GO/BLOCK tracking",
    handler: async (args, ctx) => {
      const repoPath = process.cwd();
      const repoName = getRepoName(repoPath);
      const sessionKey = getSessionKey();
      const paths = getStatePaths(repoPath, sessionKey);
      ensureStateDir(paths);
      activeStatePaths = paths;

      const parsed = parseCommandArgs(args);
      let subcommand = SHIP_SUBCOMMANDS.has(parsed.positional[0] as ShipSubcommand)
        ? (parsed.positional[0] as ShipSubcommand)
        : undefined;

      if (!subcommand) {
        const current = readCurrentRun(paths);
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

      const env: ShipEnv = { pi, ctx, paths, repoPath, repoName, sessionKey };

      if (subcommand === "start") return handleStart(env, parsed);
      if (subcommand === "mark") return handleMark(env, parsed);
      if (subcommand === "finalize") return handleFinalize(env, parsed);
      handleStatus(env);
    },
  });
}
