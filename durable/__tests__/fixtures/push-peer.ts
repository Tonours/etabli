import { createServer, request } from "node:https";
import type { ServerResponse } from "node:http";
import type { Socket } from "node:net";
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { sendPush, type PushAdmission } from "../../src/push.ts";

export function acceptedPush(admission: PushAdmission) {
  if (admission.kind !== "accepted") throw new Error(`Expected admitted Push attempt, received ${admission.kind}`);
  return admission.done;
}

export function localPushSend(peer: Awaited<ReturnType<typeof pushPeer>>): typeof sendPush {
  return (url, headers, _transport, deadline, signal) => sendPush(url, headers, peer.transport, deadline, signal);
}

export async function pushPeer(root: string) {
  const key = join(root, "push-peer.key"), pem = join(root, "push-peer.pem");
  execFileSync("openssl", ["req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes", "-keyout", key, "-out", pem, "-days", "1", "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1"], { stdio: "ignore" });
  const cert = await readFile(pem), sockets = new Set<Socket>(), responses = new Set<ServerResponse>();
  const received: { connection?: string; ttl?: string; urgency?: string; bytes: number }[] = [];
  let peak = 0, peakSockets = 0, clients = 0, peakClients = 0;
  let answer: (ordinal: number) => number | undefined = () => 201;
  const server = createServer({ key: await readFile(key), cert }, (req, res) => {
    responses.add(res); peak = Math.max(peak, responses.size);
    res.once("close", () => responses.delete(res));
    const record = { connection: req.headers.connection, ttl: req.headers.ttl as string | undefined, urgency: req.headers.urgency as string | undefined, bytes: 0 };
    received.push(record);
    req.on("data", (chunk: Buffer) => { record.bytes += chunk.length; });
    req.on("end", () => { const status = answer(received.length); if (status !== undefined) { res.writeHead(status); res.end(); } });
  });
  server.on("connection", (socket) => { sockets.add(socket); peakSockets = Math.max(peakSockets, sockets.size); socket.once("close", () => sockets.delete(socket)); });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as { port: number }).port;
  const transport: Parameters<typeof sendPush>[2] = (_url, options, callback) => {
    const outgoing = request(`https://127.0.0.1:${port}/`, { ...options, ca: cert }, callback);
    clients++; peakClients = Math.max(peakClients, clients); outgoing.once("close", () => { clients--; });
    return outgoing;
  };
  return {
    transport, received, get peak() { return peak; }, get peakSockets() { return peakSockets; }, get live() { return responses.size; }, get liveSockets() { return sockets.size; }, get clients() { return clients; }, get peakClients() { return peakClients; },
    answer(fn: typeof answer) { answer = fn; },
    release(status = 201) { answer = () => status; for (const res of responses) if (!res.destroyed) { res.writeHead(status); res.end(); } },
    async close() { server.closeAllConnections(); for (const socket of sockets) socket.destroy(); await new Promise<void>((resolve) => server.close(() => resolve())); },
  };
}
