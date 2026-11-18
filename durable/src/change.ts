import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

export async function git(cwd: string, args: readonly string[]): Promise<string> {
  return (await promisify(execFile)("git", ["-C", cwd, ...args], { encoding: "utf8", timeout: 120_000, maxBuffer: 16_000_000 })).stdout.trimEnd();
}

export async function change(cwd: string): Promise<{ base: string; patch: string; hash: string }> {
  const remote = await git(cwd, ["symbolic-ref", "refs/remotes/origin/HEAD"]);
  if (!remote.startsWith("refs/remotes/origin/")) throw new Error("Default branch unresolved");
  const base = await git(cwd, ["merge-base", "HEAD", remote]);
  let patch = await git(cwd, ["diff", "--binary", "--no-ext-diff", base, "--"]);
  const untracked = await git(cwd, ["ls-files", "--others", "--exclude-standard", "-z"]);
  for (const path of untracked.split("\0").filter(Boolean)) {
    const data = await readFile(join(cwd, path));
    if (data.length > 2_000_000) throw new Error("Untracked review file exceeds two megabytes");
    patch += `\nUntracked ${JSON.stringify(path)}\n${data.toString("base64")}\n`;
    if (patch.length > 4_000_000) throw new Error("Review patch exceeds four megabytes");
  }
  if (!patch.trim() || patch.length > 4_000_000) throw new Error("Provide a nonempty bounded change for review");
  return { base, patch, hash: createHash("sha256").update(patch).digest("hex") };
}
