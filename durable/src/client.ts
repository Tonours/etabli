import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";
import { readToken } from "./auth.ts";
import { WebSocket } from "ws";
import { createConnection } from "node:net";
import type { ConversationView } from "@earendil-works/pi-durable";
import { join } from "node:path";

export type ApiRequest = { op: string; id?: string; repo?: string; prompt?: string; requestId?: string; content?: string; route?: string; cron?: string };

export function operationPath(body: ApiRequest): { method: string; path: string } {
  const id = encodeURIComponent(body.id ?? "");
  switch (body.op) {
    case "schedule-create": return { method: "POST", path: "/v1/schedules" };
    case "schedule-list": return { method: "GET", path: "/v1/schedules" };
    case "schedule-delete": return { method: "DELETE", path: `/v1/schedules/${id}` };
    case "run": return { method: "POST", path: "/v1/runs" };
    case "ls": return { method: "GET", path: "/v1/runs" };
    case "show": return { method: "GET", path: `/v1/runs/${id}` };
    case "plan": return { method: "GET", path: `/v1/runs/${id}/plan` };
    case "steer": case "abort": return { method: "POST", path: `/v1/runs/${id}/${body.op}` };
    default: throw new Error("Unknown API operation");
  }
}

export type Remote = { host: string; tokenFile: string };

async function connection(remote?: Remote) {
  const host = remote ? new URL(remote.host) : undefined;
  if (host && (host.protocol !== "https:" || host.username || host.password || host.search || host.hash || host.pathname !== "/")) throw new Error("Remote host must be an HTTPS origin");
  const token = remote ? await readToken(remote.tokenFile) : undefined;
  return { host, token };
}

export async function request(state: string, body: object, remote?: Remote, signal?: AbortSignal): Promise<unknown> {
  const operation = operationPath(body as ApiRequest);
  const { host, token } = await connection(remote);
  signal?.throwIfAborted();
  return new Promise((resolve, reject) => {
    const payload = operation.method === "POST" ? JSON.stringify(body) : undefined;
    const headers = { ...(payload ? { "content-type": "application/json", "content-length": Buffer.byteLength(payload) } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}) };
    const options = { signal, method: operation.method, path: operation.path, headers, ...(host ? { hostname: host.hostname, port: host.port || 443 } : { socketPath: join(state, "daemon.sock") }) };
    const outgoing = (host ? httpsRequest : httpRequest)(options, (response) => {
      let buffer = "";
      response.setEncoding("utf8");
      response.on("data", (chunk: string) => { buffer += chunk; if (Buffer.byteLength(buffer) > 16_000_000) response.destroy(new Error("Daemon response exceeds the client limit")); });
      response.on("error", reject);
      response.on("end", () => {
        try {
          const reply = JSON.parse(buffer) as { ok: boolean; value: unknown; error: string };
          if (response.statusCode !== 200 || !reply.ok) reject(new Error(reply.error ?? `API refused request (${response.statusCode})`)); else resolve(reply.value);
        } catch { reject(new Error("Invalid daemon response")); }
      });
    });
    outgoing.setTimeout(30_000, () => outgoing.destroy(new Error("Daemon request timed out")));
    outgoing.on("error", () => reject(new Error("Daemon unavailable; check the host or start the user service")));
    outgoing.end(payload);
  });
}

export async function watchRun(state: string, id: string, from: number | undefined, remote: Remote | undefined, signal: AbortSignal, value: (view: ConversationView) => void, closed: () => void): Promise<void> {
  const { host, token } = await connection(remote);
  signal.throwIfAborted();
  const path = `/v1/runs/${encodeURIComponent(id)}/watch${from === undefined ? "" : `?from=${from}`}`;
  const socket = new WebSocket(host ? `wss://${host.host}${path}` : `ws://localhost${path}`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
    ...(host ? {} : { createConnection: () => createConnection({ path: join(state, "daemon.sock") }) }),
    handshakeTimeout: 10_000, maxPayload: 4_000_000, followRedirects: false,
  });
  let ended = false;
  const dispose = () => {
    if (ended) return;
    ended = true;
    signal.removeEventListener("abort", dispose);
    socket.terminate();
    if (!signal.aborted) closed();
  };
  signal.addEventListener("abort", dispose, { once: true });
  socket.on("error", dispose);
  socket.on("close", dispose);
  socket.on("message", (data) => {
    if (ended || signal.aborted) return;
    try {
      const frame = JSON.parse(data.toString()) as { kind?: unknown; value?: ConversationView };
      const view = frame.value;
      if (frame.kind !== "value" || !view || !Array.isArray(view.entries) || !view.docs || typeof view.docs !== "object" || view.entries.some((entry) => !entry || !Number.isSafeInteger(entry.id) || entry.id < 1)) throw new Error("Invalid watch value");
      value(view);
    } catch { dispose(); }
  });
}

