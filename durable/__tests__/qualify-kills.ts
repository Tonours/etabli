import { mkdtemp, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { spawn, execFileSync, type ChildProcess } from "node:child_process";
import { request } from "../src/cli.ts";
import { localRepo, until } from "./helpers.ts";
import type { Run } from "../src/runs.ts";

type Shown = { run: Run; entries: { kind: string; model?: { toolCallId?: string }[]; data?: { diagnostics?: { code: string }[] } }[] };

export async function qualifyKills(cuts = 10): Promise<{ cuts: number; midTool: number; midGeneration: number; completed: number; interrupted: number }> {
  const root = await mkdtemp(join(tmpdir(), "durable-kills-"));
  const source = await localRepo(root);
  const state = join(root, "state");
  let child: ChildProcess | undefined;
  let midTool = 0;
  let midGeneration = 0;
  const start = async () => {
    child = spawn("node", [join(import.meta.dirname, "fixtures/crash-daemon.ts"), root, source], { stdio: ["ignore", "ignore", "ignore"] });
    const pid = child.pid!;
    await until(async () => await readFile(join(root, "ready"), "utf8").catch(() => "") === String(pid), 15_000);
  };
  const kill = async () => {
    const target = child!;
    const phase = await readFile(join(root, "phase"), "utf8").catch(() => "");
    const ended = new Promise<void>((resolve) => target.once("exit", () => resolve()));
    target.kill("SIGKILL");
    if (phase.startsWith(`tool:${target.pid}:`)) {
      const toolPid = Number(phase.split(":")[2]);
      try { process.kill(-toolPid, "SIGKILL"); } catch {}
    }
    await ended;
    child = undefined;
  };
  try {
    await start();
    const run = await request(state, { op: "run", repo: "Tonours/fixture", prompt: "unsafe crash fixture", requestId: "crash-once" }) as Run;
    for (let index = 0; index < cuts; index++) {
      const phase = index < 6 && index % 2 === 0 ? "tool" : "generation";
      const pid = child!.pid!;
      await until(async () => (await readFile(join(root, "phase"), "utf8").catch(() => "")).startsWith(`${phase}:${pid}`), 20_000);
      if (phase === "tool") midTool++; else midGeneration++;
      await kill();
      await start();
    }
    await until(async () => (await request(state, { op: "show", id: run.id }) as Shown).run.status === "done", 30_000);
    const shown = await request(state, { op: "show", id: run.id }) as Shown;
    const results = shown.entries.filter((entry) => entry.kind === "pi.tool-result");
    const ids = results.map((entry) => entry.model?.[0]?.toolCallId);
    if (new Set(ids).size !== ids.length) throw new Error("Duplicated completed tool result");
    const interrupted = results.filter((entry) => JSON.stringify(entry).includes('"code":"interrupted"')).length;
    if (interrupted < midTool) throw new Error("Cut-off unsafe tool lacks an interrupted result");
    const effects = (await readFile(join(run.worktree, "unsafe-effects"), "utf8")).trim().split("\n");
    if (new Set(effects).size !== effects.length) throw new Error("Interrupted unsafe invocation was automatically replayed");
    if (await readFile(join(run.worktree, "result.txt"), "utf8") !== "finished\n") throw new Error("Recovered run did not complete its fixture check");
    if (execFileSync("git", ["-C", run.worktree, "log", "-1", "--format=%s"], { encoding: "utf8" }).trim() !== "test: finish durable fixture") throw new Error("Recovered run did not commit its completed work");
    return { cuts, midTool, midGeneration, completed: results.length - interrupted, interrupted };
  } finally {
    if (child) await kill();
    await rm(root, { recursive: true, force: true });
  }
}

if (import.meta.main) console.log(JSON.stringify(await qualifyKills(10)));
