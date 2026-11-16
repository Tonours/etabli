// Disposable HTTPS browser proof fixture. No credentials, default state or Serve access.
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { request } from "node:http";
import { createServer } from "node:https";
import { join } from "node:path";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { serveRemote } from "../../src/api.ts";
import { Push } from "../../src/push.ts";
import { fixture } from "../helpers.ts";

const f = await fixture();
const key = join(f.root, "tls.key"), cert = join(f.root, "tls.pem");
execFileSync("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", cert, "-days", "1", "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1,DNS:localhost"], { stdio: "ignore" });
let port = 0;
const proxy = createServer({ key: await readFile(key), cert: await readFile(cert) }, (req, res) => {
  const outgoing = request({ hostname: "127.0.0.1", port, path: req.url, method: req.method, headers: { ...req.headers, "tailscale-user-login": "owner@example.invalid" } }, (response) => {
    res.writeHead(response.statusCode!, response.headers); response.pipe(res);
  });
  outgoing.on("error", () => { res.writeHead(502); res.end(); }); req.pipe(outgoing);
});
proxy.on("upgrade", (req, socket, head) => {
  const outgoing = request({ hostname: "127.0.0.1", port, path: req.url, method: req.method, headers: { ...req.headers, "tailscale-user-login": "owner@example.invalid" } });
  outgoing.on("upgrade", (response, upstream, upstreamHead) => {
    socket.write(`HTTP/1.1 101 Switching Protocols\r\n${Object.entries(response.headers).map(([name, value]) => `${name}: ${value}`).join("\r\n")}\r\n\r\n`);
    if (upstreamHead.length) socket.write(upstreamHead); if (head.length) upstream.write(head);
    socket.pipe(upstream).pipe(socket); socket.once("close", () => upstream.destroy()); upstream.once("close", () => socket.destroy());
  });
  outgoing.on("response", (response) => { response.resume(); socket.end(`HTTP/1.1 ${response.statusCode} Refused\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`); });
  outgoing.on("error", () => socket.destroy()); outgoing.end();
});
await new Promise<void>((resolve) => proxy.listen(0, "127.0.0.1", resolve));
const origin = `https://127.0.0.1:${(proxy.address() as { port: number }).port}`;
const push = await Push.open(f.core.harness, f.state, origin, ["owner@example.invalid"]);
// This public synthetic fixture value is deliberately not a real credential.
const api = await serveRemote(f.core, 0, "F".repeat(43), ["owner@example.invalid"], { origin, push });
port = (api.address() as { port: number }).port;
f.faux.setResponses([
  fauxAssistantMessage(fauxToolCall("bash", { command: "printf 'fixture streaming output'; sleep 1; printf ' finished'" }), { stopReason: "toolUse" }),
  async (_input, options) => { await new Promise<void>((resolve) => options?.signal?.addEventListener("abort", () => resolve(), { once: true })); return fauxAssistantMessage("Stopped by owner"); },
]);
const run = await f.core.runs.submit("Tonours/fixture", "Browser fixture: <img src=x onerror=alert(1)> must remain text.", "browser-proof");
const timer = setInterval(() => { void f.core.runs.tick(); }, 250);
console.log(JSON.stringify({ origin, runId: run.id, state: "temporary isolated fixture", pid: process.pid }));
let closing = false;
const stop = async () => { if (closing) return; closing = true; clearInterval(timer); await api.shutdown(); proxy.closeAllConnections(); await new Promise<void>((resolve) => proxy.close(() => resolve())); await f.cleanup(); process.exit(0); };
process.once("SIGTERM", () => void stop()); process.once("SIGINT", () => void stop());
