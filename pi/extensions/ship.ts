import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { join } from "node:path";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { parseCommandArgs, getFlagValue, toBoolean, toOptionalString, notifyBlock } from "./lib/args.ts";
import {
  normalizeSegment,
  getRepoName,
  createRepoKey,
  getSessionKey,
  isShipResult,
  summarizeLast7Days,
  appendHistory,
  readHistory,
  pruneHistory,
  type ShipStatePaths,
  type ShipCurrentRun,
  type ShipHistoryEntry,
  type ShipResult,
} from "./lib/ship-utils.ts";

type ShipSubcommand = "start" | "mark" | "status" | "finalize";

const SHIP_BASE_STATE_DIR = join(homedir(), ".local", "state", "pi-ship");
const SHIP_SUBCOMMANDS = new Set<ShipSubcommand>(["start", "mark", "status", "finalize"]);

// Fix M-4: pipeline steps tracked
const PIPELINE_STEPS = ["plan", "plan-review", "implement", "verify", "review"] as const;

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

function formatStartResponse(run: ShipCurrentRun, auto: boolean): string {
  const lines = [
    `Started /ship run: ${run.runId}`,
    `Task: ${run.task}`,
    `Repo: ${run.repoName}`,
    `Session: ${run.sessionKey}`,
    "",
    "Pipeline:",
    "1) /skill:plan",
    "2) /skill:plan-review",
    "3) implement",
    "4) /skill:verify",
    "5) /skill:review",
    "",
    "When finished, record decision:",
    '/ship mark --result go --notes "ready to commit"',
    "or",
    '/ship mark --result block --notes "why blocked"',
  ];

  if (auto) {
    lines.splice(3, 0, "Queued /skill:plan and /skill:plan-review.");
  }

  return lines.join("\n");
}

// Fix M-4: show completed vs pending steps
function formatFinalizeResponse(run: ShipCurrentRun, runChecks: boolean): string {
  const completed = new Set(run.completedSteps);
  const pendingSteps = PIPELINE_STEPS.filter((s) => !completed.has(s));

  const lines = [
    `Finalize requested for: ${run.task}`,
    `Run ID: ${run.runId}`,
    "",
  ];

  if (completed.size > 0) {
    lines.push(`Completed: ${[...completed].join(", ")}`);
  }
  if (pendingSteps.length > 0) {
    lines.push(`Pending: ${pendingSteps.join(", ")}`);
  }

  lines.push("");
  lines.push("Next:");
  lines.push("- ensure verify + review are complete");
  lines.push("- then record decision with /ship mark --result go|block");

  if (runChecks) {
    // Fix M-4: only queue steps not already completed
    const toQueue: string[] = [];
    if (!completed.has("verify")) toQueue.push("/skill:verify");
    if (!completed.has("review")) toQueue.push("/skill:review");
    if (toQueue.length > 0) {
      lines.splice(3, 0, `Queued ${toQueue.join(" and ")}.`);
    }
  }

  return lines.join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("ship", {
    description: "Orchestrate plan->verify->review pipeline with GO/BLOCK tracking",
    handler: async (args, ctx) => {
      const parsed = parseCommandArgs(args);
      const firstPositional = parsed.positional[0];
      const subcommand = SHIP_SUBCOMMANDS.has(firstPositional as ShipSubcommand)
        ? (firstPositional as ShipSubcommand)
        : undefined;

      if (!subcommand) {
        ctx.ui.notify("Usage: /ship <start|mark|status|finalize> [--flags]", "warning");
        return;
      }

      const repoPath = getRepoPath();
      const repoName = getRepoName(repoPath);
      // Fix I-6: deterministic session key
      const sessionKey = getSessionKey();
      const statePaths = getStatePaths(repoPath, sessionKey);
      ensureStateDir(statePaths);

      const taskFromFlag = toOptionalString(getFlagValue(parsed.flags, ["task"]));
      const taskFromPositionals = parsed.positional.slice(1).join(" ").trim();
      const task = taskFromFlag ?? (taskFromPositionals.length > 0 ? taskFromPositionals : undefined);

      const resultFromFlag = toOptionalString(getFlagValue(parsed.flags, ["result"]));
      const positionalResult = parsed.positional[1];
      const result = resultFromFlag ?? positionalResult;

      const notesFromFlag = toOptionalString(getFlagValue(parsed.flags, ["notes"]));
      const positionalNotes = parsed.positional.slice(2).join(" ").trim();
      const notes = notesFromFlag ?? (positionalNotes.length > 0 ? positionalNotes : undefined);

      const auto = toBoolean(getFlagValue(parsed.flags, ["auto"]), true);
      const runChecks = toBoolean(getFlagValue(parsed.flags, ["run-checks", "runChecks"]), true);

      if (subcommand === "start") {
        if (!task || task.trim().length === 0) {
          ctx.ui.notify('Missing task. Usage: /ship start --task "..."', "warning");
          return;
        }

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
          runId: run.runId,
          status: "started",
          task: run.task,
          startedAt: run.startedAt,
          repoPath,
          repoName,
          sessionKey,
        });

        if (auto) {
          if (ctx.isIdle()) {
            pi.sendUserMessage(`/skill:plan ${run.task}`);
          } else {
            pi.sendUserMessage(`/skill:plan ${run.task}`, { deliverAs: "steer" });
          }
          pi.sendUserMessage("/skill:plan-review", { deliverAs: "followUp" });
        }

        notifyBlock(ctx, formatStartResponse(run, auto), "info");
        return;
      }

      if (subcommand === "finalize") {
        const current = readCurrentRun(statePaths);
        if (!current) {
          ctx.ui.notify('No active /ship run for this repo. Start one with /ship start --task "..."', "warning");
          return;
        }

        if (runChecks) {
          // Fix M-4: only queue not-yet-completed steps
          const completed = new Set(current.completedSteps);
          if (!completed.has("verify")) {
            if (ctx.isIdle()) {
              pi.sendUserMessage("/skill:verify");
            } else {
              pi.sendUserMessage("/skill:verify", { deliverAs: "steer" });
            }
          }
          if (!completed.has("review")) {
            pi.sendUserMessage("/skill:review", { deliverAs: "followUp" });
          }
        }

        notifyBlock(ctx, formatFinalizeResponse(current, runChecks), "info");
        return;
      }

      if (subcommand === "mark") {
        if (!isShipResult(result)) {
          ctx.ui.notify('Missing result. Usage: /ship mark --result go|block [--notes "..."]', "warning");
          return;
        }

        const current = readCurrentRun(statePaths);
        const startedAt = current?.startedAt ?? nowIso();
        const taskName = current?.task ?? task?.trim() ?? "(unknown task)";
        const runId = current?.runId ?? createRunId();

        appendHistory(statePaths, {
          runId,
          status: result,
          task: taskName,
          startedAt,
          endedAt: nowIso(),
          notes: notes?.trim(),
          repoPath,
          repoName,
          sessionKey,
        });

        if (current) {
          clearCurrentRun(statePaths);
        }

        ctx.ui.notify(`Recorded SHIP_${result.toUpperCase()} for: ${taskName}`, "info");
        return;
      }

      // status subcommand
      const current = readCurrentRun(statePaths);
      // Fix C-5: pass sessionKey to summarizeLast7Days
      const summary = summarizeLast7Days(readHistory(statePaths), sessionKey);
      const currentText = current
        ? `Current run: ${current.runId}\nTask: ${current.task}\nRepo: ${current.repoName}\nSession: ${current.sessionKey}\nStarted: ${current.startedAt}\n`
        : `Current run: none\nRepo: ${repoName}\nSession: ${sessionKey}\n`;

      notifyBlock(ctx, `${currentText}\n${summary}`, "info");
    },
  });
}
