import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, openSync, readFileSync, writeFileSync, closeSync } from "node:fs";
import { join } from "node:path";
import { checkBinaries } from "./checks.ts";

export interface RunEngineOptions {
  workDir: string;
  taskId: string;
  prompt: string;
  engine: "codex" | "none";
  logFile: string;
}

export interface RunEngineResult {
  success: boolean;
  error?: string;
}

const ENGINE_SYSTEM_PROMPT = `You are a senior engineer running an overnight batch task.

Read .nightshift/TASK.md and implement it.
Constraints:
- No browser.
- Do not create PRs.
- Do not merge.
- Prefer minimal changes.
- After implementation, run the verify commands listed in the task (if any).
- Leave the working tree in a clean state if possible.

If you need to choose between options, pick the simplest that ships.`;

export function writeTaskFiles(workDir: string, taskId: string, prompt: string, engine: string, base: string, branch: string, repoName: string): void {
  const nightshiftDir = join(workDir, ".nightshift");
  mkdirSync(nightshiftDir, { recursive: true });

  writeFileSync(
    join(nightshiftDir, "TASK.md"),
    `# Night Shift Task: ${taskId}\n\nRepo: ${repoName}\nBase: ${base}\nBranch: ${branch}\nEngine: ${engine}\n\n## Prompt\n${prompt}`,
    "utf-8",
  );

  writeFileSync(join(nightshiftDir, "ENGINE_PROMPT.txt"), ENGINE_SYSTEM_PROMPT, "utf-8");
}

export function runEngine(opts: RunEngineOptions): RunEngineResult {
  if (opts.engine === "none") {
    return { success: true };
  }

  // Fix I-2: check binary availability upfront
  const { missing } = checkBinaries(["codex"]);
  if (missing.length > 0) {
    return { success: false, error: `missing binary: ${missing.join(", ")}` };
  }

  try {
    const promptPath = join(opts.workDir, ".nightshift", "ENGINE_PROMPT.txt");
    const stdinFd = openSync(promptPath, "r");
    try {
      const result = spawnSync("codex", ["exec", "--full-auto", "-C", opts.workDir, "-o", opts.logFile, "-"], {
        cwd: opts.workDir,
        stdio: [stdinFd, "ignore", "ignore"],
      });
      if (result.status !== 0) {
        return { success: false, error: "engine failed" };
      }
    } finally {
      closeSync(stdinFd);
    }
    return { success: true };
  } catch {
    return { success: false, error: "engine failed" };
  }
}
