import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

type ShipSubcommand = "start" | "mark" | "status";
type ShipResult = "go" | "block";

type ShipHistoryStatus = "started" | ShipResult;

interface ShipCurrentRun {
  runId: string;
  task: string;
  startedAt: string;
  auto: boolean;
}

interface ShipHistoryEntry {
  runId: string;
  status: ShipHistoryStatus;
  task: string;
  startedAt: string;
  endedAt?: string;
  notes?: string;
}

const STATE_DIR = join(homedir(), ".local", "state", "pi-ship");
const CURRENT_FILE = join(STATE_DIR, "current.json");
const HISTORY_FILE = join(STATE_DIR, "history.jsonl");

function nowIso(): string {
  return new Date().toISOString();
}

function ensureStateDir(): void {
  mkdirSync(STATE_DIR, { recursive: true });
  if (!existsSync(HISTORY_FILE)) {
    writeFileSync(HISTORY_FILE, "", "utf-8");
  }
}

function createRunId(): string {
  const rand = Math.random().toString(16).slice(2, 8);
  return `${Date.now()}-${rand}`;
}

function readCurrentRun(): ShipCurrentRun | null {
  if (!existsSync(CURRENT_FILE)) return null;
  try {
    return JSON.parse(readFileSync(CURRENT_FILE, "utf-8")) as ShipCurrentRun;
  } catch {
    return null;
  }
}

function writeCurrentRun(run: ShipCurrentRun): void {
  writeFileSync(CURRENT_FILE, `${JSON.stringify(run, null, 2)}\n`, "utf-8");
}

function clearCurrentRun(): void {
  if (existsSync(CURRENT_FILE)) {
    rmSync(CURRENT_FILE, { force: true });
  }
}

function appendHistory(entry: ShipHistoryEntry): void {
  const line = `${JSON.stringify(entry)}\n`;
  writeFileSync(HISTORY_FILE, line, { encoding: "utf-8", flag: "a" });
}

function readHistory(): ShipHistoryEntry[] {
  if (!existsSync(HISTORY_FILE)) return [];
  const lines = readFileSync(HISTORY_FILE, "utf-8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  const entries: ShipHistoryEntry[] = [];
  for (const line of lines) {
    try {
      entries.push(JSON.parse(line) as ShipHistoryEntry);
    } catch {
      // Ignore malformed line
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
    lines.splice(2, 0, "Queued /skill:plan and /skill:plan-review.");
  }

  return lines.join("\n");
}

function isShipResult(value: string | undefined): value is ShipResult {
  return value === "go" || value === "block";
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.notify("Ship extension loaded — /ship {start,mark,status}", "info");
  });

  pi.registerCommand({
    name: "ship",
    description: "Orchestrate plan->verify->review pipeline with GO/BLOCK tracking",
    parameters: {
      type: "object",
      properties: {
        subcommand: {
          type: "string",
          enum: ["start", "mark", "status"],
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
      ensureStateDir();

      const { subcommand, task, auto = true, result, notes } = params as {
        subcommand: ShipSubcommand;
        task?: string;
        auto?: boolean;
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
        };

        writeCurrentRun(run);
        appendHistory({
          runId: run.runId,
          status: "started",
          task: run.task,
          startedAt: run.startedAt,
        });

        if (auto) {
          pi.sendUserMessage(`/skill:plan ${run.task}`);
          pi.sendUserMessage("/skill:plan-review", { deliverAs: "followUp" });
        }

        return {
          content: [{ type: "text", text: formatStartResponse(run, auto) }],
        };
      }

      if (subcommand === "mark") {
        if (!isShipResult(result)) {
          return {
            content: [{ type: "text", text: "Missing result. Usage: /ship mark --result go|block [--notes \"...\"]" }],
            isError: true,
          };
        }

        const current = readCurrentRun();
        const startedAt = current?.startedAt ?? nowIso();
        const taskName = current?.task ?? task?.trim() ?? "(unknown task)";
        const runId = current?.runId ?? createRunId();

        appendHistory({
          runId,
          status: result,
          task: taskName,
          startedAt,
          endedAt: nowIso(),
          notes: notes?.trim(),
        });

        if (current) {
          clearCurrentRun();
        }

        return {
          content: [{ type: "text", text: `Recorded SHIP_${result.toUpperCase()} for: ${taskName}` }],
        };
      }

      const current = readCurrentRun();
      const summary = summarizeLast7Days(readHistory());
      const currentText = current
        ? `Current run: ${current.runId}\nTask: ${current.task}\nStarted: ${current.startedAt}\n`
        : "Current run: none\n";

      return {
        content: [{ type: "text", text: `${currentText}\n${summary}` }],
      };
    },
  });
}
