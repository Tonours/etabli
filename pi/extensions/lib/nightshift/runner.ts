import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { parseTasks } from "./parse-tasks.ts";
import { readState, updateTaskState } from "./state.ts";
import { appendHistory } from "./history.ts";
import { checkBinaries } from "./checks.ts";
import { ensureWorktree } from "./worktree.ts";
import { runVerify } from "./verify.ts";
import { commitAndPush, ensureNightshiftGitignore } from "./git-ops.ts";
import { runEngine, writeTaskFiles } from "./engine.ts";
import { generateMarkdownReport, generateJsonReport } from "./report.ts";
import type { NightshiftConfig, RunReport, RunReportTask } from "./types.ts";

export interface RunOptions {
  dryRun: boolean;
  verifyOnly: boolean;
  requireVerify: boolean;
  only?: string;
  limit: number;
}

function nowIso(): string {
  return new Date().toISOString().replace(/\.\d+Z$/, "Z");
}

function failTask(
  config: NightshiftConfig,
  runId: string,
  task: { id: string; branch: string; engine: string },
  opts: { verifyOnly: boolean },
  reportTasks: RunReportTask[],
  meta: { repoDir: string; worktree: string; startedAt: string; error: string; verify?: string },
): void {
  updateTaskState(config.stateFile, task.id, "status", "failed");
  updateTaskState(config.stateFile, task.id, "lastError", meta.error);
  const endedAt = nowIso();
  appendHistory(config.historyFile, {
    runId, taskId: task.id, status: "failed", verify: meta.verify ?? "skipped", engine: task.engine,
    branch: task.branch, repoDir: meta.repoDir, worktree: meta.worktree, startedAt: meta.startedAt,
    endedAt, error: meta.error, logFile: "", verifyOnly: opts.verifyOnly,
  });
  reportTasks.push({
    taskId: task.id, status: "failed", verify: meta.verify ?? "skipped", branch: task.branch,
    engine: task.engine, repoDir: meta.repoDir, worktree: meta.worktree, startedAt: meta.startedAt,
    endedAt, error: meta.error, logFile: "",
  });
}

export async function cmdRun(config: NightshiftConfig, opts: RunOptions): Promise<string> {
  const { missing } = checkBinaries(["git"]);
  if (missing.length > 0) {
    return `Missing required binaries: ${missing.join(", ")}`;
  }

  if (!existsSync(config.tasksFile)) {
    return `No tasks file found: ${config.tasksFile}\nRun /nightshift init to create one.`;
  }

  const content = readFileSync(config.tasksFile, "utf-8");
  let tasks = parseTasks(content);

  if (opts.only) {
    const ids = new Set(opts.only.split(",").map((s) => s.trim()).filter(Boolean));
    tasks = tasks.filter((t) => ids.has(t.id));
  }

  if (tasks.length === 0) return `No tasks found in: ${config.tasksFile}`;

  const runId = `${new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14)}-${process.pid}`;
  const runStarted = nowIso();
  const reportTasks: RunReportTask[] = [];
  let doneCount = 0;
  let failedCount = 0;
  let skippedCount = 0;

  for (let i = 0; i < tasks.length; i++) {
    if (opts.limit > 0 && i >= opts.limit) {
      skippedCount++;
      continue;
    }

    const task = tasks[i];
    const startedAt = nowIso();

    const state = readState(config.stateFile);
    if (state.tasks[task.id]?.status === "done") {
      skippedCount++;
      reportTasks.push({
        taskId: task.id, status: "skipped", verify: "n/a", branch: task.branch,
        engine: task.engine, repoDir: "", worktree: "", startedAt: "", endedAt: "",
        error: "already done", logFile: "",
      });
      continue;
    }

    updateTaskState(config.stateFile, task.id, "status", "running");
    updateTaskState(config.stateFile, task.id, "lastRunAt", startedAt);
    updateTaskState(config.stateFile, task.id, "branch", task.branch);

    let repoDir: string;
    let repoName: string;
    if (task.path) {
      repoDir = task.path.replace(/^~/, process.env.HOME ?? "~");
      repoName = basename(repoDir);
    } else {
      repoName = task.repo ?? task.id;
      repoDir = join(config.projectRoot, repoName);
    }

    if (opts.dryRun) {
      updateTaskState(config.stateFile, task.id, "status", "todo");
      skippedCount++;
      reportTasks.push({
        taskId: task.id, status: "dry-run", verify: "n/a", branch: task.branch,
        engine: task.engine, repoDir, worktree: "", startedAt, endedAt: startedAt,
        error: "", logFile: "",
      });
      continue;
    }

    if (!existsSync(join(repoDir, ".git"))) {
      failTask(config, runId, task, opts, reportTasks, { repoDir, worktree: "", startedAt, error: `repo not found: ${repoDir}` });
      failedCount++;
      continue;
    }

    if (opts.requireVerify && task.verify.length === 0) {
      failTask(config, runId, task, opts, reportTasks, { repoDir, worktree: "", startedAt, error: "verify commands required", verify: "failed" });
      updateTaskState(config.stateFile, task.id, "verify", "failed");
      failedCount++;
      continue;
    }

    let wt: string;
    try {
      wt = ensureWorktree({
        repoDir, repoName, base: task.base, branch: task.branch,
        taskId: task.id, worktreeRoot: config.worktreeRoot,
      });
    } catch (err) {
      failTask(config, runId, task, opts, reportTasks, {
        repoDir, worktree: "", startedAt,
        error: `worktree failed: ${err instanceof Error ? err.message : String(err)}`,
      });
      failedCount++;
      continue;
    }
    updateTaskState(config.stateFile, task.id, "worktree", wt);

    try {
      writeTaskFiles(wt, task.id, task.prompt, task.engine, task.base, task.branch, repoName);
    } catch (err) {
      failTask(config, runId, task, opts, reportTasks, {
        repoDir, worktree: wt, startedAt,
        error: `write task files failed: ${err instanceof Error ? err.message : String(err)}`,
      });
      failedCount++;
      continue;
    }

    const ts = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);
    const logFile = join(config.logDir, `${task.id}-${ts}.log`);

    let failed = false;
    let verifyStatus = "skipped";
    let taskError = "";

    if (!opts.verifyOnly) {
      const engineResult = runEngine({
        workDir: wt, taskId: task.id, prompt: task.prompt,
        engine: task.engine, logFile,
      });
      if (!engineResult.success) {
        failed = true;
        taskError = engineResult.error ?? "engine failed";
      }
    }

    if (task.verify.length > 0) {
      const verifyResult = await runVerify(wt, task.verify);
      if (verifyResult.status === "ok") {
        verifyStatus = "ok";
        updateTaskState(config.stateFile, task.id, "verify", "ok");
      } else {
        verifyStatus = "failed";
        failed = true;
        updateTaskState(config.stateFile, task.id, "verify", "failed");
        if (!taskError) taskError = "verify failed";
      }
    }

    if (!opts.verifyOnly) {
      ensureNightshiftGitignore(wt);
      const cpResult = commitAndPush(wt, task.branch, `nightshift: ${task.id}`);
      if (!cpResult.success) {
        failed = true;
        if (!taskError) taskError = cpResult.error ?? "commit/push failed";
      }
    }

    const endedAt = nowIso();

    if (failed) {
      updateTaskState(config.stateFile, task.id, "status", "failed");
      updateTaskState(config.stateFile, task.id, "lastError", taskError);
      failedCount++;
    } else {
      updateTaskState(config.stateFile, task.id, "status", "done");
      updateTaskState(config.stateFile, task.id, "lastError", "");
      doneCount++;
    }

    appendHistory(config.historyFile, {
      runId, taskId: task.id, status: failed ? "failed" : "done", verify: verifyStatus,
      engine: task.engine, branch: task.branch, repoDir, worktree: wt,
      startedAt, endedAt, error: taskError, logFile, verifyOnly: opts.verifyOnly,
    });

    reportTasks.push({
      taskId: task.id, status: failed ? "failed" : "done", verify: verifyStatus,
      branch: task.branch, engine: task.engine, repoDir, worktree: wt,
      startedAt, endedAt, error: taskError, logFile,
    });
  }

  const runFinished = nowIso();
  const report: RunReport = {
    runId, startedAt: runStarted, finishedAt: runFinished,
    verifyOnly: opts.verifyOnly, requireVerify: opts.requireVerify,
    tasksFile: config.tasksFile,
    summary: { done: doneCount, failed: failedCount, skipped: skippedCount },
    tasks: reportTasks,
  };

  writeFileSync(config.lastReportFile, generateMarkdownReport(report), "utf-8");
  writeFileSync(config.lastReportJsonFile, generateJsonReport(report), "utf-8");

  return [
    `Run complete: ${runId}`,
    `Done: ${doneCount}, Failed: ${failedCount}, Skipped: ${skippedCount}`,
    `Report: ${config.lastReportFile}`,
    `Report JSON: ${config.lastReportJsonFile}`,
  ].join("\n");
}
