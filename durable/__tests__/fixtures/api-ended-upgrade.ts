import { Socket } from "node:net";
import { IncomingMessage } from "node:http";
import { randomBytes } from "node:crypto";
import { setTimeout } from "node:timers/promises";
import { fixture } from "../helpers.ts";
import { serveRemote } from "../../src/api.ts";

const f = await fixture();
const token = randomBytes(32).toString("base64url");
const server = await serveRemote(f.core, 0, token, ["owner@example.invalid"]);
const errors: string[] = [];
const capture = (error: NodeJS.ErrnoException) => { errors.push(error.code ?? error.name); };
process.on("uncaughtException", capture);
try {
  const port = (server.address() as { port: number }).port;
  const control = await fetch(`http://127.0.0.1:${port}/v1/runs`, { headers: { authorization: `Bearer ${token}`, "tailscale-user-login": "owner@example.invalid" } });
  const socket = new Socket();
  socket.end();
  const request = new IncomingMessage(socket);
  request.url = "/v1/runs/00000000-0000-0000-0000-000000000000/watch";
  request.method = "GET";
  server.emit("upgrade", request, socket, Buffer.alloc(0));
  await setTimeout(30);
  console.log(JSON.stringify({ control: control.status, unhandled: errors }));
} finally {
  process.removeListener("uncaughtException", capture);
  await server.shutdown();
  await f.cleanup();
}
