import { expect, test } from "bun:test";
import { createServer } from "node:http";
import { createServer as createHttpsServer } from "node:https";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { WebSocketServer } from "ws";
import { loadToken } from "../src/auth.ts";
import { TuiModel } from "../tui/model.ts";
import { fixture } from "./helpers.ts";

test("retry keeps the same steer identity and captured target despite a refreshed selection", async () => {
  const f = await fixture();
  const first = await f.core.runs.submit("Tonours/fixture", "first", "first");
  const second = await f.core.runs.submit("Tonours/fixture", "second", "second");
  const received: { requestId: string; content: string; path: string }[] = [];
  const server = createServer(async (req, res) => {
    if (req.method === "GET") { res.end(JSON.stringify({ ok: true, value: [first, second] })); return; }
    let body = "";
    for await (const chunk of req) body += String(chunk);
    received.push({ ...JSON.parse(body), path: req.url });
    res.writeHead(received.length === 1 ? 500 : 200).end(JSON.stringify({ ok: received.length > 1, value: true, error: "retry fixture" }));
  });
  await new Promise<void>((resolve) => server.listen(join(f.state, "daemon.sock"), resolve));
  const model = new TuiModel(f.state, undefined, () => {});
  try {
    await model.refresh();
    model.selectedId = first.id;
    model.mode = "run";
    model.begin("steer");
    model.draft = "retained draft";
    await model.send();
    expect(model.draft).toBe("retained draft");
    expect(model.error).toContain("Request failed");
    model.selectedId = second.id;
    await model.send();
    expect(received).toHaveLength(2);
    expect(received[0].requestId).toBe(received[1].requestId);
    expect(received[0].requestId).not.toBe("");
    expect(received.every((row) => row.path === `/v1/runs/${first.id}/steer`)).toBe(true);
    expect(model.draft).toBe("");
  } finally { model.close(); server.closeAllConnections(); await new Promise<void>((resolve) => server.close(() => resolve())); await f.cleanup(); }
});

test("WSS verifies TLS, sends only its bearer, resumes, and refuses upgrade redirects", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-watch-tls-"));
  const key = join(root, "key.pem");
  const cert = join(root, "cert.pem");
  const tokenFile = join(root, "token");
  let server: ReturnType<typeof createHttpsServer> | undefined;
  const ws = new WebSocketServer({ noServer: true });
  try {
    await promisify(execFile)("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", cert, "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1", "-days", "1"], { timeout: 10_000 });
    const token = await loadToken(tokenFile);
    server = createHttpsServer({ key: await readFile(key), cert: await readFile(cert) });
    let redirect = false;
    let sources = 0;
    let destinations = 0;
    const observations: { bearer: boolean; identity: boolean; cursor: boolean }[] = [];
    server.on("upgrade", (req, socket, head) => {
      socket.on("error", () => socket.destroy());
      if (req.url === "/destination") { destinations++; socket.destroy(); return; }
      sources++;
      observations.push({ bearer: req.headers.authorization === `Bearer ${token}`, identity: req.headers["tailscale-user-login"] !== undefined, cursor: req.url?.endsWith("?from=23") === true });
      if (redirect) { socket.end("HTTP/1.1 302 Found\r\nLocation: /destination\r\nContent-Length: 0\r\n\r\n"); return; }
      ws.handleUpgrade(req, socket, head, (client) => { client.on("error", () => client.terminate()); client.send(JSON.stringify({ kind: "value", value: { entries: [], docs: {} } })); });
    });
    await new Promise<void>((resolve) => server!.listen(0, "127.0.0.1", resolve));
    const host = `https://127.0.0.1:${(server.address() as { port: number }).port}`;
    const args = [join(import.meta.dirname, "fixtures/client-watch.ts"), host, tokenFile, "00000000-0000-4000-8000-000000000000"];
    const env = { ...process.env, NODE_EXTRA_CA_CERTS: cert };
    const control = await promisify(execFile)("node", args, { env, timeout: 10_000 });
    expect(JSON.parse(control.stdout)).toEqual({ result: "value" });
    redirect = true;
    const refused = await promisify(execFile)("node", args, { env, timeout: 10_000 });
    expect(JSON.parse(refused.stdout)).toEqual({ result: "closed" });
    expect(sources).toBe(2);
    expect(destinations).toBe(0);
    expect(observations).toEqual([{ bearer: true, identity: false, cursor: true }, { bearer: true, identity: false, cursor: true }]);
  } finally {
    for (const client of ws.clients) client.terminate();
    ws.close();
    server?.closeAllConnections();
    await new Promise<void>((resolve) => server ? server.close(() => resolve()) : resolve());
    await rm(root, { recursive: true, force: true });
  }
}, 20_000);
