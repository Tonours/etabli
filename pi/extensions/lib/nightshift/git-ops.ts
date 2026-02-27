import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { execFileSync } from "node:child_process";

export interface CommitAndPushResult {
  success: boolean;
  error?: string;
}

function git(dir: string, ...args: string[]): string {
  return execFileSync("git", ["-C", dir, ...args], {
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

export function ensureNightshiftGitignore(workDir: string): void {
  const gitignorePath = join(workDir, ".gitignore");
  let content = "";

  if (existsSync(gitignorePath)) {
    content = readFileSync(gitignorePath, "utf-8");
    if (content.split("\n").some((line) => line.trim() === ".nightshift/")) {
      return;
    }
  }

  writeFileSync(gitignorePath, content + ".nightshift/\n", "utf-8");
}

function findRemote(workDir: string): string | null {
  try {
    const remotes = git(workDir, "remote").split("\n").filter((r) => r.trim());
    if (remotes.includes("origin")) return "origin";
    return remotes[0] ?? null;
  } catch {
    return null;
  }
}

function stageChanges(workDir: string): void {
  const modified = git(workDir, "diff", "--name-only").split("\n").filter((f) => f.trim());
  const untracked = git(workDir, "ls-files", "--others", "--exclude-standard").split("\n").filter((f) => f.trim());
  const filesToAdd = [...modified, ...untracked];

  if (filesToAdd.length > 0) {
    git(workDir, "add", ...filesToAdd);
  }

  try {
    git(workDir, "add", ".gitignore");
  } catch {
    // .gitignore may not exist or be unchanged
  }
}

function hasChangesToCommit(workDir: string): boolean {
  const staged = git(workDir, "diff", "--cached", "--name-only").split("\n").filter((f) => f.trim());
  return staged.length > 0;
}

export function commitAndPush(workDir: string, branch: string, message: string): CommitAndPushResult {
  const remote = findRemote(workDir);
  if (!remote) return { success: false, error: "no remote found" };

  ensureNightshiftGitignore(workDir);

  try {
    stageChanges(workDir);

    if (hasChangesToCommit(workDir)) {
      git(workDir, "commit", "-m", message);
    }
  } catch {
    return { success: false, error: "commit failed" };
  }

  try {
    git(workDir, "push", "-u", remote, branch);
  } catch {
    return { success: false, error: "push failed" };
  }

  return { success: true };
}
