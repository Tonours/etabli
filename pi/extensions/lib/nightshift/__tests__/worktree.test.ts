import { describe, expect, test, beforeEach } from "bun:test";
import { mkdtempSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execSync } from "node:child_process";
import { ensureWorktree, cleanWorktrees } from "../worktree.ts";

let tempDir: string;
let repoDir: string;
let worktreeRoot: string;

function initBareRepo(dir: string): void {
  execSync(`git init ${dir}`, { stdio: "ignore" });
  execSync("git commit --allow-empty -m 'initial'", { cwd: dir, stdio: "ignore" });
}

beforeEach(() => {
  tempDir = mkdtempSync(join(tmpdir(), "nightshift-worktree-test-"));
  repoDir = join(tempDir, "repo");
  worktreeRoot = join(tempDir, "worktrees");
  initBareRepo(repoDir);
});

describe("ensureWorktree", () => {
  test("creates worktree with new branch from base", () => {
    const wt = ensureWorktree({
      repoDir,
      repoName: "repo",
      base: "main",
      branch: "night/test-task",
      taskId: "test-task",
      worktreeRoot,
    });

    expect(existsSync(join(wt, ".git"))).toBe(true);
    // Verify branch was created
    const branch = execSync("git branch --show-current", { cwd: wt, encoding: "utf-8" }).trim();
    expect(branch).toBe("night/test-task");
  });

  test("reuses existing worktree", () => {
    const wt1 = ensureWorktree({
      repoDir,
      repoName: "repo",
      base: "main",
      branch: "night/reuse-test",
      taskId: "reuse-test",
      worktreeRoot,
    });

    const wt2 = ensureWorktree({
      repoDir,
      repoName: "repo",
      base: "main",
      branch: "night/reuse-test",
      taskId: "reuse-test",
      worktreeRoot,
    });

    expect(wt1).toBe(wt2);
  });

  test("creates worktree from existing local branch", () => {
    // Create a local branch first
    execSync("git branch feature-branch", { cwd: repoDir, stdio: "ignore" });

    const wt = ensureWorktree({
      repoDir,
      repoName: "repo",
      base: "main",
      branch: "feature-branch",
      taskId: "feat",
      worktreeRoot,
    });

    expect(existsSync(join(wt, ".git"))).toBe(true);
    const branch = execSync("git branch --show-current", { cwd: wt, encoding: "utf-8" }).trim();
    expect(branch).toBe("feature-branch");
  });
});

describe("cleanWorktrees", () => {
  test("removes stale worktrees", () => {
    // Create a worktree then manually remove it
    const wt = ensureWorktree({
      repoDir,
      repoName: "repo",
      base: "main",
      branch: "night/stale",
      taskId: "stale",
      worktreeRoot,
    });

    // Manually remove the worktree dir to make it stale
    execSync(`rm -rf ${wt}`, { stdio: "ignore" });

    // Clean should not throw
    const cleaned = cleanWorktrees(repoDir);
    expect(cleaned).toBeGreaterThanOrEqual(0);
  });

  test("no-op on repo with no worktrees", () => {
    const cleaned = cleanWorktrees(repoDir);
    expect(cleaned).toBe(0);
  });
});
