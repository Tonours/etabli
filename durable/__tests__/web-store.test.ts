import { expect, test } from "bun:test";
import type { Registration } from "../web-src/store.ts";
import { A, B, deferred, FakeSocket, harness, listed, ok, settle, type Reply } from "./web-harness.ts";

test("token login sends the token once and the store keeps none", async () => {
  const h = harness();
  await h.signIn();
  expect(h.calls[0]).toEqual({ path: "/v1/browser/session", method: "POST", body: undefined, authorization: `Bearer ${"F".repeat(43)}` });
  expect(h.store.get().session).toBe("in");
  expect(JSON.stringify(h.store.get())).not.toContain("F".repeat(43));
  expect(h.calls.slice(1).every((call) => call.authorization === undefined)).toBe(true);
});

test("sign out deletes the session and clears runs, selection, schedules and draft", async () => {
  const h = harness();
  await h.signIn(); await h.store.showTab("schedules"); await h.store.showTab("runs");
  h.store.route(`#${A}`); h.store.setDraft("draft"); h.store.setForm({ repo: "Tonours/fixture", prompt: "p", cron: "* * * * *" });
  await h.store.logout();
  expect(h.calls.at(-1)).toMatchObject({ path: "/v1/browser/session", method: "DELETE" });
  const state = h.store.get();
  expect([state.session, state.runs, state.selected, state.schedules, state.draft, state.form]).toEqual(["out", undefined, undefined, undefined, "", { repo: "", prompt: "", cron: "" }]);
  expect(state.message).toEqual({ text: "Signed out.", tone: "notice" });
  expect(h.open()).toHaveLength(0);
});

for (const [name, reply] of [["JSON 401", { status: 401, body: { ok: false, error: "no" } }], ["HTML 403", { status: 403, raw: "<html>refused</html>" }]] as const) {
  test(`${name} clears the displayed data and shows the login`, async () => {
    const h = harness();
    await h.signIn(); h.store.route(`#${A}`); h.store.setDraft("private draft");
    h.use(() => reply);
    await expect(h.store.api("/v1/runs")).rejects.toThrow("Session unavailable. Reconnect with your daemon token.");
    const state = h.store.get();
    expect([state.session, state.runs, state.selected, state.draft, state.activity.blocks]).toEqual(["out", undefined, undefined, "", []]);
    expect(h.open()).toHaveLength(0);
  });
}

test("a non-JSON proxy failure shows connection guidance and the next JSON reply renders", async () => {
  const h = harness();
  const restore = h.use(() => ({ status: 502, raw: "Bad gateway" }));
  await expect(h.store.api("/v1/runs")).rejects.toThrow("Daemon unavailable. Check your connection and retry.");
  restore();
  expect(await h.store.api<unknown>("/v1/runs")).toEqual([listed(A), listed(B)]);
});

test("watch: one socket per selection, reopening leaves no stale retry, a drop reconnects once, a run change cancels it", async () => {
  const h = harness();
  await h.signIn();
  h.store.route(`#${A}`); h.store.route(`#${A}`); h.store.select(A);
  expect(h.open()).toHaveLength(1);
  expect(h.timers.size).toBe(0);
  expect(h.open()[0]!.url).toBe(`wss://fixture.invalid/v1/runs/${A}/watch`);
  h.open()[0]!.drop();
  expect(h.store.get().connection).toBe("reconnecting");
  expect(h.timers.size).toBe(1);
  const [retry] = [...h.timers.values()]; h.timers.clear(); retry!();
  expect(h.open()).toHaveLength(1);
  h.open()[0]!.drop();
  expect(h.timers.size).toBe(1);
  h.store.route(`#${B}`);
  expect(h.timers.size).toBe(0);
  expect(h.open().map((socket) => socket.url)).toEqual([`wss://fixture.invalid/v1/runs/${B}/watch`]);
});

test("refresh runs sends one list request and updates the rows", async () => {
  const h = harness();
  await h.signIn();
  h.setRuns([listed(A, "blocked")]);
  const before = h.calls.length;
  await h.store.refresh();
  expect(h.calls.slice(before).map((call) => call.path)).toEqual(["/v1/runs"]);
  expect(h.store.get().runs).toEqual([listed(A, "blocked")]);
});

test("steer reuses its request id until success or a text change and clears the field only for the same run", async () => {
  const h = harness();
  await h.signIn(); h.store.route(`#${A}`);
  let fail = true;
  h.use((call) => call.path.endsWith("/steer") ? (fail ? { status: 500, body: { ok: false, error: "busy" } } : ok({})) : h.fallback(call));
  h.store.setDraft("first");
  await h.store.steer(); await h.store.steer();
  const ids = () => h.calls.filter((call) => call.path.endsWith("/steer")).map((call) => (call.body as { requestId: string }).requestId);
  expect(ids()).toEqual(["request-1", "request-1"]);
  expect(h.store.get().send).toMatchObject({ status: "failed", error: "busy" });
  expect(h.store.get().draft).toBe("first");
  h.store.setDraft("second"); await h.store.steer();
  expect(ids().at(-1)).toBe("request-2");
  fail = false; await h.store.steer();
  expect(ids().at(-1)).toBe("request-2");
  expect(h.store.get().send.status).toBe("queued");
  expect(h.store.get().draft).toBe("");
  h.store.setDraft("second"); await h.store.steer();
  expect(ids().at(-1)).toBe("request-3");
  const pending = deferred<Reply>();
  h.use((call) => call.path.endsWith("/steer") ? pending.promise : h.fallback(call));
  h.store.setDraft("for A"); const sent = h.store.steer();
  h.store.route(`#${B}`); h.store.setDraft("typed for B");
  pending.resolve(ok({})); await sent;
  expect(h.store.get().draft).toBe("typed for B");
  expect(h.store.get().send.status).toBe("idle");
});

test("abort asks first, cancel sends nothing, confirm posts and refreshes, a failure keeps the confirmation", async () => {
  const h = harness();
  await h.signIn(); h.store.route(`#${A}`);
  const count = () => h.calls.filter((call) => call.path.endsWith("/abort")).length;
  h.store.openAbort(true);
  expect(h.store.get().abort.open).toBe(true);
  h.store.openAbort(false);
  expect([h.store.get().abort.open, count()]).toEqual([false, 0]);
  const restore = h.use((call) => call.path.endsWith("/abort") ? { status: 409, body: { ok: false, error: "Run already ended" } } : h.fallback(call));
  h.store.openAbort(true); await h.store.confirmAbort();
  expect(h.store.get().abort).toEqual({ open: true, error: "Run already ended" });
  restore();
  h.setRuns([listed(A, "aborted"), listed(B)]);
  const before = h.calls.length;
  await h.store.confirmAbort();
  expect(h.calls.slice(before).map((call) => `${call.method} ${call.path}`)).toEqual([`POST /v1/runs/${A}/abort`, "GET /v1/runs"]);
  expect(h.store.get().abort.open).toBe(false);
  expect(h.store.selectedRun()?.status).toBe("aborted");
});

test("the Runs and Schedules switch shows one panel and reloads its list", async () => {
  const h = harness();
  await h.signIn();
  let before = h.calls.length;
  await h.store.showTab("schedules");
  expect([h.store.get().tab, h.calls.slice(before).map((call) => call.path)]).toEqual(["schedules", ["/v1/schedules"]]);
  before = h.calls.length;
  await h.store.showTab("runs");
  expect([h.store.get().tab, h.calls.slice(before).map((call) => call.path)]).toEqual(["runs", ["/v1/runs"]]);
});

test("schedule create reuses its request id on retry, clears the task and reloads", async () => {
  const h = harness();
  await h.signIn();
  let fail = true;
  h.use((call) => call.path === "/v1/schedules" && call.method === "POST" ? (fail ? { status: 500, body: { ok: false, error: "later" } } : ok({})) : h.fallback(call));
  h.store.setForm({ repo: "Tonours/fixture", prompt: "nightly", cron: "0 9 * * *" });
  await h.store.createSchedule(); await h.store.createSchedule();
  const ids = () => h.calls.filter((call) => call.method === "POST" && call.path === "/v1/schedules").map((call) => (call.body as { requestId: string }).requestId);
  expect(ids()).toEqual(["request-1", "request-1"]);
  expect(h.store.get().message?.text).toBe("later");
  h.store.setForm({ cron: "0 10 * * *" }); fail = false;
  await h.store.createSchedule();
  expect(ids().at(-1)).toBe("request-2");
  expect(h.store.get().form).toEqual({ repo: "Tonours/fixture", prompt: "", cron: "0 10 * * *" });
  expect(h.calls.at(-1)).toMatchObject({ path: "/v1/schedules", method: "GET" });
  h.store.setForm({ prompt: "nightly" }); await h.store.createSchedule();
  expect(ids().at(-1)).toBe("request-3");
});

test("schedule delete stays disabled while pending, reloads on success, re-enables on failure", async () => {
  const h = harness();
  await h.signIn();
  const id = "33333333-3333-4333-8333-333333333333";
  const pending = deferred<Reply>();
  const restore = h.use((call) => call.method === "DELETE" ? pending.promise : h.fallback(call));
  const removal = h.store.deleteSchedule(id);
  expect(h.store.get().deleting).toEqual([id]);
  await h.store.deleteSchedule(id);
  expect(h.calls.filter((call) => call.method === "DELETE")).toHaveLength(1);
  pending.resolve({ status: 500, body: { ok: false, error: "Schedule is busy" } }); await removal;
  expect([h.store.get().deleting, h.store.get().message?.text]).toEqual([[], "Schedule is busy"]);
  restore();
  const before = h.calls.length;
  await h.store.deleteSchedule(id);
  expect(h.calls.slice(before).map((call) => `${call.method} ${call.path}`)).toEqual([`DELETE /v1/schedules/${id}`, "GET /v1/schedules"]);
});

function pushEnv(h: ReturnType<typeof harness>, key: Uint8Array, options: { current?: Uint8Array; permission?: string; events?: string[] } = {}) {
  const events = options.events ?? [];
  const subscription = (bytes: Uint8Array) => ({ endpoint: "https://fcm.googleapis.com/fcm/send/fixture", options: { applicationServerKey: bytes.buffer as ArrayBuffer }, unsubscribe: async () => { events.push("unsubscribe"); return true; } });
  let current = options.current ? subscription(options.current) : null;
  const registration: Registration = { pushManager: { getSubscription: async () => current, subscribe: async () => { events.push("subscribe"); current = subscription(key); return current; } } };
  h.env.push = { register: async () => registration, requestPermission: () => { events.push("permission"); return Promise.resolve(options.permission ?? "granted"); } };
  h.use((call) => {
    if (call.path === "/v1/push/key") return ok({ publicKey: Buffer.from(key).toString("base64url") });
    if (call.path === "/v1/push/subscriptions") { events.push(`${call.method} subscription`); return ok({}); }
    return h.fallback(call);
  });
  return events;
}
const key = Uint8Array.from([4, ...Array<number>(64).fill(1)]);

test("push setup discards a subscription bound to an old key and reuses a current one", async () => {
  for (const matches of [false, true]) {
    const h = harness();
    const events = pushEnv(h, key, { current: matches ? key : Uint8Array.from([4, ...Array<number>(64).fill(2)]) });
    await h.signIn();
    expect(events).toEqual(matches ? ["POST subscription"] : ["unsubscribe", "DELETE subscription"]);
    expect(h.store.get().push.subscribed).toBe(matches);
    expect(h.store.get().push.text).toBe(matches ? "Notifications enabled for this device. Run contents stay private." : "The daemon notification key changed. Enable notifications again for this device.");
  }
});

test("a push setup failure shows in the notification state only", async () => {
  const h = harness();
  h.env.push = { register: async () => { throw new Error("Service worker refused"); }, requestPermission: async () => "granted" };
  await h.signIn();
  expect([h.store.get().push.text, h.store.get().message, h.store.get().session]).toEqual(["Service worker refused", undefined, "in"]);
});

test("enable notifications requests permission before any await, explains a refusal and posts the endpoint", async () => {
  for (const permission of ["denied", "granted"]) {
    const h = harness();
    const events = pushEnv(h, key, { permission });
    await h.signIn(); events.length = 0;
    const done = h.store.enableNotifications();
    expect(events).toEqual(["permission"]);
    await done;
    if (permission === "denied") expect(h.store.get().message?.text).toBe("Notifications were not allowed. Change the browser permission to enable them.");
    else expect([events, h.store.get().push.subscribed, h.store.get().push.text]).toEqual([["permission", "subscribe", "POST subscription"], true, "Notifications enabled for this device."]);
  }
});

test("disable notifications deletes the daemon subscription, then unsubscribes", async () => {
  const h = harness();
  const events = pushEnv(h, key, { current: key });
  await h.signIn(); events.length = 0;
  await h.store.disableNotifications();
  expect(events).toEqual(["DELETE subscription", "unsubscribe"]);
  expect([h.store.get().push.subscribed, h.store.get().push.text]).toEqual([false, "Notifications disabled for this device."]);
});

test("opening and polling never request the per-run show; the plan is polled only while its panel is open", async () => {
  const h = harness();
  await h.signIn();
  h.store.route(`#${A}`);
  await h.store.poll();
  h.store.setPanel("plan"); await settle();
  await h.store.poll();
  h.store.setPanel("activity");
  await h.store.poll();
  const paths = h.calls.map((call) => call.path);
  expect(paths.filter((path) => path === `/v1/runs/${A}`)).toHaveLength(0);
  expect(paths.filter((path) => path === `/v1/runs/${A}/plan`)).toHaveLength(2);
  expect(h.store.get().plan).toEqual({ enabled: true, status: "DRAFT", sections: { Goal: "goal" } });
});

test("(a, e) a superseded selection keeps no socket and its frames and close events are ignored", async () => {
  const h = harness();
  await h.signIn();
  h.store.route(`#${A}`);
  const first = FakeSocket.all[0]!;
  h.store.route(`#${B}`);
  first.frame({ entries: [{ id: 1, model: [{ role: "assistant", content: "stale A" }] }] });
  first.emit("close");
  expect([h.store.get().activity.blocks, h.timers.size, h.open().length]).toEqual([[], 0, 1]);
});

test("(b) an invalid or unknown hash closes the run, its watch and its timer", async () => {
  for (const hash of ["#../../v1/schedules", `#${A.toUpperCase()}`, `#${A.slice(1)}`, "#44444444-4444-4444-8444-444444444444"]) {
    const h = harness();
    await h.signIn();
    h.store.route(`#${A}`); h.open()[0]!.drop();
    const before = h.calls.length;
    h.store.route(hash);
    expect([h.store.get().selected, h.open().length, h.timers.size, h.store.get().message?.text]).toEqual([undefined, 0, 0, "That run is no longer available."]);
    expect(h.calls.length).toBe(before);
  }
});

test("(c) a 401 during a pending poll clears everything and a new session renders its own rows", async () => {
  const h = harness();
  await h.signIn(); h.store.route(`#${A}`); h.store.setDraft("draft");
  const pending = deferred<Reply>();
  const restore = h.use((call) => call.path === "/v1/runs" ? pending.promise : h.fallback(call));
  const poll = h.store.poll();
  pending.resolve({ status: 401, body: { ok: false } }); await poll;
  restore();
  expect([h.store.get().session, h.store.get().runs, h.store.get().draft, h.store.get().selected]).toEqual(["out", undefined, "", undefined]);
  h.setRuns([listed(B)]);
  await h.signIn();
  expect(h.store.get().runs?.map((run) => run.id)).toEqual([B]);
});

test("(d) plan and steer replies of an earlier visit are dropped, also after A, B, A", async () => {
  const h = harness();
  await h.signIn(); h.store.route(`#${A}`);
  const plan = deferred<Reply>(), steer = deferred<Reply>();
  let plans = 0;
  h.use((call) => call.path.endsWith("/plan") && ++plans === 1 ? plan.promise : call.path.endsWith("/steer") ? steer.promise : h.fallback(call));
  h.store.setPanel("plan"); h.store.setDraft("old");
  const sent = h.store.steer();
  h.store.route(`#${B}`); h.store.route(`#${A}`); h.store.setPanel("plan");
  plan.resolve(ok({ enabled: true, status: "STALE", sections: {} })); steer.resolve({ status: 500, body: { ok: false, error: "stale failure" } });
  await sent; await settle();
  expect([h.store.get().plan?.status, h.store.get().send.status]).toEqual(["DRAFT", "idle"]);
});

test("(f) sign-out cancels a pending reconnect", async () => {
  const h = harness();
  await h.signIn(); h.store.route(`#${A}`); h.open()[0]!.drop();
  expect(h.timers.size).toBe(1);
  await h.store.logout();
  expect([h.timers.size, h.open().length]).toEqual([0, 0]);
});

test("(g) the run ending during an action removes the controls and keeps the draft and the outcome", async () => {
  const h = harness();
  await h.signIn(); h.store.route(`#${A}`);
  h.store.setPanel("instructions"); h.store.openAbort(true); h.store.setDraft("kept draft");
  const steer = deferred<Reply>();
  h.use((call) => call.path.endsWith("/steer") ? steer.promise : h.fallback(call));
  const sent = h.store.steer();
  h.store.setDraft("kept draft");
  h.setRuns([listed(A, "blocked", { reason: "wall_clock_limit" }), listed(B)]);
  await h.store.poll();
  expect([h.store.get().panel, h.store.get().abort.open, h.store.get().draft]).toEqual(["overview", false, "kept draft"]);
  steer.resolve({ status: 409, body: { ok: false, error: "Run ended" } }); await sent;
  expect(h.store.get().send).toEqual({ status: "failed", error: "Run ended", content: "kept draft", ended: true });
});

test("(h) selecting another run resets the panel, the draft and the reading position", async () => {
  const h = harness();
  await h.signIn(); h.store.route(`#${A}`);
  h.store.setPanel("activity"); h.store.setDraft("for A"); h.store.follow(false, 420);
  h.open()[0]!.frame({ entries: [{ id: 1, model: [{ role: "assistant", content: "A only" }] }] });
  h.store.route(`#${B}`);
  const state = h.store.get();
  expect([state.panel, state.draft, state.activity.blocks, state.activity.follow, state.activity.offset]).toEqual(["overview", "", [], true, 0]);
});

test("a reload on a run hash opens that run once the list arrives", async () => {
  const h = harness();
  h.setHash(`#${B}`);
  const restore = h.use(() => ({ status: 401, body: { ok: false } }));
  h.store.start();
  await settle(); await settle();
  restore();
  expect(h.store.get().session).toBe("out");
  await h.signIn();
  expect([h.store.get().selected, h.open().map((socket) => socket.url)]).toEqual([B, [`wss://fixture.invalid/v1/runs/${B}/watch`]]);
});

test("offline, pagehide, online and a bfcache restore each act once on the open run", async () => {
  const h = harness();
  await h.signIn();
  h.store.route(`#${A}`);
  expect(h.open()).toHaveLength(1);
  h.store.offline();
  expect(h.store.get().message?.text).toBe("You are offline. Reconnect to watch and control runs.");
  h.store.pagehide();
  expect(h.open()).toHaveLength(0);
  const lists = () => h.calls.filter((call) => call.path === "/v1/runs").length;
  const before = lists();
  h.store.online();
  await settle();
  expect([h.open().length, h.open()[0]!.url.includes(A), lists()]).toEqual([1, true, before + 1]);
  h.store.applyFrame({ entries: [{ id: 1, model: [{ role: "assistant", content: "old page" }] }] });
  h.store.pageshow(false);
  expect(h.store.get().activity.blocks).toHaveLength(1);
  h.setHash(`#${A}`);
  h.store.pageshow(true);
  expect([h.store.get().activity.blocks.length, h.open().length]).toEqual([0, 0]);
  await settle(); await settle();
  expect([h.store.get().session, h.store.get().selected, h.open().length]).toEqual(["in", A, 1]);
});

test("a poll in flight at sign out leaves the Signed out notice alone", async () => {
  const h = harness();
  await h.signIn();
  const gate = deferred<Reply>();
  const restore = h.use((call) => call.path === "/v1/runs" ? gate.promise : h.fallback(call));
  const polling = h.store.poll();
  restore();
  await h.store.logout();
  gate.resolve(ok([listed(A)]));
  await polling;
  expect([h.store.get().session, h.store.get().message?.text, h.store.get().runs]).toEqual(["out", "Signed out.", undefined]);
});

test("an older run-list reply never overwrites a newer one", async () => {
  const h = harness();
  await h.signIn();
  const first = deferred<Reply>(), second = deferred<Reply>();
  const replies = [first, second];
  const restore = h.use((call) => call.path === "/v1/runs" ? replies.shift()!.promise : h.fallback(call));
  const older = h.store.listRuns(), newer = h.store.listRuns();
  restore();
  second.resolve(ok([listed(A, "aborted")]));
  await newer;
  first.resolve(ok([listed(A, "implementing")]));
  await older;
  expect(h.store.get().runs?.map((run) => run.status)).toEqual(["aborted"]);
});

test("the startup session check never ends a session signed in after it", async () => {
  const h = harness();
  const check = deferred<Reply>();
  let first = true;
  const restore = h.use((call) => call.path === "/v1/runs" && first ? (first = false, check.promise) : h.fallback(call));
  h.store.start();
  await h.signIn(); h.store.setDraft("kept");
  restore();
  check.resolve({ status: 401, body: { ok: false, error: "no" } });
  await settle(); await settle();
  expect([h.store.get().session, h.store.get().draft, h.store.get().message?.text ?? ""]).toEqual(["in", "kept", ""]);
});

test("an older schedule list never restores a deleted row", async () => {
  const h = harness();
  await h.signIn();
  const older = deferred<Reply>();
  let lists = 0;
  const row = { id: "s1", repo: "Tonours/fixture", prompt: "p", cron: "* * * * *", nextDue: 0 };
  h.use((call) => call.path === "/v1/schedules" && call.method === "GET" ? (++lists === 1 ? older.promise : ok([])) : h.fallback(call));
  const reopened = h.store.loadSchedules();
  await h.store.deleteSchedule("s1");
  older.resolve(ok([row]));
  await reopened;
  expect(h.store.get().schedules).toEqual([]);
});

test("an older plan reply of the same visit never overwrites a newer one", async () => {
  const h = harness();
  await h.signIn(); h.store.route(`#${A}`);
  const older = deferred<Reply>();
  let plans = 0;
  h.use((call) => call.path.endsWith("/plan") ? (++plans === 1 ? older.promise : ok({ enabled: true, status: "NEW", sections: {} })) : h.fallback(call));
  h.store.setPanel("plan");
  await h.store.loadPlan();
  older.resolve(ok({ enabled: true, status: "OLD", sections: {} }));
  await settle(); await settle();
  expect(h.store.get().plan?.status).toBe("NEW");
});
