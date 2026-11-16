import { expect, test } from "bun:test";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { localRepo, until } from "./helpers.ts";
import { request } from "../src/cli.ts";
import type { Run } from "../src/runs-doc.ts";

for (const mode of ["schedule", "ci"]) test(`native SIGKILL ${mode} reservation and submission/ack boundaries preserve exactly one input`, async () => {
  const root = await mkdtemp(join(tmpdir(), `etabli-s6-${mode}-kills-`));
  const source = await localRepo(root);
  const state = join(root, "state");
  let child: ChildProcess | undefined;
  let now = Date.UTC(2026, 0, 1);
  const kill = async () => {
    const target = child!;
    const ended = new Promise<void>((resolve) => target.once("exit", () => resolve()));
    target.kill("SIGKILL"); await ended; child = undefined;
  };
  const start = async () => {
    child = spawn("node", [join(import.meta.dir, "fixtures/trigger-daemon.ts"), root, source, mode], { stdio: ["ignore", "ignore", "inherit"] });
    const pid = child.pid;
    await until(async () => await readFile(join(root, "ready"), "utf8").catch(() => "") === String(pid), 10_000);
  };
  try {
    await writeFile(join(root, "clock"), String(now));
    await start();
    let scheduleId = "";
    if (mode === "schedule") {
      const schedule = await request(state, { op: "schedule-create", repo: "Tonours/fixture", prompt: "exact scheduled input", cron: "* * * * *", requestId: "schedule-create" }) as { id: string };
      scheduleId = schedule.id;
    }
    now += mode === "schedule" ? 7 * 86_400_000 : 60_000; await writeFile(join(root, "clock"), String(now));
    const phases = mode === "schedule" ? ["before_occurrence", "after_occurrence", "before_run_ack", "after_run_ack"] : ["before_reservation", "after_reservation", "before_input", "after_input"];
    for (const stage of phases) {
      const pid = child!.pid;
      await until(async () => await readFile(join(root, "phase"), "utf8").catch(() => "") === `${stage}:${pid}`, 12_000);
      await kill();
      await writeFile(join(root, `released-${stage}`), "yes");
      await start();
      if (mode === "ci") { now += 60_000; await writeFile(join(root, "clock"), String(now)); }
    }
    await until(async () => (await request(state, { op: "ls" }) as Run[]).every((run) => ["done", "blocked"].includes(run.status)), 10_000);
    const runs = await request(state, { op: "ls" }) as Run[];
    expect(runs).toHaveLength(1);
    const shown = await request(state, { op: "show", id: runs[0].id }) as { entries: { kind: string }[] };
    expect(shown.entries.filter((entry) => entry.kind === "pi.user")).toHaveLength(mode === "schedule" ? 1 : 2);
    if (scheduleId) {
      await request(state, { op: "schedule-delete", id: scheduleId });
      now += 7 * 86_400_000; await writeFile(join(root, "clock"), String(now));
      await kill(); await start();
      expect(await request(state, { op: "ls" })).toHaveLength(1);
    }
  } finally { if (child) await kill(); await rm(root, { recursive: true, force: true }); }
}, 120_000);
