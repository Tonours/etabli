/**
 * Shared utilities for the Ship extension.
 * Extracted for testability and reuse.
 */

import { createHash } from "node:crypto";
import { basename, dirname, join } from "node:path";
import { existsSync, readFileSync, writeFileSync, renameSync } from "node:fs";

// -- Types --

export type ShipResult = "go" | "block";
export type ShipHistoryStatus = "started" | ShipResult;

export interface ShipStatePaths {
  dir: string;
  currentFile: string;
  historyFile: string;
  sessionKey: string;
}

export interface ShipCurrentRun {
  runId: string;
  task: string;
  startedAt: string;
  auto: boolean;
  repoPath: string;
  repoName: string;
  sessionKey: string;
  completedSteps: string[];
}

export interface ShipHistoryEntry {
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

// -- Pure helpers --

export function normalizeSegment(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
}

export function getRepoName(repoPath: string): string {
  const name = basename(repoPath);
  const normalized = normalizeSegment(name);
  return normalized.length > 0 ? normalized : "repo";
}

export function createRepoKey(repoPath: string): string {
  const hash = createHash("sha1").update(repoPath).digest("hex").slice(0, 12);
  return `${getRepoName(repoPath)}-${hash}`;
}

export function isShipResult(value: string | undefined): value is ShipResult {
  return value === "go" || value === "block";
}

// Fix I-6: deterministic fallback chain, never "default"
export function getSessionKey(env: Record<string, string | undefined> = process.env): string {
  const candidates = [
    env.PI_SHIP_SESSION,
    env.TMUX_PANE,
    env.TTY,
  ];

  for (const raw of candidates) {
    if (raw) {
      const normalized = normalizeSegment(raw);
      if (normalized.length > 0) return normalized;
    }
  }

  return `pid-${process.pid}`;
}

// Fix C-5: filter by sessionKey
export function summarizeLast7Days(entries: ShipHistoryEntry[], sessionKey: string): string {
  const weekMs = 7 * 24 * 60 * 60 * 1000;
  const cutoff = Date.now() - weekMs;

  const recent = entries.filter((entry) => {
    if (entry.sessionKey !== sessionKey) return false;
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

// -- I/O helpers --

export function appendHistory(paths: ShipStatePaths, entry: ShipHistoryEntry): void {
  const line = `${JSON.stringify(entry)}\n`;
  writeFileSync(paths.historyFile, line, { encoding: "utf-8", flag: "a" });
}

export function readHistory(paths: ShipStatePaths): ShipHistoryEntry[] {
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
      // skip malformed
    }
  }
  return entries;
}

// Fix I-3: prune history with atomic write-rename
export function pruneHistory(paths: ShipStatePaths, max: number = 500): void {
  if (!existsSync(paths.historyFile)) return;

  const entries = readHistory(paths);
  if (entries.length <= max) return;

  const kept = entries.slice(-max);
  const content = kept.map((e) => JSON.stringify(e)).join("\n") + "\n";

  const tmpFile = join(dirname(paths.historyFile), `.history-${process.pid}-${Date.now()}.tmp`);
  writeFileSync(tmpFile, content, "utf-8");
  renameSync(tmpFile, paths.historyFile);
}

// -- Format helpers --

const PIPELINE_STEPS = ["plan", "plan-review", "implement", "verify", "review"] as const;

export function formatStartResponse(run: ShipCurrentRun, auto: boolean): string {
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

export function formatFinalizeResponse(run: ShipCurrentRun, runChecks: boolean): string {
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
    const toQueue: string[] = [];
    if (!completed.has("verify")) toQueue.push("/skill:verify");
    if (!completed.has("review")) toQueue.push("/skill:review");
    if (toQueue.length > 0) {
      lines.splice(3, 0, `Queued ${toQueue.join(" and ")}.`);
    }
  }

  return lines.join("\n");
}
