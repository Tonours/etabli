import { expect, test } from "bun:test";
import { readdir, stat, copyFile, mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { createModels } from "@earendil-works/pi-ai";
import { backup } from "../src/backup.ts";
import { openCore } from "../src/daemon.ts";
import { fixture } from "./helpers.ts";

test("live WAL backups retain fourteen snapshots and restore the native run document", async () => {
  const f = await fixture();
  let restored: Awaited<ReturnType<typeof openCore>> | undefined;
  try {
    f.faux.setResponses([fauxAssistantMessage("done")]);
    await f.core.runs.submit("Tonours/fixture", "durable backup fixture", "backup");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    const unrelated = join(f.state, "backups", "unrelated.sqlite");
    await mkdir(join(f.state, "backups"));
    await writeFile(unrelated, "keep");
    const snapshots: string[] = [];
    for (let index = 0; index < 15; index++) snapshots.push(await backup(f.state, new Date(Date.UTC(2026, 0, index + 1))));
    const files = await readdir(join(f.state, "backups"));
    expect(files.length).toBe(15);
    expect(files).not.toContain(snapshots[0].split("/").at(-1)!);
    expect(files).toContain("unrelated.sqlite");
    expect((await stat(snapshots[14])).mode & 0o777).toBe(0o600);
    const state = join(f.root, "restored");
    await mkdir(state, { mode: 0o700 });
    await copyFile(snapshots[14], join(state, "store.sqlite"));
    const original = await f.core.runs.list();
    restored = await openCore({ state, policy: f.policy, models: createModels() });
    expect(await restored.runs.list()).toEqual(original);
  } finally { await restored?.close(); await f.cleanup(); }
});
