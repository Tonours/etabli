import { expect, test } from "bun:test";
import { createPublicKey, verify } from "node:crypto";
import { chmod, readFile, stat, symlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { createServer, request } from "node:https";
import { runInNewContext } from "node:vm";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { loadVapid, Push, PushDoc, pushEndpoint, pushHeaders, sendPush } from "../src/push.ts";
import { fixture } from "./helpers.ts";

const identity = "owner@example.invalid", origin = "https://app.fixture.ts.net";
const endpoint = "https://fcm.googleapis.com/fcm/send/fixture";

test("actual service worker shows generic push without network/cache and opens only its own app", async () => {
  type Event = { waitUntil(promise: Promise<unknown>): void; notification: { close(): void } };
  const listeners = new Map<string, (event: Event) => void>();
  const notifications: { title: string; body: string }[] = [], opened: string[] = [];
  let pending: Promise<unknown> | undefined, closed = false;
  runInNewContext(await readFile(new URL("../web/sw.js", import.meta.url), "utf8"), { URL, self: {
    location: { origin }, addEventListener: (name: string, listener: (event: Event) => void) => listeners.set(name, listener),
    registration: { showNotification: async (title: string, value: { body: string }) => { notifications.push({ title, body: value.body }); } },
    clients: { matchAll: async () => [{ url: "https://foreign.invalid/", focus: async () => { throw new Error("Foreign client focused"); } }], openWindow: async (path: string) => { opened.push(path); } },
  } });
  const event = { waitUntil: (promise: Promise<unknown>) => { pending = promise; }, notification: { close: () => { closed = true; } } };
  listeners.get("push")!(event); await pending;
  expect(notifications).toEqual([{ title: "Etabli", body: "A run finished or needs your attention. Open Etabli to check." }]);
  expect(listeners.has("fetch")).toBe(false);
  listeners.get("notificationclick")!(event); await pending;
  expect(closed).toBe(true); expect(opened).toEqual(["/"]);
});

test("native push transport sends an empty signed POST, refuses redirects and enforces a total deadline", async () => {
  const f = await fixture();
  const tlsKey = join(f.root, "tls.key"), tlsCert = join(f.root, "tls.pem");
  execFileSync("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", tlsKey, "-out", tlsCert, "-days", "1", "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1"], { stdio: "ignore" });
  const cert = await readFile(tlsCert);
  let redirect = false, hanging = false, calls = 0;
  const server = createServer({ key: await readFile(tlsKey), cert }, (req, res) => {
    calls++; expect(req.method).toBe("POST"); expect(req.headers.ttl).toBe("3600"); expect(req.headers.urgency).toBe("high"); expect(req.headers.authorization).toStartWith("vapid t=");
    let body = ""; req.on("data", (chunk) => { body += String(chunk); });
    req.on("end", () => { expect(body).toBe(""); if (hanging) return; res.writeHead(redirect ? 307 : 201, redirect ? { Location: "https://127.0.0.1/secret" } : {}); res.end(); });
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as { port: number }).port;
  try {
    const headers = pushHeaders(await loadVapid(join(f.state, "vapid.pem")), endpoint, origin);
    const transport: Parameters<typeof sendPush>[2] = (url, options, cb) => { expect(url).toBe(endpoint); return request(`https://127.0.0.1:${port}/`, { ...options, ca: cert }, cb); };
    expect(await sendPush(endpoint, headers, transport)).toBe(201);
    redirect = true; expect(await sendPush(endpoint, headers, transport)).toBe(307); expect(calls).toBe(2);
    hanging = true; await expect(sendPush(endpoint, headers, transport, 50)).rejects.toThrow("Push delivery failed"); expect(calls).toBe(3);
  } finally { server.closeAllConnections(); await new Promise<void>((resolve) => server.close(() => resolve())); await f.cleanup(); }
});

test("first-start VAPID is stable owned0600 P256 and native RFC8292 signature/wire headers verify", async () => {
  const f = await fixture();
  try {
    const path = join(f.state, "vapid.pem"), key = await loadVapid(path);
    expect((await stat(path)).mode & 0o777).toBe(0o600);
    expect((await loadVapid(path)).publicKey).toBe(key.publicKey);
    expect(Buffer.from(key.publicKey, "base64url")).toHaveLength(65);
    const now = Date.now(), headers = pushHeaders(key, endpoint, origin, now);
    expect(headers.TTL).toBe("3600"); expect(headers.Urgency).toBe("high"); expect(headers["Content-Length"]).toBe("0");
    const token = headers.Authorization.match(/^vapid t=([^,]+), k=(.+)$/)!;
    expect(token[2]).toBe(key.publicKey);
    const [header, body, signature] = token[1].split(".");
    expect(JSON.parse(Buffer.from(header, "base64url").toString())).toEqual({ typ: "JWT", alg: "ES256" });
    expect(JSON.parse(Buffer.from(body, "base64url").toString())).toEqual({ aud: "https://fcm.googleapis.com", exp: Math.floor(now / 1000) + 43_200, sub: origin });
    const publicKey = createPublicKey(await readFile(path, "utf8"));
    expect(verify("sha256", Buffer.from(`${header}.${body}`), { key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(signature, "base64url"))).toBe(true);
    expect(verify("sha256", Buffer.from(`${header}.${body}x`), { key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(signature, "base64url"))).toBe(false);
    await chmod(path, 0o644); await expect(loadVapid(path)).rejects.toThrow("0600");
    await chmod(path, 0o600); await symlink(path, join(f.state, "link.pem")); await expect(loadVapid(join(f.state, "link.pem"))).rejects.toThrow();
    await writeFile(path, "broken"); await expect(loadVapid(path)).rejects.toThrow();
    expect(await readFile(path, "utf8")).toBe("broken");
  } finally { await f.cleanup(); }
});

test("push endpoints reject SSRF/alternate transport and support the bounded phone provider set", () => {
  for (const invalid of ["http://fcm.googleapis.com/a", "https://127.0.0.1/a", "https://web.push.apple.com.evil.invalid/a", "https://evil@web.push.apple.com/a", "https://fcm.googleapis.com:8443/a", "https://fcm.googleapis.com/a#secret", "https://updates.push.services.mozilla.com/", "https://example.invalid/a", "x".repeat(4097)]) expect(() => pushEndpoint(invalid)).toThrow();
  for (const host of ["fcm.googleapis.com", "updates.push.services.mozilla.com", "web.push.apple.com"]) expect(pushEndpoint(`https://${host}/fixture?a=b`)).toBe(`https://${host}/fixture?a=b`);
});

test("native SQLite subscriptions survive reopen, deduplicate, enforce identity/cap and prune only rejected/removed identities", async () => {
  const f = await fixture();
  try {
    const key = await loadVapid(join(f.state, "vapid.pem"));
    let calls: string[] = [];
    const send = async (url: string) => { calls.push(url); return url.endsWith("gone") ? 410 : url.endsWith("missing") ? 404 : 503; };
    let push = new Push(f.core.harness, key, origin, [identity, "removed@example.invalid"], send);
    await push.subscribe(identity, endpoint); await push.subscribe(identity, endpoint);
    await push.subscribe(identity, `${endpoint}-gone`); await push.subscribe(identity, `${endpoint}-missing`);
    await push.subscribe("removed@example.invalid", `${endpoint}-removed`);
    await expect(push.subscribe("removed@example.invalid", endpoint)).rejects.toThrow("another identity");
    expect(await push.unsubscribe("removed@example.invalid", endpoint)).toEqual({ deleted: false });
    await f.reopen();
    push = new Push(f.core.harness, key, origin, [identity], send);
    expect((await f.core.harness.snapshot(PushDoc, context))?.subscriptions).toHaveLength(4);
    await push.notify();
    expect(calls).toHaveLength(3); expect(calls).not.toContain(`${endpoint}-removed`);
    expect((await f.core.harness.snapshot(PushDoc, context))?.subscriptions.map((row) => row.endpoint)).toEqual([endpoint]);
    for (let i = 1; i < 64; i++) await push.subscribe(identity, `${endpoint}-${i}`);
    await expect(push.subscribe(identity, `${endpoint}-overflow`)).rejects.toThrow("limit");
    expect(await push.unsubscribe(identity, endpoint)).toEqual({ deleted: true });
    expect(await push.unsubscribe(identity, endpoint)).toEqual({ deleted: false });
    await push.subscribe(identity, `${endpoint}-overflow`);
  } finally { await f.cleanup(); }
});

test("push fanout is concurrent, stale prune cannot delete a replacement subscription", async () => {
  const f = await fixture();
  try {
    const key = await loadVapid(join(f.state, "vapid.pem"));
    let release!: () => void, started = 0;
    const gate = new Promise<void>((resolve) => { release = resolve; });
    const push = new Push(f.core.harness, key, origin, [identity], async () => { started++; await gate; return 410; });
    await push.subscribe(identity, endpoint); await push.subscribe(identity, `${endpoint}-other`);
    const pending = push.notify();
    const { until } = await import("./helpers.ts"); await until(async () => started === 2);
    await push.unsubscribe(identity, endpoint); await push.subscribe(identity, endpoint);
    release(); await pending;
    expect((await f.core.harness.snapshot(PushDoc, context))?.subscriptions.map((row) => row.endpoint)).toEqual([endpoint]);
  } finally { await f.cleanup(); }
});

test("done/blocked push shares terminal claim, aborted skips push; hung delivery never holds the run line and close drains", async () => {
  const f = await fixture();
  let release!: () => void;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  let calls = 0;
  Object.assign(f.core.runs, { pushNotify: async () => { calls++; await gate; } });
  try {
    f.faux.setResponses([fauxAssistantMessage("done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "push fixture", "push");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context); await f.core.runs.tick();
    expect(calls).toBe(1); expect((await f.core.runs.show(run.id)).notified).toBe(true);
    const next = await f.core.runs.submit("Tonours/fixture", "next fixture", "next");
    await f.core.runs.abort(next.id); await f.core.runs.tick(); expect(calls).toBe(1);
    const blocked = await f.core.runs.submit("Tonours/fixture", "blocked fixture", "blocked");
    const { RunsDoc } = await import("../src/runs-doc.ts");
    await f.core.harness.commit(async (tx) => { const row = (await tx.doc(RunsDoc)).runs.find((row) => row.id === blocked.id)!; row.status = "blocked"; }, context);
    await f.core.runs.tick(); expect(calls).toBe(2);
    let drained = false; const drain = f.core.runs.drainNotifications().then(() => { drained = true; });
    await Promise.resolve(); expect(drained).toBe(false);
    release(); await drain;
    await f.reopen(); await f.core.runs.tick(); expect(calls).toBe(2);
  } finally { release(); await f.cleanup(); }
});

test("each fresh terminal generation of the same run may push once, with no permanent run-id deduplication", async () => {
  const f = await fixture();
  let sends = 0;
  try {
    const key = await loadVapid(join(f.state, "vapid.pem"));
    const attach = () => {
      const push = new Push(f.core.harness, key, origin, [identity], async () => { sends++; return 201; });
      Object.assign(f.core.runs, { pushNotify: () => push.notify() });
      return push;
    };
    await attach().subscribe(identity, endpoint);
    f.faux.setResponses([fauxAssistantMessage("done")]);
    const run = await f.core.runs.submit("Tonours/fixture", "terminal generation fixture", "terminal-generation");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    await f.core.runs.tick(); await f.core.runs.drainNotifications();
    expect(sends).toBe(1);
    const { RunsDoc } = await import("../src/runs-doc.ts");
    for (const [terminalGeneration, status] of [["ci-1", "done"], ["ci-exhausted", "blocked"]] as const) {
      // Reproduce S6's notification boundary without implementing or borrowing its CI trigger.
      await f.core.harness.commit(async (tx) => {
        const row = (await tx.doc(RunsDoc)).runs.find((row) => row.id === run.id)!;
        Object.assign(row, { terminalGeneration, status, notified: false });
      }, context);
      const previous = sends;
      await f.core.runs.tick(); await f.core.runs.drainNotifications();
      expect(sends).toBe(previous + 1);
      await f.core.runs.tick(); await f.core.runs.tick(); await f.core.runs.drainNotifications();
      expect(sends).toBe(previous + 1);
    }
    await f.reopen(); attach();
    await f.core.runs.tick(); await f.core.runs.drainNotifications();
    expect(sends).toBe(3);
  } finally { await f.cleanup(); }
});
