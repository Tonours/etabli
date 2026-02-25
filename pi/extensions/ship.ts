import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { createHash } from "node:crypto";
import { basename, join } from "node:path";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";

type ShipSubcommand = "start" | "mark" | "status" | "finalize";
type ShipResult = "go" | "block";
type ShipHistoryStatus = "started" | ShipResult;

interface ShipStatePaths {
  dir: string;
  currentFile: string;
  historyFile: string;
  sessionKey: string;
}

interface ShipCurrentRun {
  runId: string;
  task: string;
  startedAt: string;
  auto: boolean;
  repoPath: string;
  repoName: string;
  sessionKey: string;
}

interface ShipHistoryEntry {
  runId: string;
  status: ShipHistoryStatus;
  task: string;
  startedAt: string;
  endedAt?: string;
  notes?: string;
  repoPath: string;
  repoName: string;
  sessionKey: string;
}

const SHIP_BASE_STATE_DIR = join(homedir(), ".local", "state", "pi-ship");

function nowIso(): string {
  return new Date().toISOString();
}

function normalizeSegment(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
}

function getRepoPath(): string {
  return process.cwd();
}

function getRepoName(repoPath: string): string {
  const name = basename(repoPath);
  const normalized = normalizeSegment(name);
  return normalized.length > 0 ? normalized : "repo";
}

function createRepoKey(repoPath: string): string {
  const hash = createHash("sha1").update(repoPath).digest("hex").slice(0, 12);
  return `${getRepoName(repoPath)}-${hash}`;
}

function getSessionKey(): string {
  const raw = process.env.PI_SHIP_SESSION ?? process.env.TMUX_PANE ?? "default";
  const normalized = normalizeSegment(raw);
  return normalized.length > 0 ? normalized : "default";
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
}

function createRunId(): string {
  const rand = Math.random().toString(16).slice(2, 8);
  return `${Date.now()}-${rand}`;
}

function readCurrentRun(paths: ShipStatePaths): ShipCurrentRun | null {
  if (!existsSync(paths.currentFile)) return null;
  try {
    return JSON.parse(readFileSync(paths.currentFile, "utf-8")) as ShipCurrentRun;
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

function appendHistory(paths: ShipStatePaths, entry: ShipHistoryEntry): void {
  const line = `${JSON.stringify(entry)}\n`;
  writeFileSync(paths.historyFile, line, { encoding: "utf-8", flag: "a" });
}

function readHistory(paths: ShipStatePaths): ShipHistoryEntry[] {
  if (!existsSync(paths.historyFile)) return [];
  const lines = readFileSync(paths.historyFile, "utf-8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  const entries: ShipHistoryEntry[] = [];
  for (const line of lines) {
    try {
      entries.push(JSON.parse(line) as ShipHistoryEntry);
    } catch {
      // Ignore malformed lines.
    }
  }
  return entries;
}

function summarizeLast7Days(entries: ShipHistoryEntry[]): string {
  const weekMs = 7 * 24 * 60 * 60 * 1000;
  const cutoff = Date.now() - weekMs;

  const recent = entries.filter((entry) => {
    const ts = Date.parse(entry.startedAt);
    return Number.isFinite(ts) && ts >= cutoff;
  });

  const started = recent.filter((entry) => entry.status === "started").length;
  const go = recent.filter((entry) => entry.status === "go").length;
  const block = recent.filter((entry) => entry.status === "block").length;

  const lines = [
    `Last 7 days: started=${started}, go=${go}, block=${block}`,
    "",
    "Recent decisions:",
  ];

  const recentDecisions = recent
    .filter((entry) => entry.status === "go" || entry.status === "block")
    .slice(-10)
    .reverse();

  if (recentDecisions.length === 0) {
    lines.push("- No GO/BLOCK decision recorded yet.");
    return lines.join("\n");
  }

  for (const entry of recentDecisions) {
    const stamp = entry.endedAt ?? entry.startedAt;
    const notes = entry.notes ? ` — ${entry.notes}` : "";
    lines.push(`- [${entry.status.toUpperCase()}] ${stamp} | ${entry.task}${notes}`);
  }

  return lines.join("\n");
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
    "/ship mark --result go --notes \"ready to commit\"",
    "or",
    "/ship mark --result block --notes \"why blocked\"",
  ];

  if (auto) {
    lines.splice(3, 0, "Queued /skill:plan and /skill:plan-review.");
  }

  return lines.join("\n");
}

function formatFinalizeResponse(run: ShipCurrentRun, runChecks: boolean): string {
  const lines = [
    `Finalize requested for: ${run.task}`,
    `Run ID: ${run.runId}`,
    "",
    "Next:",
    "- ensure verify + review are complete",
    "- then record decision with /ship mark --result go|block",
  ];

  if (runChecks) {
    lines.splice(3, 0, "Queued /skill:verify and /skill:review.");
  }

  return lines.join("\n");
}

function isShipResult(value: string | undefined): value is ShipResult {
  return value === "go" || value === "block";
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.notify("Ship extension loaded — /ship {start,mark,status,finalize}", "info");
  });

  pi.registerCommand({
    name: "ship",
    description: "Orchestrate plan->verify->review pipeline with GO/BLOCK tracking",
    parameters: {
      type: "object",
      properties: {
        subcommand: {
          type: "string",
          enum: ["start", "mark", "status", "finalize"],
          description: "Action to execute",
        },
        task: {
          type: "string",
          description: "Task description for /ship start",
        },
        auto: {
          type: "boolean",
          description: "Auto-queue plan steps on start",
          default: true,
        },
        runChecks: {
          type: "boolean",
          description: "Queue verify/review during /ship finalize",
          default: true,
        },
        result: {
          type: "string",
          enum: ["go", "block"],
          description: "Decision for /ship mark",
        },
        notes: {
          type: "string",
          description: "Optional notes for /ship mark",
        },
      },
      required: ["subcommand"],
    },
    async execute(params) {
      const repoPath = getRepoPath();
      const repoName = getRepoName(repoPath);
      const sessionKey = getSessionKey();
      const statePaths = getStatePaths(repoPath, sessionKey);
      ensureStateDir(statePaths);

      const { subcommand, task, auto = true, runChecks = true, result, notes } = params as {
        subcommand: ShipSubcommand;
        task?: string;
        auto?: boolean;
        runChecks?: boolean;
        result?: string;
        notes?: string;
      };

      if (subcommand === "start") {
        if (!task || task.trim().length === 0) {
          return {
            content: [{ type: "text", text: "Missing task. Usage: /ship start --task \"...\"" }],
            isError: true,
          };
        }

        const run: ShipCurrentRun = {
          runId: createRunId(),
          task: task.trim(),
          startedAt: nowIso(),
          auto,
          repoPath,
          repoName,
          sessionKey,
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
          pi.sendUserMessage(`/skill:plan ${run.task}`);
          pi.sendUserMessage("/skill:plan-review", { deliverAs: "followUp" });
        }

        return {
          content: [{ type: "text", text: formatStartResponse(run, auto) }],
        };
      }

      if (subcommand === "finalize") {
        const current = readCurrentRun(statePaths);
        if (!current) {
          return {
            content: [{ type: "text", text: "No active /ship run for this repo. Start one with /ship start --task \"...\"" }],
            isError: true,
          };
        }

        if (runChecks) {
          pi.sendUserMessage("/skill:verify");
          pi.sendUserMessage("/skill:review", { deliverAs: "followUp" });
        }

        return {
          content: [{ type: "text", text: formatFinalizeResponse(current, runChecks) }],
        };
      }

      if (subcommand === "mark") {
        if (!isShipResult(result)) {
          return {
            content: [{ type: "text", text: "Missing result. Usage: /ship mark --result go|block [--notes \"...\"]" }],
            isError: true,
          };
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

        return {
          content: [{ type: "text", text: `Recorded SHIP_${result.toUpperCase()} for: ${taskName}` }],
        };
      }

      const current = readCurrentRun(statePaths);
      const summary = summarizeLast7Days(readHistory(statePaths));
      const currentText = current
        ? `Current run: ${current.runId}\nTask: ${current.task}\nRepo: ${current.repoName}\nSession: ${current.sessionKey}\nStarted: ${current.startedAt}\n`
        : `Current run: none\nRepo: ${repoName}\nSession: ${sessionKey}\n`;

      return {
        content: [{ type: "text", text: `${currentText}\n${summary}` }],
      };
    },
  });
}
