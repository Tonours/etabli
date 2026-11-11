import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { constants } from "node:fs";
import { lstat, open, realpath } from "node:fs/promises";
import { hostname, platform } from "node:os";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { validateTarget, type Fact } from "./core.ts";

export const localIdentity = (cwd: string) => ({ hostname: hostname(), cwd, platform: platform() });

export interface ProcessResult { stdout: string; stderr: string; code: number; killed: boolean; truncated: boolean }

export async function run(program: string, args: string[], cwd: string, stdin: string, signal?: AbortSignal): Promise<ProcessResult> {
  if (signal?.aborted) throw new Error("aborted");
  return new Promise((resolveResult, reject) => {
    const child = spawn(program, args, { cwd, detached: true, stdio: ["pipe", "pipe", "pipe"] });
    const out: Buffer[] = [], err: Buffer[] = [];
    let size = 0, killed = false, truncated = false, settled = false;
    let exitCode = 128;
    const finish = (code: number) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      signal?.removeEventListener("abort", stop);
      resolveResult({ stdout: Buffer.concat(out).toString(), stderr: Buffer.concat(err).toString(), code, killed, truncated });
    };
    const stop = () => {
      if (killed) return;
      killed = true;
      if (child.pid) { try { process.kill(-child.pid, "SIGTERM"); } catch { } }
      setTimeout(() => {
        if (child.pid) { try { process.kill(-child.pid, "SIGKILL"); } catch { } }
        child.stdin.destroy(); child.stdout.destroy(); child.stderr.destroy();
        finish(exitCode);
      }, 250);
    };
    const collect = (chunks: Buffer[], data: Buffer) => {
      size += data.length;
      if (size > 65536) { truncated = true; stop(); return; }
      chunks.push(data);
    };
    const timeout = setTimeout(stop, 60000);
    signal?.addEventListener("abort", stop, { once: true });
    if (signal?.aborted) stop();
    child.stdout.on("data", (data: Buffer) => collect(out, data));
    child.stderr.on("data", (data: Buffer) => collect(err, data));
    child.stdin.on("error", () => {});
    child.stdin.end(stdin);
    child.on("error", (error) => {
      clearTimeout(timeout);
      signal?.removeEventListener("abort", stop);
      if (!settled) { settled = true; reject(error); }
    });
    child.on("exit", (code) => { exitCode = code ?? 128; });
    child.on("close", (code) => finish(code ?? 128));
  });
}

const quote = (value: string) => `'${value.replaceAll("'", "'\\''")}'`;
export function remoteScript(command: string, nonce: string): string {
  return `printf '\\nGEMMA_${nonce}_BEGIN\\n'\nhostname\npwd -P\nuname -s\nprintf 'GEMMA_${nonce}_BODY\\n'\n/bin/sh -c ${quote(command)} </dev/null\ncode=$?\nprintf '\\nGEMMA_${nonce}_END:%s\\n' "$code"\nexit 0\n`;
}

export function parseRemote(result: ProcessResult, nonce: string): Fact {
  const begin = `\nGEMMA_${nonce}_BEGIN\n`, body = `GEMMA_${nonce}_BODY\n`, end = `\nGEMMA_${nonce}_END:`;
  const first = result.stdout.indexOf(begin), middle = result.stdout.indexOf(body, first + begin.length), last = result.stdout.lastIndexOf(end);
  if (result.code !== 0 || result.killed || result.truncated || first < 0 || middle < 0 || last < middle || result.stdout.indexOf(begin, first + 1) >= 0) throw new Error("transport_failed");
  const identity = result.stdout.slice(first + begin.length, middle).trimEnd().split("\n");
  const trailer = result.stdout.slice(last + end.length).match(/^(\d+)\n/);
  if (identity.length !== 3 || identity.some((v) => !v) || !trailer || result.stdout.indexOf(body, middle + 1) >= 0 || result.stdout.indexOf(end) !== last) throw new Error("transport_failed");
  return { kind: "command_executed", hostname: identity[0]!, cwd: identity[1]!, platform: identity[2]!, code: Number(trailer[1]),
    killed: false, truncated: false, stdout: result.stdout.slice(middle + body.length, last), stderr: result.stderr };
}

export async function execute(target: string, command: string, cwd: string, signal?: AbortSignal): Promise<Fact> {
  validateTarget(target);
  if (!command.trim() || command.includes("\0")) throw new Error("invalid_command");
  if (/(?:^|[;&|\n])\s*(?:(?:rtk\s+(?:proxy\s+)?)|(?:command\s+))?(?:\/usr\/bin\/)?(?:ssh|scp|sftp)(?:\s|$)/.test(command)) throw new Error("nested_ssh_refused: select the target with /gemma-target or --gemma-target");
  if (target === "local") {
    const physical = await realpath(cwd);
    return { kind: "command_executed", ...localIdentity(physical), ...await run("/bin/sh", ["-c", command], physical, "", signal) };
  }
  const nonce = randomBytes(16).toString("hex");
  return parseRemote(await run("/usr/bin/ssh", ["-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=10", "--", target, "/bin/sh", "-s"], cwd, remoteScript(command, nonce), signal), nonce);
}

export async function localPath(root: string, path: string, writing = false): Promise<string> {
  const base = await realpath(root), candidate = resolve(base, path);
  let found: string;
  if (writing) {
    const parent = await realpath(dirname(candidate));
    const info = await lstat(candidate).catch((e: NodeJS.ErrnoException) => { if (e.code !== "ENOENT") throw e; return null; });
    if (info?.isSymbolicLink()) throw new Error("symlink_refused");
    found = resolve(parent, candidate.slice(dirname(candidate).length + 1));
  } else found = await realpath(candidate);
  const rel = relative(base, found);
  if (rel === ".." || rel.startsWith("../") || isAbsolute(rel)) throw new Error("outside_workdir");
  return found;
}

export async function writeLocal(root: string, path: string, content: string, signal?: AbortSignal): Promise<string> {
  if (Buffer.byteLength(content) > 65536) throw new Error("file_too_large");
  const resolved = await localPath(root, path, true);
  const file = await open(resolved, constants.O_WRONLY | constants.O_CREAT | constants.O_NOFOLLOW | constants.O_NONBLOCK, 0o600);
  try {
    if (!(await file.stat()).isFile()) throw new Error("regular_file_required");
    if (signal?.aborted) throw new Error("aborted");
    await file.truncate(0);
    await file.writeFile(content, { signal });
  } finally { await file.close(); }
  return resolved;
}

export async function readLocal(root: string, path: string, signal?: AbortSignal): Promise<{ path: string; content: string }> {
  const resolved = await localPath(root, path);
  const file = await open(resolved, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  try {
    if (!(await file.stat()).isFile()) throw new Error("regular_file_required");
    const buffer = Buffer.alloc(65537);
    let used = 0;
    while (used < buffer.length) {
      if (signal?.aborted) throw new Error("aborted");
      const { bytesRead } = await file.read(buffer, used, buffer.length - used, used);
      if (!bytesRead) break;
      used += bytesRead;
    }
    if (used > 65536) throw new Error("file_too_large");
    return { path: resolved, content: buffer.subarray(0, used).toString() };
  } finally { await file.close(); }
}
