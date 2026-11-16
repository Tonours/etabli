import { expect, spyOn, test } from "bun:test";
import { readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { PUSH_LIMITS, Push, PushDoc, sendPush, type PushAdmission, type PushSummary } from "../src/push.ts";
import { Runs } from "../src/runs.ts";
import { RunsDoc } from "../src/runs-doc.ts";
import { openCore } from "../src/daemon.ts";
import { fixture, until } from "./helpers.ts";
import { acceptedPush, localPushSend, pushPeer } from "./fixtures/push-peer.ts";

const identity = "owner@example.invalid", origin = "https://app.fixture.ts.net";
const endpoint = "https://fcm.googleapis.com/fcm/send/admission-fixture";

test("all simultaneous notify calls share two native HTTPS requests", async () => {
  const f = await fixture(), peer = await pushPeer(f.root);
  const real = await Push.open(f.core.harness, f.state, origin, [identity]);
  const push = new Push(f.core.harness, real.key, origin, [identity], localPushSend(peer));
  let pending: Promise<PushSummary>[] = [];
  try {
    await push.subscribe(identity, endpoint); await push.subscribe(identity, `${endpoint}-second`);
    peer.answer(() => undefined);
    const attempts = Array.from({ length: 6 }, () => push.notify());
    pending = attempts.filter((attempt) => attempt.kind === "accepted").map(acceptedPush);
    expect(attempts.map((attempt) => attempt.kind)).toEqual(["accepted", "accepted", "coalesced", "coalesced", "coalesced", "coalesced"]);
    await until(async () => peer.live >= 2);
    await new Promise((resolve) => setTimeout(resolve, 100));
    expect(peer.peak).toBeLessThanOrEqual(2);
    expect(peer.peakClients).toBeLessThanOrEqual(2);
    expect(attempts[2]).toBe(attempts[5]);
    expect(peer.received.every((record) => record.connection === "close")).toBe(true);
    peer.release();
    expect(await Promise.all(pending)).toMatchObject([{ attempted: 2, providerAccepted: 2, coalesced: 0 }, { attempted: 2, providerAccepted: 2, coalesced: 4 }]);
    expect(peer.received).toHaveLength(4);
    expect(peer.peakClients).toBeLessThanOrEqual(2); expect(peer.clients).toBe(0);
    expect(peer.received.every((record) => record.connection === "close" && record.ttl === "3600" && record.urgency === "high" && record.bytes === 0)).toBe(true);
  } finally { const closing = push.close(); peer.release(); await peer.close(); await closing; await real.close(); await f.cleanup(); }
});

test("normal 64-target fanout and rejected/transient providers keep the native request cap", async () => {
  const f = await fixture(), peer = await pushPeer(f.root), real = await Push.open(f.core.harness, f.state, origin, [identity]);
  const push = new Push(f.core.harness, real.key, origin, [identity], localPushSend(peer));
  try {
    for (let i = 0; i < 64; i++) await push.subscribe(identity, `${endpoint}-${i}`);
    const normal = await acceptedPush(push.notify());
    expect(normal).toMatchObject({ outcome: "complete", attempted: 64, providerAccepted: 64, failed: 0, unattempted: 0 });
    expect(peer.peak).toBeLessThanOrEqual(2);
    expect(peer.peakClients).toBeLessThanOrEqual(2); expect(peer.clients).toBe(0);
    peer.answer((ordinal) => ordinal === 65 ? 410 : 503);
    expect(await acceptedPush(push.notify())).toMatchObject({ attempted: 64, providerAccepted: 0, failed: 64 });
    expect((await f.core.harness.snapshot(PushDoc, context))?.subscriptions).toHaveLength(63);
    peer.release();
    expect(await acceptedPush(push.notify())).toMatchObject({ attempted: 63, providerAccepted: 63, failed: 0 });
  } finally { await push.close(); await real.close(); await peer.close(); await f.cleanup(); }
});

test("a queued attempt expires without late dispatch while the real SDK mutation line is held", async () => {
  const f = await fixture(), peer = await pushPeer(f.root);
  const initial = await Push.open(f.core.harness, f.state, origin, [identity]);
  await initial.subscribe(identity, endpoint); await initial.close(); await f.reopen();
  const real = await Push.open(f.core.harness, f.state, origin, [identity]);
  const push = new Push(f.core.harness, real.key, origin, [identity], localPushSend(peer), { executionMs: 40, waitMs: 100 });
  let release!: () => void, entered!: () => void, closing: Promise<void> | undefined;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  const started = new Promise<void>((resolve) => { entered = resolve; });
  const held = f.core.harness.commit(async (tx) => { await tx.doc(RunsDoc); entered(); await gate; }, context);
  try {
    await started;
    const active = acceptedPush(push.notify()), waiting = acceptedPush(push.notify());
    expect(push.notify().kind).toBe("coalesced");
    let expired: PushSummary | undefined; void waiting.then((result) => { expired = result; });
    await until(async () => expired !== undefined, 1_000);
    expect(expired).toMatchObject({ outcome: "wait_expired", attempted: 0, providerAccepted: 0, coalesced: 1 });
    const next = acceptedPush(push.notify());
    closing = push.close(); let closed = false; void closing.then(() => { closed = true; });
    expect(await next).toMatchObject({ outcome: "closed", attempted: 0 });
    expect(push.notify()).toEqual({ kind: "skipped", reason: "closed" });
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(closed).toBe(false); expect(peer.received).toHaveLength(0);
    release(); await held;
    expect(await active).toMatchObject({ outcome: "execution_expired", attempted: 0, unattempted: 1 });
    await closing; expect(push.close()).toBe(closing); expect(peer.received).toHaveLength(0);
  } finally { release(); await held; await push.close(); await real.close(); await peer.close(); await f.cleanup(); }
});

test("a slow active request reaches its budget before the waiter starts, with real core shutdown draining native work", async () => {
  let now = Date.now();
  const f = await fixture({ web: { origin, identities: [identity] }, now: () => now, wallMs: 50_000 }), peer = await pushPeer(f.root);
  const push = f.core.push!, attempts: PushAdmission[] = [], notify = push.notify.bind(push);
  Object.assign(push, { send: localPushSend(peer), notify: () => { const admission = notify(); attempts.push(admission); return admission; } });
  peer.answer(() => undefined);
  let closing: Promise<void> | undefined, harnessClosed = false, coreClosed = false;
  const close = f.core.harness.close.bind(f.core.harness);
  Object.assign(f.core.harness, { close: async (...args: Parameters<typeof close>) => { expect(peer.live).toBe(0); harnessClosed = true; return close(...args); } });
  try {
    expect(PUSH_LIMITS.waitMs - PUSH_LIMITS.executionMs).toBe(5_000);
    await push.subscribe(identity, endpoint);
    f.faux.setResponses([fauxAssistantMessage("done")]);
    await f.core.runs.submit("Tonours/fixture", "native done", "native-done");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    await until(async () => peer.received.length === 1);
    f.faux.setResponses([async (_input, options) => {
      await new Promise<void>((resolve) => { if (options?.signal?.aborted) resolve(); else options?.signal?.addEventListener("abort", () => resolve(), { once: true }); });
      return fauxAssistantMessage("stopped");
    }]);
    const blocked = await f.core.runs.submit("Tonours/fixture", "native blocked", "native-blocked");
    await f.core.runs.tick(); expect((await f.core.runs.show(blocked.id)).status).toBe("implementing");
    expect(peer.received).toHaveLength(1);
    now += 50_001; await f.core.runs.enforceLimits(); await f.core.runs.tick();
    expect(attempts.map((attempt) => attempt.kind)).toEqual(["accepted", "accepted"]);
    const active = acceptedPush(attempts[0]), waiting = acceptedPush(attempts[1]);
    expect(await active).toMatchObject({ outcome: "execution_expired", attempted: 1, providerAccepted: 0, failed: 1 });
    await until(async () => peer.received.length === 2);
    closing = f.core.close();
    await new Promise((resolve) => setImmediate(resolve)); expect(harnessClosed).toBe(false);
    peer.release();
    expect(await waiting).toMatchObject({ outcome: "complete", attempted: 1, providerAccepted: 1 });
    await closing; coreClosed = true; expect(harnessClosed).toBe(true); expect(peer.peak).toBeLessThanOrEqual(2);
  } finally {
    peer.release();
    await closing?.catch(() => undefined); await push.close(); await f.core.runs.drainNotifications(); await peer.close();
    if (coreClosed) await rm(f.root, { recursive: true, force: true }); else await f.cleanup();
  }
}, 25_000);

test("a queued setup-failure burst coalesces without growing pending work or blocking the next run", async () => {
  const argv: string[] = [];
  const f = await fixture({ web: { origin, identities: [identity] }, notifyArgv: argv }), peer = await pushPeer(f.root), notices = spyOn(console, "error").mockImplementation(() => {});
  argv.push("/usr/bin/node", "-e", `require('node:fs').appendFileSync(${JSON.stringify(join(f.root, "notify-claims"))}, 'x')`);
  const push = f.core.push!, notify = push.notify.bind(push), admissions: PushAdmission[] = [];
  Object.assign(push, { send: localPushSend(peer), notify: () => { const admission = notify(); admissions.push(admission); return admission; } });
  const prepare = f.core.runs.repositories.prepare.bind(f.core.runs.repositories);
  peer.answer(() => undefined);
  try {
    await push.subscribe(identity, endpoint); await push.subscribe(identity, `${endpoint}-second`);
    for (let i = 0; i < 24; i++) await f.core.runs.submit("Tonours/fixture", "setup failure", `burst-${i}`);
    Object.assign(f.core.runs.repositories, { prepare: async () => { throw new Error("Local setup fixture failure"); } });
    const ticking = f.core.runs.tick(); let progressed = false; void ticking.then(() => { progressed = true; });
    try { await until(async () => progressed, 4_000); } catch (error) { peer.release(); await ticking; throw error; }
    expect(admissions.filter((admission) => admission.kind === "accepted")).toHaveLength(2);
    expect(admissions.filter((admission) => admission.kind === "coalesced")).toHaveLength(22);
    expect((await f.core.runs.list()).every((run) => run.status === "blocked" && run.notified)).toBe(true);
    expect((await readFile(join(f.root, "notify-claims"), "utf8")).length).toBe(24);
    Object.assign(f.core.runs.repositories, { prepare });
    f.faux.setResponses([fauxAssistantMessage("next")]);
    const next = await f.core.runs.submit("Tonours/fixture", "next after overload", "next-after-overload");
    await f.core.runs.tick(); expect((await f.core.runs.show(next.id)).startedAt).toBeGreaterThan(0);
    expect(peer.peak).toBeLessThanOrEqual(2);
    peer.release(); await f.core.runs.drainNotifications();
    expect(notices.mock.calls.some((args) => args[0] === "Web Push attempt summary (not device delivery)")).toBe(true);
    expect(notices.mock.calls.length).toBeLessThanOrEqual(2);
    expect(peer.received).toHaveLength(4);
    await f.core.runs.tick(); await f.core.runs.drainNotifications();
    expect(admissions.filter((admission) => admission.kind === "accepted").length).toBeLessThanOrEqual(3);
  } finally { notices.mockRestore(); peer.release(); Object.assign(f.core.runs.repositories, { prepare }); await peer.close(); await f.cleanup(); }
}, 20_000);

test("native cancellation closes actual HTTPS work and pre-socket errors leave no waiter", async () => {
  const f = await fixture(), peer = await pushPeer(f.root), real = await Push.open(f.core.harness, f.state, origin, [identity]);
  let pending: Promise<void> | undefined;
  try {
    const controller = new AbortController(), headers = { TTL: "3600", Urgency: "high" };
    const cancelled = new AbortController(); cancelled.abort();
    await expect(sendPush(endpoint, headers, peer.transport, 2_000, cancelled.signal)).rejects.toThrow("unconfirmed");
    expect(peer.received).toHaveLength(0);
    await expect(sendPush(endpoint, headers, () => { throw new Error("Fixture before socket"); })).rejects.toThrow("Fixture before socket");
    peer.answer(() => undefined);
    let unconfirmed = false;
    pending = sendPush(endpoint, headers, peer.transport, 2_000, controller.signal).then(() => { throw new Error("Cancelled request was confirmed"); }, () => { unconfirmed = true; });
    await until(async () => peer.live === 1);
    controller.abort(); await until(async () => unconfirmed && peer.live === 0, 500);
    expect(peer.received).toHaveLength(1);
    expect(peer.clients).toBe(0);
    await pending;
    for (const timing of [{ waitMs: 0, executionMs: 1 }, { waitMs: 15_001, executionMs: 1 }, { waitMs: 1, executionMs: 10_001 }]) expect(() => new Push(f.core.harness, real.key, origin, [identity], localPushSend(peer), timing)).toThrow("timing");
  } finally { await peer.close(); await pending; await real.close(); await f.cleanup(); }
});

test("reconcile failure and outer startup failure close Push before the native Harness", async () => {
  const f = await fixture({ web: { origin, identities: [identity] } }), peer = await pushPeer(f.root);
  const originalOpen = Push.open.bind(Push), reconcile = Runs.prototype.reconcile;
  let opened: Push | undefined, closedInOrder = false;
  const opening = spyOn(Push, "open").mockImplementation(async (...args) => {
    const push = opened = await originalOpen(...args); Object.assign(push, { send: localPushSend(peer) });
    const harness = args[0], close = harness.close.bind(harness);
    Object.assign(harness, { close: async (...params: Parameters<typeof close>) => {
      expect(push.notify()).toEqual({ kind: "skipped", reason: "closed" });
      expect(peer.live).toBe(0); closedInOrder = true; return close(...params);
    } });
    return push;
  });
  let failure: ReturnType<typeof spyOn> | undefined;
  try {
    await f.core.push!.subscribe(identity, endpoint);
    const run = await f.core.runs.submit("Tonours/fixture", "startup cleanup", "startup-cleanup");
    await f.core.harness.commit(async (tx) => { (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!.status = "blocked"; }, context);
    peer.answer(() => 410);
    failure = spyOn(Runs.prototype, "reconcile").mockImplementation(async function(this: Runs) { await reconcile.call(this); throw new Error("Reconcile failure fixture"); });
    await expect(f.reopen()).rejects.toThrow("Reconcile failure fixture");
    expect(closedInOrder).toBe(true); expect(peer.received).toHaveLength(1);
    failure.mockRestore(); failure = undefined; closedInOrder = false;
    await expect(openCore({ state: f.state, policy: f.policy, models: f.models, web: { origin, identities: [identity] }, maxTurns: 0 })).rejects.toThrow("Run limits");
    expect(closedInOrder).toBe(true);
  } finally { failure?.mockRestore(); opening.mockRestore(); await opened?.close(); peer.release(); await peer.close(); await f.cleanup(); }
});
