import { describe, expect, test, beforeEach } from "bun:test";
import { mkdtempSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execSync } from "node:child_process";
import { commitAndPush, ensureNightshiftGitignore } from "../git-ops.ts";

let tempDir: string;
let repoDir: string;
let remoteDir: string;

function git(dir: string, cmd: string): string {
  return execSync(`git -C "${dir}" ${cmd}`, { encoding: "utf-8", stdio: ["ignore", "pipe", "pipe"] }).trim();
}

function initRepoWithRemote(): void {
  // Create bare remote
  remoteDir = join(tempDir, "remote.git");
  execSync(`git init --bare -b main ${remoteDir}`, { stdio: "ignore" });

  // Create local repo
  repoDir = join(tempDir, "local");
  execSync(`git init -b main ${repoDir}`, { stdio: "ignore" });
  writeFileSync(join(repoDir, "README.md"), "# Test\n");
  git(repoDir, "add README.md");
  git(repoDir, 'commit -m "initial"');
  git(repoDir, `remote add origin "${remoteDir}"`);
  git(repoDir, "push -u origin main");
}

beforeEach(() => {
  tempDir = mkdtempSync(join(tmpdir(), "nightshift-git-ops-test-"));
  initRepoWithRemote();
});

describe("ensureNightshiftGitignore", () => {
  test("adds .nightshift/ to .gitignore if not present", () => {
    ensureNightshiftGitignore(repoDir);

    const gitignore = readFileSync(join(repoDir, ".gitignore"), "utf-8");
    expect(gitignore).toContain(".nightshift/");
  });

  test("does not duplicate if already present", () => {
    writeFileSync(join(repoDir, ".gitignore"), ".nightshift/\n");
    ensureNightshiftGitignore(repoDir);

    const gitignore = readFileSync(join(repoDir, ".gitignore"), "utf-8");
    const occurrences = gitignore.split(".nightshift/").length - 1;
    expect(occurrences).toBe(1);
  });
});

describe("commitAndPush", () => {
  test("commits only changed/new files selectively (no git add -A)", () => {
    // Create tracked changes
    writeFileSync(join(repoDir, "changed.txt"), "new content\n");
    git(repoDir, "add changed.txt");
    git(repoDir, 'commit -m "add changed.txt"');
    git(repoDir, "push");

    // Modify file
    writeFileSync(join(repoDir, "changed.txt"), "modified\n");
    // Also create a new untracked file
    writeFileSync(join(repoDir, "new-file.txt"), "hello\n");

    const result = commitAndPush(repoDir, "main", "nightshift: test-task");
    expect(result.success).toBe(true);

    // Verify commit happened
    const log = git(repoDir, 'log --oneline -1');
    expect(log).toContain("nightshift: test-task");
  });

  test("pushes to remote after commit", () => {
    writeFileSync(join(repoDir, "push-test.txt"), "data\n");

    const result = commitAndPush(repoDir, "main", "nightshift: push-test");
    expect(result.success).toBe(true);

    // Verify remote has the commit
    const remoteLog = execSync(`git -C "${remoteDir}" log --oneline`, { encoding: "utf-8" });
    expect(remoteLog).toContain("nightshift: push-test");
  });

  test("succeeds with no changes (nothing to commit)", () => {
    const result = commitAndPush(repoDir, "main", "nightshift: no-changes");
    expect(result.success).toBe(true);
  });

  test("returns error when no remote exists", () => {
    const noRemoteDir = join(tempDir, "no-remote");
    execSync(`git init -b main ${noRemoteDir}`, { stdio: "ignore" });
    writeFileSync(join(noRemoteDir, "file.txt"), "data\n");
    git(noRemoteDir, "add file.txt");
    git(noRemoteDir, 'commit -m "initial"');
    // Remove the remote
    try { git(noRemoteDir, "remote remove origin"); } catch { /* no remote */ }

    const result = commitAndPush(noRemoteDir, "main", "nightshift: test");
    expect(result.success).toBe(false);
    expect(result.error).toContain("no remote");
  });
});
