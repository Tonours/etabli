import { createConnection } from "node:net";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { daemon, defaultConfig, defaultState } from "./daemon.ts";
import { backup } from "./backup.ts";

export async function request(state: string, body: object): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const socket = createConnection(join(state, "daemon.sock"));
    let buffer = "";
    socket.setEncoding("utf8");
    socket.setTimeout(30_000, () => socket.destroy(new Error("Daemon request timed out")));
    socket.on("error", () => reject(new Error("Daemon unavailable; start the user service")));
    socket.on("connect", () => socket.write(`${JSON.stringify(body)}\n`));
    socket.on("data", (chunk: string) => { buffer += chunk; if (buffer.length > 16_000_000) socket.destroy(new Error("Daemon response exceeds the client limit")); });
    socket.on("end", () => {
      try {
        const reply = JSON.parse(buffer) as { ok: boolean; value: unknown; error: string };
        if (!reply.ok) reject(new Error(reply.error)); else resolve(reply.value);
      } catch { reject(new Error("Invalid daemon response")); }
    });
  });
}

async function main(args: string[]): Promise<void> {
  let state = defaultState();
  let config = defaultConfig();
  let requestId: string = randomUUID();
  let repo = "";
  const positional: string[] = [];
  for (let index = 0; index < args.length; index++) {
    const value = args[index];
    if (["--state", "--config", "--request-id", "--repo"].includes(value)) {
      const next = args[++index];
      if (!next) throw new Error(`Missing value for ${value}`);
      if (value === "--state") state = next;
      if (value === "--config") config = next;
      if (value === "--request-id") requestId = next;
      if (value === "--repo") repo = next;
    } else positional.push(value);
  }
  const [op, ...rest] = positional;
  if (op === "daemon") return daemon(state, config);
  if (op === "backup") { console.log(await backup(state)); return; }
  if (!["run", "ls", "show", "steer", "abort"].includes(op)) throw new Error("Usage: etabli-durable [--state PATH] run --repo OWNER/REPO TASK | ls | show ID | steer ID TEXT | abort ID | daemon | backup");
  const body = op === "run" ? { op, repo, prompt: rest.join(" "), requestId } : op === "steer" ? { op, id: rest[0], content: rest.slice(1).join(" "), requestId } : { op, id: rest[0] };
  console.log(JSON.stringify(await request(state, body), null, 2));
}

if (import.meta.main) void main(process.argv.slice(2)).catch((error) => { console.error(error instanceof Error ? error.message : "Durable command failed"); process.exitCode = 1; });
