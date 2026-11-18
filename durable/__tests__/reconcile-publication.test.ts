import { expect, test } from "bun:test";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fixture } from "./helpers.ts";
import { PublishDoc, reconcilePublication, type Command } from "../src/publish.ts";
import { RunsDoc } from "../src/runs-doc.ts";

for (const outcome of ["found", "absent", "unavailable", "wrong_head"]) test(`terminal publication lookup is read-only and durable once: ${outcome}`, async () => {
  let lookups = 0;
  const command: Command = async (_cwd, program, args) => {
    expect(program).toBe("gh");
    expect(args.slice(0, 2)).toEqual(["pr", "list"]);
    lookups++;
    if (outcome === "unavailable") throw new Error("service unavailable");
    return JSON.stringify(outcome === "absent" ? [] : [{ url: "https://github.com/Tonours/fixture/pull/1", headRefOid: outcome === "wrong_head" ? "wrong" : "head", baseRefName: "main", state: "OPEN", headRepositoryOwner: { login: "Tonours" } }]);
  };
  const f = await fixture({ workflow: true, publishCommand: command });
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "terminal reconcile", `reconcile-${outcome}`);
    await f.core.harness.commit(async (tx) => {
      const row = (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!;
      row.status = "blocked"; row.reason = "wall_clock_limit";
      Object.assign(await tx.doc(PublishDoc, run.conversationId), { title: "fixture", body: "fixture", head: "head", base: "main", sourceHash: "source" });
    }, context);
    await reconcilePublication(f.core.harness, await f.core.runs.show(run.id), f.policy, context, command);
    expect((await f.core.runs.show(run.id)).url).toBe(outcome === "found" ? "https://github.com/Tonours/fixture/pull/1" : "");
    expect((await f.core.harness.snapshot(PublishDoc, run.conversationId, context))?.reconcileError).toBe(["unavailable", "wrong_head"].includes(outcome) ? "lookup_failed" : "");
    await f.reopen(); await f.core.runs.tick(); await f.core.runs.tick();
    expect(lookups).toBe(1);
    expect(await f.core.runs.show(run.id)).toMatchObject({ status: "blocked", reason: "wall_clock_limit", notified: true });
    expect((await f.core.harness.snapshot(PublishDoc, run.conversationId, context))?.reconciled).toBe(true);
  } finally { await f.cleanup(); }
});
