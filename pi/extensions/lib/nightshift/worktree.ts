import { existsSync } from "node:fs";
import { join } from "node:path";
import { execFileSync } from "node:child_process";

export interface EnsureWorktreeOptions {
  repoDir: string;
  repoName: string;
  base: string;
  branch: string;
  taskId: string;
  worktreeRoot: string;
}

function git(repoDir: string, ...args: string[]): string {
  return execFileSync("git", ["-C", repoDir, ...args], {
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function refExists(repoDir: string, ref: string): boolean {
  try {
    git(repoDir, "show-ref", "--verify", "--quiet", ref);
    return true;
  } catch {
    return false;
  }
}

export function ensureWorktree(opts: EnsureWorktreeOptions): string {
  const wtPath = join(opts.worktreeRoot, `${opts.repoName}-${opts.taskId}`);

  if (existsSync(join(wtPath, ".git"))) {
    return wtPath;
  }

  try {
    git(opts.repoDir, "fetch", "origin", "--prune");
  } catch {
    // no remote is fine
  }

  // Priority:
  // 1. Local branch exists → checkout it
  // 2. Remote branch exists → track it
  // 3. Remote base exists → branch from it
  // 4. Local base exists → branch from it
  // 5. Fallback → branch from current HEAD
  if (refExists(opts.repoDir, `refs/heads/${opts.branch}`)) {
    git(opts.repoDir, "worktree", "add", wtPath, opts.branch);
  } else if (refExists(opts.repoDir, `refs/remotes/origin/${opts.branch}`)) {
    git(opts.repoDir, "worktree", "add", wtPath, "-b", opts.branch, `origin/${opts.branch}`);
  } else if (refExists(opts.repoDir, `refs/remotes/origin/${opts.base}`)) {
    git(opts.repoDir, "worktree", "add", wtPath, "-b", opts.branch, `origin/${opts.base}`);
  } else if (refExists(opts.repoDir, `refs/heads/${opts.base}`)) {
    git(opts.repoDir, "worktree", "add", wtPath, "-b", opts.branch, opts.base);
  } else {
    git(opts.repoDir, "worktree", "add", wtPath, "-b", opts.branch);
  }

  return wtPath;
}

export function cleanWorktrees(repoDir: string): number {
  try {
    const output = git(repoDir, "worktree", "list", "--porcelain");
    const worktrees = output
      .split("\n\n")
      .filter((block) => block.includes("worktree "))
      .map((block) => {
        const match = block.match(/^worktree (.+)$/m);
        return match?.[1];
      })
      .filter((p): p is string => !!p);

    let cleaned = 0;
    for (const wt of worktrees) {
      if (wt === repoDir) continue;
      if (!existsSync(wt)) {
        try {
          git(repoDir, "worktree", "remove", wt, "--force");
          cleaned++;
        } catch {
          // If remove fails, try prune
        }
      }
    }

    // Also prune any stale entries
    try {
      git(repoDir, "worktree", "prune");
    } catch {
      // ignore
    }

    return cleaned;
  } catch {
    return 0;
  }
}
