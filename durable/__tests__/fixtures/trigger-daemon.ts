import { readFile, writeFile, stat } from "node:fs/promises";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { createModels } from "@earendil-works/pi-ai";
import { fauxProvider, fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import type { Tx } from "@earendil-works/pi-durable";
import { openCore, serve } from "../../src/daemon.ts";
import { OwnerPolicy } from "../../src/policy.ts";
import { Repositories } from "../../src/repositories.ts";
import { RunsDoc } from "../../src/runs-doc.ts";
import { SchedulesDoc } from "../../src/schedule.ts";
import { CiDoc } from "../../src/ci-doc.ts";
import { PublishDoc } from "../../src/publish.ts";
import { git } from "../../src/change.ts";

const [root, source, mode] = process.argv.slice(2);
const state = join(root, "state");
const now = () => Number(readFileSync(join(root, "clock"), "utf8"));
const barrier = async (stage: string) => {
  if (await stat(join(root, `released-${stage}`)).then(() => true, () => false)) return;
  await writeFile(join(root, "phase"), `${stage}:${process.pid}`);
  while (!await stat(join(root, `released-${stage}`)).then(() => true, () => false)) await new Promise((resolve) => setTimeout(resolve, 10));
};
const policy = new OwnerPolicy(["ForeignOrg"]);
const faux = fauxProvider({ provider: "fixture", models: [{ id: "fixture" }] });
faux.setResponses(Array.from({ length: 40 }, () => fauxAssistantMessage("fixture completed")));
const models = createModels(); models.setProvider(faux.provider);
const core = await openCore({ state, policy, models, now, model: async () => ({ provider: "fixture", modelId: "fixture" }), repositories: new Repositories(state, policy, () => source, async (repo) => repo), ciCommand: async (_cwd, program, args) => {
  if (program !== "gh" || args[0] !== "pr" || args[1] !== "view") throw new Error("Only read-only gh pr view allowed");
  return readFile(join(root, "pull.json"), "utf8");
} });
if (mode === "ci" && !(await core.runs.list()).length) {
  const run = await core.runs.submit("Tonours/fixture", "original native conversation", "initial");
  await core.runs.tick(); await core.harness.waitForIdle(context); await core.runs.tick();
  const head = await git(run.worktree, ["rev-parse", "HEAD"]);
  const url = "https://github.com/Tonours/fixture/pull/1";
  await core.harness.commit(async (tx) => {
    const stored = (await tx.doc(RunsDoc)).runs[0];
    stored.route = "answer"; stored.status = "done"; stored.reason = "published"; stored.url = url; stored.notified = true;
    Object.assign(await tx.doc(PublishDoc, run.conversationId), { head, base: "main", title: "fixture", body: "fixture", sourceHash: "fixture" });
    (await tx.doc(CiDoc)).runs.push({ runId: run.id, url, head, originalStartedAt: stored.startedAt, nextPollAt: 0, backoff: 60_000, retired: "", attempts: [] });
  }, context);
  await writeFile(join(root, "pull.json"), JSON.stringify({ url, headRefOid: head, headRefName: run.branch, state: "OPEN", headRepositoryOwner: { login: "Tonours" }, statusCheckRollup: [{ name: "native fixture", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: "https://example.invalid/check" }] }));
}
const commit = core.harness.commit.bind(core.harness);
core.harness.commit = (async (fn: (tx: Tx) => Promise<unknown>, ctx: typeof context) => {
  const beforeSchedule = (await core.harness.snapshot(SchedulesDoc, context))?.schedules[0]?.occurrence?.status;
  const beforeCi = (await core.harness.snapshot(CiDoc, context))?.runs[0]?.attempts.at(-1)?.state;
  let phase = "";
  const result = await commit(async (tx) => {
    const result = await fn(tx);
    const afterSchedule = (await tx.doc(SchedulesDoc)).schedules[0]?.occurrence?.status;
    const afterCi = (await tx.doc(CiDoc)).runs[0]?.attempts.at(-1)?.state;
    if (!beforeSchedule && afterSchedule === "pending") phase = "occurrence";
    if (beforeSchedule === "pending" && afterSchedule === "acknowledged") phase = "run_ack";
    if (!beforeCi && afterCi === "reserved") phase = "reservation";
    if (beforeCi === "reserved" && afterCi === "submitted") phase = "input";
    if (phase) await barrier(`before_${phase}`);
    return result;
  }, ctx);
  if (phase) await barrier(`after_${phase}`);
  return result;
}) as typeof core.harness.commit;
await serve(core, state);
await writeFile(join(root, "ready"), String(process.pid));
let ticking = false;
setInterval(() => {
  if (ticking) return;
  ticking = true;
  void (async () => {
    if (mode === "schedule") await core.schedules.tick(); else await core.ci.tick();
    await core.runs.tick();
  })().catch(() => process.exit(1)).finally(() => { ticking = false; });
}, 20);
