import { expect, test } from "bun:test";
import { readFile, stat, copyFile, mkdir, chmod } from "node:fs/promises";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { LiveDoc, AgentDoc, InboxDoc } from "@earendil-works/pi-durable";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { CiDoc } from "../src/ci-doc.ts";
import { RunsDoc } from "../src/runs-doc.ts";
import { PublishDoc } from "../src/publish.ts";
import { EtabliPlanDoc } from "../src/plan-doc.ts";
import { ciFixture } from "./fixtures/ci-fixture.ts";
import { openCore } from "../src/daemon.ts";
import { createModels } from "@earendil-works/pi-ai";

const digest = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex");
test("two red CI fixes reuse the native conversation, refresh reviews/caps/notifications and preserve every immutable terminal archive", async () => {
  let now = Date.now();
  const notifyArgv: string[] = [];
  const f = await ciFixture({ now: () => now, wallMs: 20_000, maxTurns: 4, notifyArgv });
  notifyArgv.push("node", "-e", "require('node:fs').appendFileSync(process.argv[1],process.argv.slice(2).join('|')+'\\n')", join(f.root, "notifications"));
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "publish fixture", "ci-parent");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    expect(await f.core.runs.show(run.id)).toMatchObject({ status: "done", reason: "published", notified: true });
    const initial = join(f.state, "final", `${run.id}.sqlite`);
    const hash = digest(await readFile(initial));
    const oldSubmission = (await f.core.runs.show(run.id)).submissionId;
    const oldDeadline = (await f.core.runs.show(run.id)).deadline;
    now += 30_000;
    await f.core.ci.tick();
    let resumed = await f.core.runs.show(run.id);
    expect(resumed).toMatchObject({ status: "implementing", conversationId: run.conversationId, notified: false, startedAt: now, deadline: now + 20_000 });
    expect(resumed.deadline).toBeGreaterThan(oldDeadline);
    expect(resumed.submissionId).not.toBe(oldSubmission);
    expect((await f.core.harness.snapshot(AgentDoc, run.conversationId, context))?.maxTurns).toBe(4);
    expect((await f.core.harness.snapshot(LiveDoc, run.conversationId, context))?.run?.turns).toBe(0);
    expect((await f.core.harness.snapshot(PublishDoc, run.conversationId, context))?.head).toBe("");
    expect((await f.core.harness.snapshot(EtabliPlanDoc, run.conversationId, context))?.reviews.filter((review) => review.kind === "code")).toEqual([]);
    await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    expect((await f.core.runs.show(run.id)).status).toBe("done");
    const first = join(f.state, "final", `${run.id}.ci-1.sqlite`);
    const firstHash = digest(await readFile(first));
    await f.reopen(); now += 60_000;
    await f.core.ci.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    expect((await f.core.runs.show(run.id)).status).toBe("done");
    expect((await stat(join(f.state, "final", `${run.id}.ci-2.sqlite`))).mode & 0o777).toBe(0o400);
    now += 60_000; await f.core.ci.tick(); await f.core.runs.tick();
    expect(await f.core.runs.show(run.id)).toMatchObject({ status: "blocked", reason: "ci_attempts_exhausted", notified: true });
    expect((await stat(join(f.state, "final", `${run.id}.ci-exhausted.sqlite`))).mode & 0o777).toBe(0o400);
    expect(digest(await readFile(initial))).toBe(hash); expect(digest(await readFile(first))).toBe(firstHash);
    for (const [file, count, status] of [[initial, 0, "done"], [first, 1, "done"], [join(f.state, "final", `${run.id}.ci-exhausted.sqlite`), 2, "blocked"]] as const) {
      const state = join(f.root, `restore-${count}-${status}`);
      await mkdir(state); await copyFile(file, join(state, "store.sqlite")); await chmod(join(state, "store.sqlite"), 0o600);
      const restored = await openCore({ state, policy: f.policy, models: createModels() });
      try {
        expect((await restored.runs.show(run.id)).status).toBe(status);
        expect((await restored.harness.snapshot(CiDoc, context))!.runs[0].attempts.filter((attempt) => attempt.state === "submitted")).toHaveLength(count);
      } finally { await restored.close(); }
    }
    expect(f.counts.creates).toBe(1); expect(f.counts.pushes).toBe(3);
    const conversation = await f.core.harness.conversation(run.conversationId, context);
    const entries = (await conversation!.entries({ order: "ascending" }, 1000, undefined, context)).items;
    expect(entries.filter((entry) => entry.kind === "pi.user" && JSON.stringify(entry).includes("CI remediation attempt"))).toHaveLength(2);
    const ci = (await f.core.harness.snapshot(CiDoc, context))!.runs[0];
    expect(ci.attempts.map((attempt) => attempt.state)).toEqual(["submitted", "submitted"]);
    expect(ci.originalStartedAt).toBeLessThan(now);
    expect((await readFile(join(f.root, "notifications"), "utf8")).trim().split("\n")).toHaveLength(4);
    expect((await f.core.runs.list()).filter((row) => row.id === run.id)).toHaveLength(1);
    await f.reopen(); await f.core.ci.tick();
    expect((await f.core.harness.snapshot(CiDoc, context))!.runs[0].attempts).toHaveLength(2);
  } finally { await f.cleanup(); }
}, 30_000);

test("foreign or pre-S6 recorded terminal PRs and unowned repository PRs never trigger work", async () => {
  const f = await ciFixture();
  try {
    const old = await f.core.runs.submit("Tonours/fixture", "old fixture", "old");
    await f.core.harness.commit(async (tx) => { const run = (await tx.doc(RunsDoc)).runs[0]; run.status = "done"; run.reason = "published"; run.url = "https://github.com/Tonours/fixture/pull/99"; run.notified = true; }, context);
    await f.core.ci.tick(); expect(f.counts.polls).toBe(0);
    const owned = await f.core.runs.submit("Tonours/fixture", "new fixture", "new");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    f.pull!.headRepositoryOwner.login = "Foreign";
    await f.core.ci.tick();
    expect((await f.core.harness.snapshot(CiDoc, context))!.runs[0]).toMatchObject({ retired: "foreign", attempts: [] });
    expect((await f.core.runs.show(owned.id)).status).toBe("done");
    expect((await f.core.runs.show(old.id)).conversationId).toBe(old.conversationId);
    expect(f.counts.creates).toBe(1);
  } finally { await f.cleanup(); }
}, 20_000);

test("pending/unknown checks poll at most once a minute across restart; retired green never submits", async () => {
  let now = Date.now();
  const f = await ciFixture({ now: () => now });
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "poll fixture", "poll");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    f.pull!.statusCheckRollup = [{ __typename: "CheckRun", name: "check", status: "IN_PROGRESS", conclusion: null }];
    const baseline = f.counts.polls;
    for (let i = 0; i < 10; i++) await f.core.ci.tick();
    expect(f.counts.polls - baseline).toBe(1);
    await f.reopen(); await f.core.ci.tick(); expect(f.counts.polls - baseline).toBe(1);
    now += 60_000; f.pull!.statusCheckRollup = [{ __typename: "CheckRun", name: "check", status: "COMPLETED", conclusion: "CANCELLED" }];
    await f.core.ci.tick(); expect(f.counts.polls - baseline).toBe(2);
    now += 60_000; f.pull!.statusCheckRollup = [{ __typename: "CheckRun", name: "check", status: "COMPLETED", conclusion: "SUCCESS" }];
    await f.core.ci.tick(); now += 60_000; await f.core.ci.tick();
    expect((await f.core.harness.snapshot(CiDoc, context))!.runs[0]).toMatchObject({ retired: "green", attempts: [] });
    expect((await f.core.runs.show(run.id)).status).toBe("done");
  } finally { await f.cleanup(); }
}, 20_000);

test("reserved attempts wait for native capacity/idle, retain exact input and cancel obsolete work without spending a submitted attempt", async () => {
  let now = Date.now();
  const f = await ciFixture({ now: () => now });
  let release = () => {};
  let gate = new Promise<void>((resolve) => { release = resolve; });
  try {
    const target = await f.core.runs.submit("Tonours/fixture", "capacity fixture", "capacity");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    f.faux.setResponses(Array.from({ length: 12 }, () => async (_input: unknown, options: { signal?: AbortSignal } | undefined) => {
      await Promise.race([gate, new Promise<void>((resolve) => options?.signal?.addEventListener("abort", () => resolve(), { once: true }))]);
      return fauxAssistantMessage("done");
    }));
    await f.core.runs.submit("Tonours/fixture", "busy one", "one");
    await f.core.runs.submit("Tonours/fixture", "busy two", "two");
    await f.core.runs.tick(); await f.core.ci.tick();
    let row = (await f.core.harness.snapshot(CiDoc, context))!.runs[0];
    expect(row.attempts.map((attempt) => attempt.state)).toEqual(["reserved"]);
    expect((await f.core.runs.show(target.id)).status).toBe("done");
    expect((await f.core.runs.list()).filter((run) => run.status === "implementing")).toHaveLength(2);
    const exact = row.attempts[0].input;
    f.pull!.statusCheckRollup = [{ name: "different untrusted check", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: "https://example.invalid/changed" }];
    release(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    gate = new Promise<void>((resolve) => { release = resolve; });
    const conversation = await f.core.harness.conversation(target.conversationId, context);
    await conversation!.submit({ type: "input", content: "native busy neighbor", requestId: "neighbor" }, context);
    now += 60_000; await f.core.ci.tick();
    expect((await f.core.runs.show(target.id)).status).toBe("done");
    expect((await f.core.harness.snapshot(CiDoc, context))!.runs[0].attempts[0].state).toBe("reserved");
    release(); await f.core.harness.waitForIdle(context);
    now += 60_000; await f.core.ci.tick();
    row = (await f.core.harness.snapshot(CiDoc, context))!.runs[0];
    expect(row.attempts[0]).toMatchObject({ state: "submitted", input: exact });
    const entries = (await conversation!.entries({ order: "ascending" }, 1000, undefined, context)).items;
    expect(JSON.stringify(entries)).toContain(exact.replaceAll('"', '\\"').split("\n")[0]);
    await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    expect((await f.core.runs.show(target.id)).status).toBe("blocked");
    const before = f.counts.polls; now += 60_000; await f.core.ci.tick(); expect(f.counts.polls).toBe(before);
  } finally { release(); await f.cleanup(); }
}, 20_000);

test("a stale reserved head cancels once and refunds the two-submission budget", async () => {
  let now = Date.now();
  const f = await ciFixture({ now: () => now });
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "cancel fixture", "cancel");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    await f.core.harness.commit(async (tx) => {
      const ci = (await tx.doc(CiDoc)).runs[0];
      ci.attempts.push({ number: 1, triggerHead: ci.head, checks: [], input: "reserved exact content", requestId: `ci:${run.id}:1`, state: "reserved" });
    }, context);
    f.pull!.headRefOid = "foreign-head";
    await f.core.ci.tick();
    expect((await f.core.harness.snapshot(CiDoc, context))!.runs[0]).toMatchObject({ retired: "foreign", attempts: [{ number: 1, state: "cancelled" }] });
    expect((await f.core.runs.show(run.id)).status).toBe("done");
    const polls = f.counts.polls; now += 60_000; await f.reopen(); await f.core.ci.tick(); expect(f.counts.polls).toBe(polls);
  } finally { await f.cleanup(); }
}, 20_000);

test("a CI attempt keeps native hard turn limits and a blocked attempt never reactivates", async () => {
  const f = await ciFixture();
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "turn cap fixture", "ci-cap");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    Object.assign(f.core.runs, { maxTurns: 1 });
    await f.core.ci.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    expect(await f.core.runs.show(run.id)).toMatchObject({ status: "blocked", reason: "turn_limit", maxTurns: 1, notified: true });
    const row = (await f.core.harness.snapshot(CiDoc, context))!.runs[0];
    expect(row.attempts.filter((attempt) => attempt.state === "submitted")).toHaveLength(1);
    const polls = f.counts.polls; await f.core.ci.tick(); await f.reopen(); await f.core.ci.tick();
    expect(f.counts.polls).toBe(polls);
  } finally { await f.cleanup(); }
}, 20_000);
