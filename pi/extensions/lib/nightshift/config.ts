import { join } from "node:path";
import type { NightshiftConfig } from "./types.ts";

export function resolveConfig(env: Record<string, string | undefined> = process.env): NightshiftConfig {
  const home = env.HOME ?? "/tmp";
  const projectRoot = env.PI_PROJECT_ROOT ?? join(home, "projects");
  const worktreeRoot = env.PI_WORKTREE_ROOT ?? join(projectRoot, "worktrees");
  const stateDir = env.NIGHTSHIFT_STATE_DIR ?? join(home, ".local", "state", "nightshift");

  return {
    projectRoot,
    worktreeRoot,
    stateDir,
    tasksFile: join(stateDir, "tasks.md"),
    stateFile: join(stateDir, "state.json"),
    historyFile: join(stateDir, "history.jsonl"),
    logDir: join(stateDir, "logs"),
    lastReportFile: join(stateDir, "last-run-report.md"),
    lastReportJsonFile: join(stateDir, "last-run-report.json"),
  };
}
