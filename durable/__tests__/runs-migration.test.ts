import { expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createModels } from "@earendil-works/pi-ai";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { createRegistry, defineDoc, Harness, type JsonObject } from "@earendil-works/pi-durable";
import { openNodeSqliteStorage } from "@earendil-works/pi-durable/storage/sqlite/node";
import { RunsDoc } from "../src/runs-doc.ts";

const LegacyRuns = defineDoc<{ runs: JsonObject[] }>({ kind: "etabli.runs", version: 1, scope: "session", initial: () => ({ runs: [] }), checkpointWhen: () => true });

test("native store v1 migration preserves terminal rows and gives busy work its phase", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-migration-"));
  const open = async () => Harness.open(await openNodeSqliteStorage(join(root, "store.sqlite")), { models: createModels(), registry: createRegistry() }, context);
  let harness = await open();
  try {
    await harness.commit(async (tx) => {
      const conversation = await tx.createConversation({ ownership: { kind: "ownerless" } });
      (await tx.doc(LegacyRuns)).runs = ["busy", "done", "blocked", "aborted"].map((status) => ({ id: status, requestId: status, repo: "Tonours/fixture", prompt: "legacy", conversationId: conversation.id, branch: "feat/legacy", worktree: root, status, reason: "old", url: "", createdAt: 1, startedAt: 1, deadline: 100, maxTurns: 64, submissionId: "", notified: status !== "busy" }));
    }, context);
    await harness.close(context);
    harness = await open();
    const migrated = (await harness.snapshot(RunsDoc, context))!;
    expect(migrated.runs.map((run) => run.status)).toEqual(["implementing", "done", "blocked", "aborted"]);
    expect(migrated.runs.every((run) => run.route === "legacy")).toBe(true);
    expect(migrated.runs.slice(1).every((run) => run.notified)).toBe(true);
    await harness.commit(async (tx) => { (await tx.doc(RunsDoc)).runs[0].reason = "migrated"; }, context);
    await harness.close(context);
    harness = await open();
    expect((await harness.snapshot(RunsDoc, context))?.runs[0].reason).toBe("migrated");
  } finally { await harness.close(context); await rm(root, { recursive: true, force: true }); }
});

test("migration refuses unknown v1 state rather than publishing an invented run", () => {
  expect(() => RunsDoc.definition.migrate?.({ runs: [{ status: "unknown" }] }, 1)).toThrow("Invalid legacy");
  expect(() => RunsDoc.definition.migrate?.({ runs: [] }, 0)).toThrow("Unsupported");
});
