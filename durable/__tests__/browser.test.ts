import { expect, test } from "bun:test";
import { randomBytes } from "node:crypto";
import { request } from "node:http";
import { WebSocket } from "ws";
import { fauxAssistantMessage } from "@earendil-works/pi-ai/providers/faux";
import { serveRemote } from "../src/api.ts";
import { Browser } from "../src/browser.ts";
import { daemonConfig } from "../src/daemon.ts";
import { Push } from "../src/push.ts";
import { fixture } from "./helpers.ts";
import { acceptedPush } from "./fixtures/push-peer.ts";

const identity = "owner@example.invalid", origin = "https://app.fixture.ts.net";
type Reply = { status: number; text: string; headers: import("node:http").IncomingHttpHeaders };
function http(port: number, path: string, method = "GET", headers: string[] = [], body?: unknown): Promise<Reply> {
  const payload = body === undefined ? undefined : JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const outgoing = request({ hostname: "127.0.0.1", port, path, method, headers: ["Host", `127.0.0.1:${port}`, ...headers, ...(payload === undefined ? [] : ["Content-Length", String(Buffer.byteLength(payload))])] }, (response) => {
      let text = ""; response.setEncoding("utf8"); response.on("data", (chunk) => { text += String(chunk); });
      response.on("end", () => resolve({ status: response.statusCode!, text, headers: response.headers }));
    });
    outgoing.on("error", reject); outgoing.end(payload);
  });
}
function upgrade(port: number, path: string, headers: Record<string, string>): Promise<number> {
  return new Promise((resolve, reject) => {
    const client = new WebSocket(`ws://127.0.0.1:${port}${path}`, { headers });
    client.once("error", reject); client.once("open", () => { client.close(); resolve(101); });
    client.once("unexpected-response", (_req, response) => { response.resume(); client.terminate(); resolve(response.statusCode!); });
  });
}

test("browser assets and session preserve bearer/identity while denying sibling-origin HTTP and WS attacks", async () => {
  const f = await fixture(); const token = randomBytes(32).toString("base64url");
  const push = await Push.open(f.core.harness, f.state, origin, [identity, "other@example.invalid"]);
  const server = await serveRemote(f.core, 0, token, [identity, "other@example.invalid"], { origin, push });
  const port = (server.address() as { port: number }).port;
  const owner = ["Tailscale-User-Login", identity];
  const marker = ["X-Etabli-Client", "web-v1"], auth = ["Authorization", `Bearer ${token}`];
  try {
    expect((await http(port, "/")).status).toBe(403);
    for (const path of ["/", "/app.js", "/style.css", "/sw.js", "/manifest.webmanifest", "/icon-192.png", "/icon-512.png"]) {
      const asset = await http(port, path, "GET", owner);
      expect(asset.status).toBe(200); expect(asset.headers["cache-control"]).toBe("no-store");
      expect(asset.headers["content-security-policy"]).toContain("wss://app.fixture.ts.net");
      expect(asset.text).not.toContain(token);
    }
    for (const path of ["/api.token", "/../src/auth.ts", "/%2e%2e/src/auth.ts", "/app.js?token=wrong", "/app.js/", "//app.js"]) expect((await http(port, path, "GET", owner)).status).not.toBe(200);
    expect((await http(port, "/app.js", "GET", ["Tailscale-User-Login", "foreign@example.invalid"])).status).toBe(403);
    expect((await http(port, "/", "POST", owner)).status).toBe(405);
    expect((await http(port, "/v1/runs", "GET", owner)).status).toBe(403);
    expect((await http(port, "/v1/runs", "GET", [...owner, ...auth])).status).toBe(200);
    expect((await http(port, "/v1/browser/session", "POST", [...owner, ...auth, ...marker])).status).toBe(403);
    expect((await http(port, "/v1/browser/session", "POST", [...owner, ...marker, "Origin", origin])).status).toBe(401);
    expect((await http(port, "/v1/browser/session", "POST", [...owner, ...auth, ...marker, "Origin", "https://evil.fixture.ts.net"])).status).toBe(403);
    const login = await http(port, "/v1/browser/session", "POST", [...owner, ...auth, ...marker, "Origin", origin]);
    expect(login.status).toBe(200);
    const set = login.headers["set-cookie"]![0];
    for (const attribute of ["HttpOnly", "Secure", "SameSite=Strict", "Path=/", "Max-Age=43200"]) expect(set).toContain(attribute);
    const cookie = set.split(";")[0], browser = [...owner, ...marker, "Cookie", cookie];
    expect((await http(port, "/v1/runs", "GET", browser)).status).toBe(200);
    expect((await http(port, "/v1/runs", "GET", [...browser, "Sec-Fetch-Site", "same-origin"])).status).toBe(200);
    expect((await http(port, "/v1/runs", "GET", [...marker, "Cookie", cookie])).status).toBe(403);
    expect((await http(port, "/v1/runs", "GET", ["Tailscale-User-Login", "foreign@example.invalid", ...marker, "Cookie", cookie])).status).toBe(403);
    const key = await http(port, "/v1/push/key", "GET", browser);
    expect(key.status).toBe(200); expect(key.text).not.toContain("PRIVATE");
    expect(JSON.parse(key.text).value.publicKey).toBe(push.key.publicKey);
    const subscription = { endpoint: "https://fcm.googleapis.com/fcm/send/browser-fixture" };
    expect((await http(port, "/v1/push/subscriptions", "POST", [...browser, "Origin", origin], subscription)).status).toBe(200);
    const alternate = await http(port, "/v1/browser/session", "POST", ["Tailscale-User-Login", "other@example.invalid", ...auth, ...marker, "Origin", origin]);
    const alternateHeaders = ["Tailscale-User-Login", "other@example.invalid", ...marker, "Origin", origin, "Cookie", alternate.headers["set-cookie"]![0].split(";")[0]];
    expect((await http(port, "/v1/push/subscriptions", "POST", alternateHeaders, subscription)).status).toBe(400);
    expect((await http(port, "/v1/push/subscriptions", "DELETE", alternateHeaders, subscription)).text).toContain('"deleted":false');
    expect((await http(port, "/v1/push/subscriptions", "POST", [...browser, "Origin", "https://evil.fixture.ts.net"], subscription)).status).toBe(403);
    expect((await http(port, "/v1/push/subscriptions", "DELETE", [...browser, "Origin", origin], subscription)).text).toContain('"deleted":true');
    expect((await http(port, "/v1/push/subscriptions", "DELETE", [...browser, "Origin", origin], subscription)).text).toContain('"deleted":false');
    expect((await http(port, "/v1/push/subscriptions", "POST", [...browser, "Origin", origin], { endpoint: "https://127.0.0.1/ssrf" })).status).toBe(400);
    for (const endpoint of ["https://169.254.169.254/x", "https://fcm.googleapis.com:8443/x", "https://fcm.googleapis.com./x", "https://u:p@fcm.googleapis.com/x"]) expect((await http(port, "/v1/push/subscriptions", "POST", [...browser, "Origin", origin], { endpoint })).status).toBe(400);
    for (const extra of [{ p256dh: "unexpected" }, { identity: "other@example.invalid" }]) expect((await http(port, "/v1/push/subscriptions", "POST", [...browser, "Origin", origin], { ...subscription, ...extra })).status).toBe(400);
    expect((await http(port, "/v1/runs", "GET", [...owner, "Cookie", cookie])).status).toBe(403);
    expect((await http(port, "/v1/runs", "GET", [...browser, "Authorization", "Bearer invalid"])).status).toBe(401);
    expect(await http(port, "/v1/runs", "GET", [...browser, "Authorization", ""])).toMatchObject({ status: 401, text: '{"error":"Bearer token required"}' });
    expect((await http(port, "/v1/runs", "GET", [...browser, "Authorization", `Bearer ${"A".repeat(43)}`])).status).toBe(401);
    expect((await http(port, "/v1/runs", "GET", [...browser, "Cookie", cookie])).status).toBe(401);
    expect((await http(port, "/v1/runs", "GET", [...browser, "Tailscale-User-Login", identity])).status).toBe(403);
    expect((await http(port, "/v1/runs", "GET", ["Tailscale-User-Login", "other@example.invalid", ...marker, "Cookie", cookie])).status).toBe(401);
    for (const method of ["GET", "POST", "DELETE"]) {
      const path = method === "DELETE" ? "/v1/browser/session" : "/v1/runs";
      expect((await http(port, path, method, [...browser, "Origin", "https://evil.fixture.ts.net"])).status).toBe(403);
      expect((await http(port, path, method, [...browser, "Sec-Fetch-Site", "same-site", "Origin", origin])).status).toBe(403);
      expect((await http(port, path, method, [...browser, "Origin", origin, "Origin", origin])).status).toBe(403);
    }
    const preflight = await http(port, "/v1/runs", "OPTIONS", [...owner, "Origin", "https://evil.fixture.ts.net", "Access-Control-Request-Method", "POST", "Access-Control-Request-Headers", "X-Etabli-Client"]);
    expect(preflight.status).toBe(403); expect(preflight.headers["access-control-allow-origin"]).toBeUndefined();
    f.faux.setResponses([async (_input, options) => {
      await new Promise<void>((resolve) => { if (options?.signal?.aborted) resolve(); else options?.signal?.addEventListener("abort", () => resolve(), { once: true }); });
      return fauxAssistantMessage("Stopped");
    }]);
    const run = await f.core.runs.submit("Tonours/fixture", "browser fixture", "browser");
    await f.core.runs.tick();
    const path = `/v1/runs/${run.id}/watch`;
    const controlWs = { "Tailscale-User-Login": identity, Cookie: cookie, Origin: origin };
    expect(await upgrade(port, `${path}?from=0`, controlWs)).toBe(400);
    expect(await upgrade(port, `${path}?from=1&from=2`, controlWs)).toBe(400);
    expect((await http(port, `/v1/runs/${run.id}/abort`, "POST", [...browser, "Origin", "https://evil.fixture.ts.net"])).status).toBe(403);
    expect((await http(port, `/v1/runs/${run.id}/abort`, "POST", [...browser, "Origin", "https://app.fixture.ts.net:8443"])).status).toBe(403);
    const steer = { content: "authorized steering control", requestId: "authorized-steer" };
    expect((await http(port, `/v1/runs/${run.id}/steer`, "POST", [...browser, "Origin", origin, "Cookie", cookie], steer)).status).toBe(401);
    expect((await http(port, `/v1/runs/${run.id}/steer`, "POST", [...browser, "Origin", origin], steer)).status).toBe(200);
    expect(await upgrade(port, path, { "Tailscale-User-Login": identity, Cookie: cookie, Origin: "https://evil.fixture.ts.net" })).toBe(403);
    expect(await upgrade(port, path, { "Tailscale-User-Login": identity, Cookie: cookie })).toBe(403);
    expect(await upgrade(port, `${path}?token=${token}`, { "Tailscale-User-Login": identity, Cookie: cookie, Origin: origin })).toBe(400);
    const client = new WebSocket(`ws://127.0.0.1:${port}${path}`, { headers: { "Tailscale-User-Login": identity, Cookie: cookie, Origin: origin } });
    await new Promise<void>((resolve, reject) => { client.once("open", resolve); client.once("error", reject); });
    expect((await http(port, `/v1/runs/${run.id}/abort`, "POST", [...browser, "Origin", origin])).status).toBe(200);
    const closed = new Promise<void>((resolve) => client.once("close", () => resolve()));
    expect((await http(port, "/v1/browser/session", "DELETE", [...browser, "Origin", origin])).status).toBe(200);
    await closed; expect(client.readyState).toBe(WebSocket.CLOSED);
    expect((await http(port, "/v1/runs", "GET", browser)).status).toBe(401);
  } finally { await server.shutdown(); await f.cleanup(); }
});

test("session bounds, expiry and daemon restart revoke cookie credentials", async () => {
  const f = await fixture(); const token = randomBytes(32).toString("base64url");
  let now = Date.now(); const browser = new Browser(token, [identity], origin, undefined, () => now);
  const { createServer } = await import("node:http");
  const server = createServer((req, res) => { void browser.handle(req, res).then((handled) => { if (!handled) { res.writeHead(browser.authorize(req) ?? 200); res.end(); } }); });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as { port: number }).port;
  try {
    const auth = ["Tailscale-User-Login", identity, "X-Etabli-Client", "web-v1", "Origin", origin, "Authorization", `Bearer ${token}`];
    let cookie = "";
    for (let i = 0; i < 64; i++) { const value = await http(port, "/v1/browser/session", "POST", auth); expect(value.status).toBe(200); cookie = value.headers["set-cookie"]![0].split(";")[0]; }
    expect((await http(port, "/v1/browser/session", "POST", auth)).status).toBe(429);
    const headers = ["Tailscale-User-Login", identity, "X-Etabli-Client", "web-v1", "Cookie", cookie];
    expect((await http(port, "/v1/runs", "GET", headers)).status).toBe(200);
    now += 43_200_001;
    expect((await http(port, "/v1/runs", "GET", headers)).status).toBe(401);
    expect((await http(port, "/v1/browser/session", "POST", auth)).status).toBe(200);
    browser.close();
    expect((await http(port, "/v1/runs", "GET", headers)).status).toBe(401);
  } finally { browser.close(); await new Promise<void>((resolve) => server.close(() => resolve())); await f.cleanup(); }
});

test("web origin configuration fails closed and cannot enable test-only HTTP relaxation", () => {
  for (const webOrigin of ["http://localhost:1234", "https://fixture.invalid/", "https://fixture.invalid/path", "https://owner@fixture.invalid", "https://fixture.invalid?x=1", "https://fixture.invalid#x", "https://FIXTURE.invalid"]) expect(() => daemonConfig({ api: { port: 4318, identities: [identity], webOrigin } })).toThrow();
  expect(() => daemonConfig({ webOrigin: origin })).toThrow();
  expect(() => daemonConfig({ web: { origin } })).toThrow();
  expect(daemonConfig({ api: { port: 4318, identities: [identity], webOrigin: origin } }).api?.webOrigin).toBe(origin);
});

test("browser cookies use the actual S6 schedule contract with UTC due times, deletion tombstones and unchanged origin checks", async () => {
  const now = Date.UTC(2026, 10, 16, 8, 59, 30);
  const f = await fixture({ now: () => now });
  const token = randomBytes(32).toString("base64url");
  const server = await serveRemote(f.core, 0, token, [identity], { origin });
  const port = (server.address() as { port: number }).port;
  try {
    const login = await http(port, "/v1/browser/session", "POST", ["Tailscale-User-Login", identity, "Authorization", `Bearer ${token}`, "Origin", origin, "X-Etabli-Client", "web-v1"]);
    const cookie = login.headers["set-cookie"]![0].split(";")[0];
    const headers = ["Tailscale-User-Login", identity, "Cookie", cookie, "X-Etabli-Client", "web-v1", "Origin", origin];
    const input = { repo: "Tonours/fixture", prompt: "Browser schedule fixture", cron: "0 9 * * 1-5", requestId: "browser-schedule" };
    const created = await http(port, "/v1/schedules", "POST", headers, input);
    expect(created.status).toBe(200);
    const schedule = JSON.parse(created.text).value;
    expect(schedule).toMatchObject({ ...input, nextDue: Date.UTC(2026, 10, 16, 9), createdAt: now });
    expect(JSON.parse((await http(port, "/v1/schedules", "GET", headers)).text).value).toEqual([schedule]);
    expect(JSON.parse((await http(port, "/v1/schedules", "POST", headers, input)).text).value.id).toBe(schedule.id);
    expect((await http(port, "/v1/schedules", "POST", headers, { ...input, prompt: "conflicting retry" })).status).toBe(400);
    expect((await http(port, "/v1/schedules", "POST", headers, { ...input, requestId: "invalid-cron", cron: "impossible" })).status).toBe(400);
    expect((await http(port, "/v1/schedules", "POST", headers.slice(0, -2), input)).status).toBe(403);
    const foreign = headers.map((value) => value === origin ? "https://evil.fixture.ts.net" : value);
    for (const method of ["GET", "POST", "DELETE"]) {
      const path = method === "DELETE" ? `/v1/schedules/${schedule.id}` : "/v1/schedules";
      expect((await http(port, path, method, foreign, method === "POST" ? input : undefined)).status).toBe(403);
    }
    expect(JSON.parse((await http(port, `/v1/schedules/${schedule.id}`, "DELETE", headers)).text).value).toEqual({ deleted: true });
    expect(JSON.parse((await http(port, `/v1/schedules/${schedule.id}`, "DELETE", headers)).text).value).toEqual({ deleted: false });
    expect((await http(port, "/v1/schedules", "POST", headers, input)).status).toBe(400);
    expect(JSON.parse((await http(port, "/v1/schedules", "GET", headers)).text).value).toEqual([]);
    expect((await http(port, "/v1/schedules", "PUT", headers)).status).toBe(405);
  } finally { await server.shutdown(); await f.cleanup(); }
});

for (const web of [undefined, { origin }]) test(`remote CLI keeps original refusal messages (web=${!!web})`, async () => {
  const f = await fixture(), token = randomBytes(32).toString("base64url");
  const server = await serveRemote(f.core, 0, token, [identity], web);
  const port = (server.address() as { port: number }).port;
  try {
    if (!web) expect(await http(port, "/v1/runs", "GET", ["Tailscale-User-Login", identity])).toMatchObject({ status: 401, text: '{"error":"Bearer token required"}' });
    if (web) expect(await http(port, "/v1/runs", "GET", ["Tailscale-User-Login", identity])).toMatchObject({ status: 403, text: '{"error":"Authorization refused"}' });
    expect(await http(port, "/v1/runs", "GET", ["Tailscale-User-Login", identity, "Authorization", `Bearer ${"A".repeat(43)}`])).toMatchObject({ status: 401, text: '{"error":"Bearer token required"}' });
    expect(await http(port, "/v1/runs", "GET", ["Authorization", `Bearer ${token}`])).toMatchObject({ status: 403, text: '{"error":"Identity refused"}' });
    expect((await http(port, "/v1/runs", "GET", ["Tailscale-User-Login", identity, "Authorization", `Bearer ${token}`])).status).toBe(200);
  } finally { await server.shutdown(); await f.cleanup(); }
});

test("documented generic notifications survive control-session logout until explicitly disabled", async () => {
  const f = await fixture(), token = randomBytes(32).toString("base64url");
  let sent = 0;
  const original = await Push.open(f.core.harness, f.state, origin, [identity]);
  const push = new Push(f.core.harness, original.key, origin, [identity], async () => { sent++; return 201; });
  const server = await serveRemote(f.core, 0, token, [identity], { origin, push });
  const port = (server.address() as { port: number }).port;
  try {
    const auth = ["Tailscale-User-Login", identity, "Authorization", `Bearer ${token}`, "Origin", origin, "X-Etabli-Client", "web-v1"];
    const login = await http(port, "/v1/browser/session", "POST", auth);
    const cookie = login.headers["set-cookie"]![0].split(";")[0], headers = ["Tailscale-User-Login", identity, "X-Etabli-Client", "web-v1", "Origin", origin, "Cookie", cookie];
    const subscription = { endpoint: "https://fcm.googleapis.com/fcm/send/persistent-fixture" };
    expect((await http(port, "/v1/push/subscriptions", "POST", headers, subscription)).status).toBe(200);
    expect((await http(port, "/v1/browser/session", "DELETE", headers)).status).toBe(200);
    expect((await http(port, "/v1/push/subscriptions", "DELETE", headers, subscription)).status).toBe(401);
    await acceptedPush(push.notify()); expect(sent).toBe(1);
    expect((await http(port, "/v1/push/subscriptions", "DELETE", auth, subscription)).status).toBe(200);
    await acceptedPush(push.notify()); expect(sent).toBe(1);
  } finally { await server.shutdown(); await f.cleanup(); }
});
