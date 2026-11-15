import { mkdir, rename, rm, stat } from "node:fs/promises";
import { join, resolve } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { OwnerPolicy } from "./policy.ts";

async function git(cwd: string, args: readonly string[]): Promise<string> {
  return (await promisify(execFile)("git", ["-C", cwd, ...args], { encoding: "utf8", timeout: 120_000, maxBuffer: 4_000_000 })).stdout.trim();
}

export class Repositories {
  readonly root: string;
  readonly policy: OwnerPolicy;
  readonly source: (repo: string) => string;
  readonly identity: (repo: string) => Promise<string>;

  constructor(root: string, policy: OwnerPolicy, source = (repo: string) => `https://github.com/${repo}.git`, identity = async (repo: string) => (await promisify(execFile)("gh", ["repo", "view", repo, "--json", "nameWithOwner", "--jq", ".nameWithOwner"], { timeout: 10_000, encoding: "utf8" })).stdout.trim()) {
    this.root = root;
    this.policy = policy;
    this.source = source;
    this.identity = identity;
  }

  path(id: string): string { return join(this.root, "worktrees", id); }

  async admit(target: string): Promise<string> {
    const repo = this.policy.allow(target);
    let actual: string;
    try { actual = await this.identity(repo); } catch { throw new Error("Repository identity could not be verified"); }
    this.policy.allow(actual);
    const cache = join(this.root, "repos", `${repo.replace("/", "--")}.git`);
    if (await stat(cache).then(() => true, () => false)) {
      const origin = await git(cache, ["remote", "get-url", "origin"]);
      const pushes = (await git(cache, ["remote", "get-url", "--push", "--all", "origin"])).split("\n");
      if (origin !== this.source(repo) || pushes.some((url) => url !== this.source(repo))) throw new Error("Repository cache remote changed; admission refused");
    }
    return repo;
  }

  async prepare(id: string, target: string, branch: string): Promise<string> {
    const repo = await this.admit(target);
    const cache = join(this.root, "repos", `${repo.replace("/", "--")}.git`);
    const destination = this.path(id);
    await mkdir(join(this.root, "repos"), { recursive: true, mode: 0o700 });
    await mkdir(join(this.root, "worktrees"), { recursive: true, mode: 0o700 });
    const exists = await stat(cache).then(() => true, () => false);
    if (!exists) {
      const temporary = `${cache}.creating`;
      const unfinished = await stat(temporary).then(() => true, () => false);
      if (unfinished) await rm(temporary, { recursive: true, force: true });
      await promisify(execFile)("git", ["clone", "--bare", this.source(repo), temporary], { timeout: 120_000 });
      await rename(temporary, cache);
    }
    const origin = await git(cache, ["remote", "get-url", "origin"]);
    if (origin !== this.source(repo)) throw new Error("Repository cache origin changed; admission refused");
    const base = (await git(cache, ["symbolic-ref", "HEAD"])).replace("refs/heads/", "");
    if (!/^[A-Za-z0-9_./-]+$/.test(base)) throw new Error("Default branch unresolved");
    await git(cache, ["config", `remote.origin.fetch`, "+refs/heads/*:refs/remotes/origin/*"]);
    await git(cache, ["fetch", "origin"]);
    await git(cache, ["symbolic-ref", "refs/remotes/origin/HEAD", `refs/remotes/origin/${base}`]);
    const present = await stat(destination).then(() => true, () => false);
    if (present) {
      const common = await git(destination, ["rev-parse", "--git-common-dir"]);
      if (resolve(destination, common) !== resolve(cache) || await git(destination, ["branch", "--show-current"]) !== branch) throw new Error("Run worktree identity changed");
      return destination;
    }
    await git(cache, ["worktree", "prune"]);
    let branchExists = false;
    try { await git(cache, ["show-ref", "--verify", `refs/heads/${branch}`]); branchExists = true; } catch {}
    await git(cache, branchExists ? ["worktree", "add", destination, branch] : ["worktree", "add", "-b", branch, destination, `refs/remotes/origin/${base}`]);
    return destination;
  }
}
