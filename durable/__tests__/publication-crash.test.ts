import { expect, test } from "bun:test";
import { mkdtemp, readFile, writeFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn, type ChildProcess } from "node:child_process";
import { localRepo, until } from "./helpers.ts";
import { request } from "../src/cli.ts";
import type { Run } from "../src/runs-doc.ts";

for (const notification of ["before_notify", "after_notify"]) test(`SIGKILL publication at push/create/store/${notification} boundaries reconciles one PR`, async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-publication-kill-"));
  const source = await localRepo(root);
  const state = join(root, "state");
  let child: ChildProcess | undefined;
  const kill = async () => {
    const phase = (await readFile(join(root, "phase"), "utf8").catch(() => "")).split(":");
    const target = child!;
    const ended = new Promise<void>((resolve) => target.once("exit", () => resolve()));
    target.kill("SIGKILL"); await ended; child = undefined;
    if (Number(phase[1]) === target.pid && Number(phase[2]) > 0) { try { process.kill(Number(phase[2]), "SIGKILL"); } catch { } }
  };
  const start = async () => {
    child = spawn(process.execPath.endsWith("bun") ? "node" : process.execPath, [join(import.meta.dir, "fixtures/publication-daemon.ts"), root, source, notification], { stdio: ["ignore", "ignore", "inherit"] });
    const pid = child.pid;
    await until(async () => await readFile(join(root, "ready"), "utf8").catch(() => "") === String(pid), 10_000);
  };
  try {
    await start();
    const run = await request(state, { op: "run", repo: "Tonours/fixture", prompt: "publication crash fixture", requestId: "publish-crash" }) as Run;
    for (const phase of ["before_push", "after_push", "before_create", "after_create", "before_store", notification]) {
      const pid = child!.pid;
      await until(async () => (await readFile(join(root, "phase"), "utf8").catch(() => "")).startsWith(`${phase}:${pid}`), 10_000);
      await kill();
      await writeFile(join(root, `released-${phase}`), "yes");
      await start();
    }
    await until(async () => await stat(join(state, "final", `${run.id}.sqlite`)).then(() => true, () => false), 10_000);
    const shown = await request(state, { op: "show", id: run.id }) as { run: Run; entries: { kind: string; model?: { toolCallId?: string }[] }[] };
    expect(shown.run).toMatchObject({ status: "done", reason: "published", url: "https://github.com/Tonours/fixture/pull/1", notified: true });
    expect((await readFile(join(root, "create-effects"), "utf8")).trim().split("\n")).toHaveLength(1);
    expect((await readFile(join(root, "notify-called"), "utf8")).trim().split("\n")).toHaveLength(1);
    const effects = await readFile(join(root, "notify-effects"), "utf8").catch(() => "");
    expect(effects).toBe(notification === "after_notify" ? "once\n" : "");
    expect((await readFile(join(root, "notify-called"), "utf8"))).toContain(shown.run.url);
    const resultIds = shown.entries.filter((entry) => entry.kind === "pi.tool-result").map((entry) => entry.model?.[0]?.toolCallId);
    expect(new Set(resultIds).size).toBe(resultIds.length);
  } finally { if (child) await kill(); await rm(root, { recursive: true, force: true }); }
}, 150_000);
