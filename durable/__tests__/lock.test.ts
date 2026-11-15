import { expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn, execFileSync } from "node:child_process";
import { writerLock } from "../src/lock.ts";

test("a second writer is refused and loss of the OS lock holder fails the writer", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-lock-"));
  const path = join(root, "daemon.lock");
  const child = spawn("node", [join(import.meta.dirname, "fixtures/lock-process.ts"), path], { stdio: ["ignore", "pipe", "ignore"] });
  try {
    await new Promise<void>((resolve) => child.stdout.once("data", () => resolve()));
    await expect(writerLock(path)).rejects.toThrow("already owns");
    const holder = Number(execFileSync("ps", ["--ppid", String(child.pid), "-o", "pid="], { encoding: "utf8" }).trim());
    const exited = new Promise<number | null>((resolve) => child.once("exit", resolve));
    process.kill(holder, "SIGKILL");
    expect(await exited).toBe(1);
    const release = await writerLock(path);
    await release();
  } finally { child.kill("SIGKILL"); await rm(root, { recursive: true, force: true }); }
});
