/**
 * Nightshift type definitions.
 *
 * Backward-compatible with the existing state.json, history.jsonl, and tasks.md formats
 * produced by the original bash + Python nightshift script.
 */

// -- Task parsing --

export interface NightshiftTask {
  id: string;
  repo?: string;
  path?: string;
  base: string;
  branch: string;
  engine: "codex" | "none";
  verify: string[];
  prompt: string;
}

// -- Config resolution --

export interface NightshiftConfig {
  projectRoot: string;
  worktreeRoot: string;
  stateDir: string;
  tasksFile: string;
  stateFile: string;
  historyFile: string;
  logDir: string;
  lastReportFile: string;
  lastReportJsonFile: string;
}

// -- State persistence --

export interface NightshiftTaskState {
  status?: string;
  branch?: string;
  worktree?: string;
  lastRunAt?: string;
  lastError?: string;
  verify?: string;
}

export interface NightshiftState {
  version: number;
  tasks: Record<string, NightshiftTaskState>;
}

// -- History --

export interface NightshiftHistoryEntry {
  runId: string;
  taskId: string;
  status: "done" | "failed" | "dry-run" | "skipped";
  verify: string;
  engine: string;
  branch: string;
  repoDir: string;
  worktree: string;
  startedAt: string;
  endedAt: string;
  error: string;
  logFile: string;
  verifyOnly: boolean;
}

// -- Run report --

export interface RunReportTask {
  taskId: string;
  status: string;
  verify: string;
  branch: string;
  engine: string;
  repoDir: string;
  worktree: string;
  startedAt: string;
  endedAt: string;
  error: string;
  logFile: string;
}

export interface RunReportSummary {
  done: number;
  failed: number;
  skipped: number;
}

export interface RunReport {
  runId: string;
  startedAt: string;
  finishedAt: string;
  verifyOnly: boolean;
  requireVerify: boolean;
  tasksFile: string;
  summary: RunReportSummary;
  tasks: RunReportTask[];
}
