import { expect, test } from "bun:test";
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn, type ChildProcess } from "node:child_process";
import { localRepo, until } from "./helpers.ts";
import { request } from "../src/cli.ts";
import type { Run } from "../src/runs-doc.ts";
import type { PlanState } from "../src/plan-doc.ts";

test("SIGKILL interrupts an unsafe review without persisting partial BLOCK receipts or consuming a round", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-review-kill-"));
  const source = await localRepo(root);
  const state = join(root, "state");
  let child: ChildProcess | undefined;
  const kill = async () => { const target = child!; const ended = new Promise<void>((resolve) => target.once("exit", () => resolve())); target.kill("SIGKILL"); await ended; child = undefined; };
  const start = async () => {
    child = spawn("node", [join(import.meta.dir, "fixtures/review-daemon.ts"), root, source], { stdio: ["ignore", "ignore", "inherit"] });
    const pid = child.pid;
    await until(async () => await readFile(join(root, "ready"), "utf8").catch(() => "") === String(pid), 10_000);
  };
  try {
    await start();
    const run = await request(state, { op: "run", repo: "Tonours/fixture", prompt: "interrupted review fixture", requestId: "review-crash" }) as Run;
    await until(async () => await readFile(join(root, "review-pending"), "utf8").catch(() => "") === String(child!.pid), 10_000);
    expect(((await request(state, { op: "plan", id: run.id }) as PlanState | undefined)?.reviews ?? [])).toEqual([]);
    await kill();
    await writeFile(join(root, "released-review"), "yes");
    await start();
    await until(async () => await readFile(join(root, "after-restart"), "utf8").catch(() => "") === String(child!.pid), 10_000);
    expect(((await request(state, { op: "plan", id: run.id }) as PlanState | undefined)?.reviews ?? [])).toEqual([]);
    const interrupted = await request(state, { op: "show", id: run.id }) as { entries: { kind: string }[] };
    expect(interrupted.entries.filter((entry) => entry.kind === "pi.tool-result" && JSON.stringify(entry).includes('"code":"interrupted"'))).toHaveLength(1);
    await writeFile(join(root, "resume-parent"), "yes");
    await until(async () => (await request(state, { op: "show", id: run.id }) as { run: Run }).run.status === "blocked", 10_000);
    const plan = await request(state, { op: "plan", id: run.id }) as PlanState;
    expect(plan.reviews).toHaveLength(12);
    expect(new Set(plan.reviews.map((receipt) => receipt.round)).size).toBe(3);
    expect((await request(state, { op: "show", id: run.id }) as { run: Run }).run.reason).toBe("review_block_limit");
  } finally { if (child) await kill(); await rm(root, { recursive: true, force: true }); }
}, 90_000);
