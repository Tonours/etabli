import { expect, test } from "bun:test";
import { randomUUID } from "node:crypto";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { SharedCredentialStore } from "../src/credentials.ts";
import { dispatch } from "../src/daemon.ts";
import { fixture } from "./helpers.ts";

test("credential-only marker never reaches SQLite, WAL, SHM, transcript or reports", async () => {
  const authRoot = await mkdtemp(join(tmpdir(), "durable-marker-"));
  const store = new SharedCredentialStore(join(authRoot, "auth.json"));
  const marker = `sk-test-${randomUUID()}`;
  await store.modify("fixture", async () => ({ type: "api_key", key: marker }));
  const f = await fixture({ credentials: store });
  let resolved = false;
  try {
    f.faux.provider.auth.apiKey!.resolve = async ({ credential }) => {
      resolved = credential?.key === marker;
      return { auth: { apiKey: credential?.key } };
    };
    f.faux.setResponses([fauxAssistantMessage("done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "credential-free fixture", "marker");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    await f.core.runs.tick();
    expect(resolved).toBe(true);
    expect(JSON.stringify(await dispatch(f.core, { op: "show", id: run.id }))).not.toContain(marker);
    const files = (await readdir(f.state)).filter((file) => file.startsWith("store.sqlite"));
    expect(files).toContain("store.sqlite");
    for (const file of files) expect((await readFile(join(f.state, file))).includes(Buffer.from(marker))).toBe(false);
  } finally { await f.cleanup(); await rm(authRoot, { recursive: true, force: true }); }
});
