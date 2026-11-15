import { expect, test } from "bun:test";
import { randomBytes } from "node:crypto";
import { request as httpRequest } from "node:http";
import { mkdtemp, readFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { createServer as createHttpsServer } from "node:https";
import { join } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { WebSocket } from "ws";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { LiveDoc, type ConversationView } from "@earendil-works/pi-durable";
import { dispatch, serve, serveRemote } from "../src/api.ts";
import { request } from "../src/cli.ts";
import { loadToken } from "../src/auth.ts";
import { fixture, until } from "./helpers.ts";

function http(port: number, headers: string[] = [], path = "/v1/runs", method = "GET", body?: string): Promise<{ status: number; text: string }> {
  return new Promise((resolve, reject) => {
    const outgoing = httpRequest({ hostname: "127.0.0.1", port, path, method, headers: ["Host", `127.0.0.1:${port}`, ...headers] }, (response) => {
      let text = "";
      response.setEncoding("utf8");
      response.on("data", (chunk: string) => { text += chunk; });
      response.on("end", () => resolve({ status: response.statusCode!, text }));
      response.on("error", reject);
    });
    outgoing.on("error", reject);
    outgoing.end(body);
  });
}

function upgrade(url: string, headers: Record<string, string | string[]>): Promise<number> {
  return new Promise((resolve, reject) => {
    const client = new WebSocket(url, { headers });
    client.on("error", reject);
    client.once("open", () => { client.close(); resolve(101); });
    client.once("unexpected-response", (_request, response) => { response.resume(); client.terminate(); resolve(response.statusCode!); });
  });
}

test("TCP never inherits local trust: both auth factors gate every HTTP request and WS upgrade", async () => {
  const f = await fixture();
  const token = randomBytes(32).toString("base64url");
  const server = await serveRemote(f.core, 0, token, ["owner@example.invalid"]);
  const port = (server.address() as { port: number }).port;
  const run = await f.core.runs.submit("Tonours/fixture", "auth fixture", "auth");
  try {
    const cases: [Record<string, string | string[]>, number][] = [
      [{}, 401],
      [{ "Tailscale-User-Login": "owner@example.invalid" }, 401],
      [{ Authorization: `Bearer ${randomBytes(32).toString("base64url")}`, "Tailscale-User-Login": "owner@example.invalid" }, 401],
      [{ Authorization: `Bearer ${token}` }, 403],
      [{ Authorization: `Bearer ${token}`, "Tailscale-User-Login": "foreign@example.invalid" }, 403],
      [{ Authorization: `Bearer ${token}`, "Tailscale-User-Login": ["owner@example.invalid", "foreign@example.invalid"] }, 403],
      [{ Authorization: [`Bearer ${token}`, `Bearer ${token}`], "Tailscale-User-Login": "owner@example.invalid" }, 401],
      [{ Authorization: `Bearer ${token}`, "Tailscale-User-Login": "owner@example.invalid" }, 200],
    ];
    for (const [headers, expected] of cases) {
      const raw = Object.entries(headers).flatMap(([name, value]) => (Array.isArray(value) ? value : [value]).flatMap((part) => [name, part]));
      const result = await http(port, raw);
      expect(result.status).toBe(expected);
      expect(result.text.includes(token)).toBe(false);
      expect(await upgrade(`ws://127.0.0.1:${port}/v1/runs/${run.id}/watch`, headers)).toBe(expected === 200 ? 101 : expected);
    }
    expect((await http(port, [], "/not-a-route")).status).toBe(401);
  } finally { await server.shutdown(); await f.cleanup(); }
});

test("Unix HTTP API serves the existing CLI and validates routes, input and schedules", async () => {
  const f = await fixture();
  const local = await serve(f.core, f.state);
  const token = randomBytes(32).toString("base64url");
  const remote = await serveRemote(f.core, 0, token, ["owner@example.invalid"]);
  const port = (remote.address() as { port: number }).port;
  const headers = ["Authorization", `Bearer ${token}`, "Tailscale-User-Login", "owner@example.invalid", "Content-Type", "application/json"];
  try {
    expect((await stat(join(f.state, "daemon.sock"))).mode & 0o777).toBe(0o600);
    const run = await request(f.state, { op: "run", repo: "Tonours/fixture", prompt: "local", requestId: "local" }) as { id: string };
    expect((await request(f.state, { op: "ls" }) as unknown[]).length).toBe(1);
    expect(await request(f.state, { op: "plan", id: run.id })).toBeNull();
    expect((await request(f.state, { op: "show", id: run.id }) as { run: { id: string } }).run.id).toBe(run.id);
    expect(await request(f.state, { op: "abort", id: run.id })).toEqual({ aborted: true });
    expect((await http(port, headers, "/v1/schedules")).status).toBe(200);
    expect((await http(port, headers, "/v1/runs", "DELETE")).status).toBe(405);
    expect((await http(port, headers, "/v1/runs?token=not-accepted")).status).toBe(400);
    expect((await http(port, headers, "/v1/runs", "POST", "[]")).status).toBe(400);
    expect((await http(port, headers, "/v1/runs", "POST", "{")).status).toBe(400);
    await expect(request(f.state, { op: "run", repo: "Tonours/fixture", prompt: "bad", requestId: {} })).rejects.toThrow("must be strings");
    await expect(request(f.state, { op: "ls" }, { host: "http://example.invalid", tokenFile: "not-read" })).rejects.toThrow("HTTPS origin");
    expect(await upgrade(`ws://127.0.0.1:${port}/v1/runs/${run.id}/watch?from=0`, { Authorization: `Bearer ${token}`, "Tailscale-User-Login": "owner@example.invalid" })).toBe(400);
  } finally { await local.shutdown(); await remote.shutdown(); await f.cleanup(); }
});

test("native busy watch resumes, steering follows the tool round, abort is idle, and shutdown closes clients", async () => {
  const f = await fixture();
  const server = await serve(f.core, f.state);
  let client: WebSocket | undefined;
  let resumed: WebSocket | undefined;
  const values: ConversationView[] = [];
  try {
    f.faux.setResponses([
      fauxAssistantMessage(fauxToolCall("bash", { command: "printf started > started; sleep 0.3; printf finished" }), { stopReason: "toolUse" }),
      async (_input, options) => {
        await new Promise<void>((resolve) => options?.signal?.addEventListener("abort", () => resolve(), { once: true }));
        return fauxAssistantMessage("aborted");
      },
    ]);
    const run = await f.core.runs.submit("Tonours/fixture", "watch", "watch");
    client = new WebSocket(`ws+unix://${join(f.state, "daemon.sock") }:/v1/runs/${run.id}/watch`);
    client.on("message", (data) => values.push((JSON.parse(String(data)) as { value: ConversationView }).value));
    await new Promise<void>((resolve, reject) => { client!.once("open", resolve); client!.once("error", reject); });
    await f.core.runs.tick();
    await until(() => stat(join(run.worktree, "started")).then(() => true, () => false));
    await request(f.state, { op: "steer", id: run.id, content: "steer after round", requestId: "steer" });
    await until(async () => values.some((view) => view.entries.some((entry) => entry.kind === "pi.user" && JSON.stringify(entry).includes("steer after round"))));
    const entries = values.at(-1)!.entries;
    const tool = entries.findIndex((entry) => entry.kind === "pi.tool-result");
    const steer = entries.findIndex((entry) => entry.kind === "pi.user" && JSON.stringify(entry).includes("steer after round"));
    expect(tool).toBeGreaterThanOrEqual(0);
    expect(steer).toBeGreaterThan(tool);
    const from = entries.at(-1)!.id;
    const frames: ConversationView[] = [];
    resumed = new WebSocket(`ws+unix://${join(f.state, "daemon.sock")}:/v1/runs/${run.id}/watch?from=${from}`);
    resumed.on("message", (data) => frames.push((JSON.parse(String(data)) as { value: ConversationView }).value));
    await new Promise<void>((resolve, reject) => { resumed!.once("open", resolve); resumed!.once("error", reject); });
    await until(async () => frames.length > 0);
    expect(frames[0].entries.every((entry) => entry.id >= from)).toBe(true);
    expect(frames[0].entries.some((entry) => entry.id === from)).toBe(true);
    expect(await request(f.state, { op: "abort", id: run.id })).toEqual({ aborted: true });
    expect((await f.core.harness.snapshot(LiveDoc, run.conversationId, context))?.run).toBeUndefined();
    const graph = await f.core.harness.watchTaskGraph(context);
    expect(Object.values(graph.value.tasks).filter((task) => task.conversationId === run.conversationId)).toHaveLength(0);
    await graph.stop();
    const closed = new Promise<void>((resolve) => client!.once("close", () => resolve()));
    await server.shutdown();
    await closed;
    expect(client.readyState).toBe(WebSocket.CLOSED);
  } finally { client?.terminate(); resumed?.terminate(); if (server.listening) await server.shutdown(); await f.cleanup(); }
});

test("disconnect, rejected handshake and oversized native views release their watches", async () => {
  const f = await fixture();
  const token = randomBytes(32).toString("base64url");
  let watching = 0;
  const conversation = f.core.harness.conversation.bind(f.core.harness);
  Object.assign(f.core.harness, { conversation: async (...args: Parameters<typeof conversation>) => {
    const record = await conversation(...args);
    if (!record) return record;
    const original = record.watch.bind(record);
    Object.assign(record, { watch: async (...args: Parameters<typeof original>) => {
      const watch = await original(...args);
      watching++;
      const stop = watch.stop.bind(watch);
      let stopped = false;
      Object.assign(watch, { stop: () => { if (!stopped) { stopped = true; watching--; } return stop(); } });
      return watch;
    } });
    return record;
  } });
  const server = await serveRemote(f.core, 0, token, ["owner@example.invalid"]);
  const port = (server.address() as { port: number }).port;
  const headers = { Authorization: `Bearer ${token}`, "Tailscale-User-Login": "owner@example.invalid" };
  const run = await f.core.runs.submit("Tonours/fixture", "cleanup", "cleanup");
  let client: WebSocket | undefined;
  try {
    client = new WebSocket(`ws://127.0.0.1:${port}/v1/runs/${run.id}/watch`, { headers });
    await new Promise<void>((resolve, reject) => { client!.once("open", resolve); client!.once("error", reject); });
    expect(watching).toBe(1);
    client.close();
    await until(async () => watching === 0);
    const malformed = ["Authorization", `Bearer ${token}`, "Tailscale-User-Login", "owner@example.invalid", "Connection", "Upgrade", "Upgrade", "websocket", "Sec-WebSocket-Version", "13", "Sec-WebSocket-Key", "invalid"];
    expect((await http(port, malformed, `/v1/runs/${run.id}/watch`)).status).toBe(400);
    await until(async () => watching === 0);
    f.faux.setResponses([fauxAssistantMessage("x".repeat(4_000_001))]);
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    client = new WebSocket(`ws://127.0.0.1:${port}/v1/runs/${run.id}/watch`, { headers });
    client.on("error", () => undefined);
    await new Promise<void>((resolve) => client!.once("close", () => resolve()));
    expect(client.readyState).toBe(WebSocket.CLOSED);
    await until(async () => watching === 0);
  } finally { client?.terminate(); await server.shutdown(); await f.cleanup(); }
});

test("native bounded window exposes a gap on a resume older than retained history", async () => {
  const f = await fixture();
  const server = await serve(f.core, f.state);
  let client: WebSocket | undefined;
  try {
    f.faux.setResponses(Array.from({ length: 55 }, () => fauxAssistantMessage(fauxToolCall("bash", { command: "true" }), { stopReason: "toolUse" })));
    const run = await f.core.runs.submit("Tonours/fixture", "window", "window");
    await f.core.runs.tick();
    await f.core.harness.waitForIdle(context);
    const frames: ConversationView[] = [];
    client = new WebSocket(`ws+unix://${join(f.state, "daemon.sock")}:/v1/runs/${run.id}/watch?from=1`);
    client.on("message", (data) => frames.push((JSON.parse(String(data)) as { value: ConversationView }).value));
    await new Promise<void>((resolve, reject) => { client!.once("open", resolve); client!.once("error", reject); });
    await until(async () => frames.length > 0);
    expect(frames[0].entries.length).toBeLessThanOrEqual(100);
    expect(frames[0].before).toBeDefined();
  } finally { client?.terminate(); await server.shutdown(); await f.cleanup(); }
});

test("upgrade accepts only the resume query and refuses a token in its URL", async () => {
  const f = await fixture();
  const token = randomBytes(32).toString("base64url");
  const server = await serveRemote(f.core, 0, token, ["owner@example.invalid"]);
  const port = (server.address() as { port: number }).port;
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "query fixture", "query");
    const headers = { Authorization: `Bearer ${token}`, "Tailscale-User-Login": "owner@example.invalid" };
    const url = `ws://127.0.0.1:${port}/v1/runs/${run.id}/watch`;
    expect(await upgrade(`${url}?from=5`, headers)).toBe(101);
    expect(await upgrade(`${url}?token=not-accepted&from=5`, headers)).toBe(400);
    expect(await upgrade(`${url}?from=1e30`, headers)).toBe(400);
  } finally { await server.shutdown(); await f.cleanup(); }
});

test("transport retains the previously accepted long French prompt domain", async () => {
  const f = await fixture();
  const server = await serve(f.core, f.state);
  try {
    const prompt = "é".repeat(63_999);
    expect((await f.core.runs.submit("Tonours/fixture", prompt, "native-french")).prompt.length).toBe(63_999);
    expect((await request(f.state, { op: "run", repo: "Tonours/fixture", prompt: "a".repeat(63_999), requestId: "ascii" }) as { prompt: string }).prompt.length).toBe(63_999);
    await expect(request(f.state, { op: "run", repo: "Tonours/fixture", prompt: "a".repeat(64_001), requestId: "too-long" })).rejects.toThrow();
    const run = await request(f.state, { op: "run", repo: "Tonours/fixture", prompt, requestId: "http-french" }) as { prompt: string };
    expect(run.prompt.length).toBe(63_999);
  } finally { await server.shutdown(); await f.cleanup(); }
});

test("in-process plan dispatch keeps undefined while HTTP uses a JSON null", async () => {
  const f = await fixture();
  const server = await serve(f.core, f.state);
  try {
    const run = await f.core.runs.submit("Tonours/fixture", "no plan", "no-plan-contract");
    expect(await request(f.state, { op: "plan", id: run.id })).toBeNull();
    expect(await dispatch(f.core, { op: "plan", id: run.id })).toBeUndefined();
  } finally { await server.shutdown(); await f.cleanup(); }
});

test("remote CLI requires an explicitly named private token file", async () => {
  const f = await fixture();
  try {
    const result = await promisify(execFile)("node", [join(import.meta.dirname, "../src/cli.ts"), "--state", f.state, "--host", "https://127.0.0.1:1", "ls"], { timeout: 10_000 }).then(() => "unexpected success", (error: { stderr: string }) => error.stderr);
    expect(result).toContain("--host requires --token-file");
  } finally { await f.cleanup(); }
});

test("upgrade refusal on an already-ended socket does not emit an unhandled process error", async () => {
  const result = await promisify(execFile)("node", [join(import.meta.dirname, "fixtures/api-ended-upgrade.ts")], { timeout: 10_000 });
  expect(JSON.parse(result.stdout)).toEqual({ control: 200, unhandled: [] });
});

test("HTTP body cap and HTTPS host path refusals reach their real decision code", async () => {
  const f = await fixture();
  const token = randomBytes(32).toString("base64url");
  const server = await serveRemote(f.core, 0, token, ["owner@example.invalid"]);
  const port = (server.address() as { port: number }).port;
  const headers = ["Authorization", `Bearer ${token}`, "Tailscale-User-Login", "owner@example.invalid", "Content-Type", "application/json"];
  try {
    const input = { repo: "Tonours/fixture", prompt: "body bound", requestId: "body-bound" };
    expect((await http(port, headers, "/v1/runs", "POST", JSON.stringify(input))).status).toBe(200);
    const empty = JSON.stringify({ ...input, requestId: "oversized", padding: "" });
    const oversized = JSON.stringify({ ...input, requestId: "oversized", padding: "a".repeat(128_001 - empty.length) });
    expect(oversized.length).toBe(128_001);
    expect((await http(port, headers, "/v1/runs", "POST", oversized)).status).toBe(400);
    await expect(request(f.state, { op: "ls" }, { host: "https://example.invalid/path", tokenFile: "not-read" })).rejects.toThrow("HTTPS origin");
  } finally { await server.shutdown(); await f.cleanup(); }
});

test("remote CLI verifies TLS and refuses a redirect without resending its bearer", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-client-tls-"));
  const key = join(root, "key.pem");
  const cert = join(root, "cert.pem");
  const tokenFile = join(root, "token");
  let server: ReturnType<typeof createHttpsServer> | undefined;
  try {
    await promisify(execFile)("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", cert, "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1", "-days", "1"], { timeout: 10_000 });
    await loadToken(tokenFile);
    let redirect = false;
    let sources = 0;
    let destinations = 0;
    server = createHttpsServer({ key: await readFile(key), cert: await readFile(cert) }, (incoming, response) => {
      if (incoming.url !== "/v1/runs") { destinations++; response.writeHead(200).end("{}"); return; }
      sources++;
      response.writeHead(redirect ? 302 : 200, { "content-type": "application/json", ...(redirect ? { location: "/redirect-target" } : {}) });
      response.end(JSON.stringify({ ok: !redirect, ...(redirect ? {} : { value: [] }) }));
    });
    await new Promise<void>((resolve, reject) => { server!.once("error", reject); server!.listen(0, "127.0.0.1", resolve); });
    const port = (server.address() as { port: number }).port;
    const args = [join(import.meta.dirname, "../src/cli.ts"), "--state", root, "--host", `https://127.0.0.1:${port}`, "--token-file", tokenFile, "ls"];
    const options = { env: { ...process.env, NODE_EXTRA_CA_CERTS: cert }, timeout: 10_000 };
    const control = await promisify(execFile)("node", args, options);
    expect(JSON.parse(control.stdout)).toEqual([]);
    redirect = true;
    const refusal = await promisify(execFile)("node", args, options).then(() => "unexpected success", (error: { stderr: string }) => error.stderr);
    expect(refusal).toContain("API refused request (302)");
    expect(sources).toBe(2);
    expect(destinations).toBe(0);
  } finally {
    server?.closeAllConnections();
    await new Promise<void>((resolve) => server ? server.close(() => resolve()) : resolve());
    await rm(root, { recursive: true, force: true });
  }
}, 20_000);
