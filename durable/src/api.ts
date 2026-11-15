import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { chmod, unlink } from "node:fs/promises";
import { join } from "node:path";
import { Socket } from "node:net";
import { WebSocket, WebSocketServer } from "ws";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { AgentDoc, LiveDoc, type ConversationWatch, type EntryId } from "@earendil-works/pi-durable";
import { EtabliPlanDoc } from "./plan-doc.ts";
import type { Core } from "./daemon.ts";
import { remoteAuth } from "./auth.ts";
import type { ApiRequest } from "./client.ts";
export { operationPath, type ApiRequest } from "./client.ts";

function requiredText(value: unknown): string {
  if (typeof value !== "string") throw new Error("Request fields must be strings");
  return value;
}

export async function dispatch(core: Core, request: ApiRequest): Promise<unknown> {
  switch (request.op) {
    case "run": {
      if (request.route !== undefined && !["answer", "plan"].includes(request.route)) throw new Error("Run route must be answer or plan");
      return core.runs.submit(requiredText(request.repo), requiredText(request.prompt), requiredText(request.requestId), request.route as "answer" | "plan" | undefined);
    }
    case "plan": return core.harness.snapshot(EtabliPlanDoc, (await core.runs.show(requiredText(request.id))).conversationId, context);
    case "ls": return core.runs.list();
    case "show": {
      const run = await core.runs.show(requiredText(request.id));
      const conversation = await core.harness.conversation(run.conversationId, context);
      return { run, agent: await core.harness.snapshot(AgentDoc, run.conversationId, context), live: await core.harness.snapshot(LiveDoc, run.conversationId, context), entries: (await conversation?.entries({ order: "ascending" }, 1000, undefined, context))?.items ?? [] };
    }
    case "steer": return core.runs.steer(requiredText(request.id), requiredText(request.content), requiredText(request.requestId));
    case "abort": return { aborted: await core.runs.abort(requiredText(request.id)) };
    default: throw new Error("Unknown operation; use run, ls, show, plan, steer or abort");
  }
}

function respond(response: ServerResponse, status: number, value: unknown): void {
  if (response.destroyed) return;
  response.writeHead(status, { "content-type": "application/json", "cache-control": "no-store" });
  response.end(JSON.stringify(value));
}

async function bodyOf(request: IncomingMessage): Promise<Record<string, unknown>> {
  let body = "";
  request.setEncoding("utf8");
  for await (const chunk of request) {
    body += String(chunk);
    if (body.length > 128_000) throw new Error("Request exceeds 128000 UTF-16 units");
  }
  const parsed: unknown = JSON.parse(body || "{}");
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("Expected an object");
  const fields = parsed as Record<string, unknown>;
  if (["id", "repo", "prompt", "requestId", "content", "route"].some((key) => key in fields && typeof fields[key] !== "string")) throw new Error("Request fields must be strings");
  return fields;
}

export type ApiServer = Server & { shutdown(): Promise<void> };

function createApi(core: Core, authorize?: ReturnType<typeof remoteAuth>): ApiServer {
  const sockets = new WebSocketServer({ noServer: true, maxPayload: 1024, perMessageDeflate: false });
  const watches = new Map<WebSocket, ConversationWatch>();
  let closing = false;
  const server = createServer({ maxHeaderSize: 8192 }, (request, response) => {
    const status = authorize?.(request);
    if (status) { respond(response, status, { error: status === 401 ? "Bearer token required" : "Identity refused" }); request.resume(); return; }
    void (async () => {
      try {
        const url = new URL(request.url!, "http://local");
        if (url.search) { respond(response, 400, { error: "Unexpected query" }); return; }
        if (url.pathname === "/v1/schedules") { respond(response, 501, { error: "Schedules arrive in slice 6" }); return; }
        const match = url.pathname.match(/^\/v1\/runs(?:\/([a-f0-9-]{36})(?:\/(plan|steer|abort))?)?$/);
        if (!match) { respond(response, 404, { error: "API route not found" }); return; }
        const [, id, action] = match;
        const op = id ? (action ?? "show") : request.method === "POST" ? "run" : "ls";
        const method = ["run", "steer", "abort"].includes(op) ? "POST" : "GET";
        if (request.method !== method) { respond(response, 405, { error: "Method refused" }); return; }
        const body = method === "POST" ? await bodyOf(request) : {};
        const value = await dispatch(core, { ...body, op, id } as ApiRequest);
        respond(response, 200, { ok: true, value: value ?? null });
      } catch (error) {
        respond(response, error instanceof Error && error.message === "Run not found" ? 404 : 400, { ok: false, error: error instanceof Error ? error.message : "Request refused" });
      }
    })();
  });
  server.headersTimeout = 10_000;
  server.requestTimeout = 15_000;
  server.setTimeout(30_000, (socket) => socket.destroy());
  server.maxConnections = 128;
  server.on("upgrade", (request, socket, head) => {
    socket.on("error", () => socket.destroy());
    const refuse = (status: number) => {
      if (!socket.writable || socket.destroyed) { socket.destroy(); return; }
      socket.end(`HTTP/1.1 ${status} Refused\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`);
    };
    const status = authorize?.(request);
    if (status) { refuse(status); return; }
    void (async () => {
      try {
        const url = new URL(request.url!, "http://local");
        const match = url.pathname.match(/^\/v1\/runs\/([a-f0-9-]{36})\/watch$/);
        const from = url.searchParams.get("from");
        if (request.method !== "GET" || !match || [...url.searchParams.keys()].some((key) => key !== "from") || url.searchParams.getAll("from").length > 1 || from !== null && (!/^[1-9][0-9]*$/.test(from) || !Number.isSafeInteger(Number(from)))) { refuse(400); return; }
        if (closing || sockets.clients.size >= 64) { refuse(503); return; }
        const run = await core.runs.show(match[1]);
        const conversation = await core.harness.conversation(run.conversationId, context);
        if (!conversation) { refuse(404); return; }
        const watch = await conversation.watch(context, from === null ? undefined : { from: Number(from) as EntryId });
        if (closing || socket.destroyed) { await watch.stop(); socket.destroy(); return; }
        if (socket instanceof Socket) socket.setTimeout(0);
        let accepted = false;
        try {
          sockets.handleUpgrade(request, socket, head, (client) => {
            accepted = true;
            watches.set(client, watch);
            let alive = true;
            client.on("error", () => client.terminate());
            client.on("pong", () => { alive = true; });
            client.on("message", () => client.close(1008, "Watch is read-only"));
            const keepalive = setInterval(() => { if (!alive) client.terminate(); else { alive = false; client.ping(); } }, 20_000);
            keepalive.unref();
            client.once("close", () => { clearInterval(keepalive); watches.delete(client); void watch.stop(); });
            const send = (value: unknown) => {
              const text = JSON.stringify({ kind: "value", value });
              if (client.readyState !== WebSocket.OPEN) return;
              if (Buffer.byteLength(text) + client.bufferedAmount > 4_000_000) { client.terminate(); return; }
              client.send(text);
            };
            send(watch.value);
            watch.start(async (call) => { if (call.kind === "value") send(call.value); });
            void watch.closed.then(() => client.close(1001, "Watch ended"));
          });
        } finally { if (!accepted) await watch.stop(); }
      } catch { refuse(404); }
    })();
  });
  const release = async () => {
    closing = true;
    for (const client of sockets.clients) client.terminate();
    await Promise.all([...watches.values()].map((watch) => watch.stop()));
    sockets.close();
  };
  server.once("close", () => void release());
  return Object.assign(server, { async shutdown() {
    await release();
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  } });
}

export async function serve(core: Core, state: string): Promise<ApiServer> {
  const path = join(state, "daemon.sock");
  await unlink(path).catch((error: NodeJS.ErrnoException) => { if (error.code !== "ENOENT") throw error; });
  const server = createApi(core);
  await new Promise<void>((resolve, reject) => { server.once("error", reject); server.listen(path, resolve); });
  await chmod(path, 0o600);
  return server;
}

export async function serveRemote(core: Core, port: number, token: string, identities: readonly string[]): Promise<ApiServer> {
  const server = createApi(core, remoteAuth(token, identities));
  await new Promise<void>((resolve, reject) => { server.once("error", reject); server.listen(port, "127.0.0.1", resolve); });
  return server;
}
