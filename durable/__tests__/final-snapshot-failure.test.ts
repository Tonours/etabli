import { expect, test } from "bun:test";
import { mkdir, stat, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { fixture } from "./helpers.ts";

test("an unavailable archive CLI cannot reject the daemon tick and retries after recovery", async () => {
  const f = await fixture({ workflow: true });
  const originalPath = process.env.PATH;
  try {
    f.faux.setResponses([fauxAssistantMessage("fixture stops")]);
    const run = await f.core.runs.submit("Tonours/fixture", "snapshot failure fixture", "snapshot-failure");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    const bin = join(f.root, "broken-bin");
    await mkdir(bin);
    await writeFile(join(bin, "sqlite3"), "#!/bin/sh\nexit 1\n", { mode: 0o700 });
    process.env.PATH = `${bin}:${originalPath}`;
    await expect(f.core.runs.tick()).resolves.toBeUndefined();
    process.env.PATH = originalPath;
    await f.core.runs.tick();
    expect((await stat(join(f.state, "final", `${run.id}.sqlite`))).mode & 0o777).toBe(0o400);
  } finally { process.env.PATH = originalPath; await f.cleanup(); }
});
