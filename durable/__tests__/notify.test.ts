import { expect, test } from "bun:test";
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fixture } from "./helpers.ts";

test("terminal notification is argv-only and claimed once across reopen", async () => {
  const f = await fixture();
  try {
    const log = join(f.root, "notifications");
    const script = join(f.root, "notify.js");
    await writeFile(script, "require('node:fs').appendFileSync(process.argv[2], JSON.stringify(process.argv.slice(3)) + '\\n');\n");
    Object.assign(f.core.runs, { notifyArgv: ["node", script, log] });
    f.faux.setResponses([fauxAssistantMessage("done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "notification; $(false)", "notify");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    await f.core.runs.tick();
    await f.reopen();
    expect((await readFile(log, "utf8")).trim().split("\n").map((line) => JSON.parse(line))).toEqual([[run.id, "done", "answer", ""]]);
  } finally { await f.cleanup(); }
});
