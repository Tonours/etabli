// Disposable HTTPS browser proof fixture. No credentials, default state or Serve access.
// Seeds one run per state the clients explain and opens the local socket for the TUI.
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { request } from "node:http";
import { createServer } from "node:https";
import { join } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { serve, serveRemote } from "../../src/api.ts";
import { RunsDoc, type Run } from "../../src/runs-doc.ts";
import { Push } from "../../src/push.ts";
import { fixture } from "../helpers.ts";

const f = await fixture({ workflow: true });
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
const call = (name: string, args: Record<string, string>) => fauxAssistantMessage(fauxToolCall(name, args), { stopReason: "toolUse" });
const untilAbort = async (_input: unknown, options?: { signal?: AbortSignal }) => { await new Promise<void>((resolve) => options?.signal?.addEventListener("abort", () => resolve(), { once: true })); return fauxAssistantMessage("Stopped by owner"); };
f.faux.setResponses([call("bash", { command: "for i in $(seq 1 40); do printf 'fixture streaming output %s\\n' \"$i\"; sleep 1; done; printf finished" }), untilAbort, untilAbort]);
f.planner.setResponses([call("plan_section", { section: "Goal", content: "Show the fixture plan in both clients." }), call("bash", { command: "sleep 3600" }), untilAbort]);
const run = await f.core.runs.submit("Tonours/fixture", "Browser fixture: <img src=x onerror=alert(1)> must remain text.", "browser-proof");
const planned = await f.core.runs.submit("Tonours/fixture", "Plan the attention-first list\nSecond line of the task.", "browser-plan", "plan");
await f.core.runs.submit("Tonours/dotfiles", "Queued fixture task waiting for a slot", "browser-queued");
const hour = 3_600_000, now = Date.now();
const ended: [Run["status"], string, string, number, string][] = [
  ["blocked", "ci_attempts_exhausted", "https://github.com/Tonours/fixture/pull/12", 0.2, "Fix the flaky CI job"],
  ["blocked", "review_block_limit", "", 1, "Refactor the run store"],
  ["blocked", "run_setup_failed", "", 3, "Add the export command"],
  ["blocked", "workflow_finished_without_publication", "", 20, "Document the deploy procedure"],
  ["blocked", "wall_clock_limit", "", 80, "Old blocked task outside the attention window"],
  ["done", "published", "https://github.com/Tonours/fixture/pull/11", 5, "Publish the release notes"],
  ["done", "answer", "", 30, "Legacy answer fixture"],
  ["aborted", "", "", 40, "Aborted fixture task"],
  ...Array.from({ length: 9 }, (_, index): [Run["status"], string, string, number, string] => ["done", "published", `https://github.com/Tonours/fixture/pull/${index + 1}`, 100 + 24 * index, `Older published task ${index + 1}`]),
];
await f.core.harness.commit(async (tx) => {
  const runs = (await tx.doc(RunsDoc)).runs;
  for (const [index, [status, reason, url, age, prompt]] of ended.entries()) {
    const conversation = await tx.createConversation({ ownership: { kind: "ownerless" } });
    const startedAt = now - age * hour, id = `00000000-0000-4000-8000-${String(index).padStart(12, "0")}`;
    runs.push({ id, requestId: `seed-${index}`, repo: index % 3 ? "Tonours/fixture" : "Tonours/dotfiles", prompt, conversationId: conversation.id, branch: `feat/durable-seed-${index}`, worktree: "", route: reason === "answer" ? "legacy" : "plan", status, reason, url, createdAt: startedAt - 60_000, startedAt: reason === "run_setup_failed" ? 0 : startedAt, deadline: startedAt + 4 * hour, maxTurns: 64, submissionId: "", notified: true });
  }
}, context);
const local = await serve(f.core, f.state);
const timer = setInterval(() => { void f.core.runs.tick(); }, 250);
console.log(JSON.stringify({ origin, runId: run.id, planRunId: planned.id, state: f.state, pid: process.pid }));
let closing = false;
const stop = async () => { if (closing) return; closing = true; clearInterval(timer); await api.shutdown(); await local.shutdown(); proxy.closeAllConnections(); await new Promise<void>((resolve) => proxy.close(() => resolve())); await f.cleanup(); process.exit(0); };
process.once("SIGTERM", () => void stop()); process.once("SIGINT", () => void stop());
