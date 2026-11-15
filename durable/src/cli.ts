import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";
import { operationPath, type ApiRequest } from "./api.ts";
import { readToken } from "./auth.ts";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { daemon, defaultConfig, defaultState } from "./daemon.ts";
import { backup } from "./backup.ts";

export async function request(state: string, body: object, remote?: { host: string; tokenFile: string }): Promise<unknown> {
  const operation = operationPath(body as ApiRequest);
  const host = remote ? new URL(remote.host) : undefined;
  if (host && (host.protocol !== "https:" || host.username || host.password || host.search || host.hash || host.pathname !== "/")) throw new Error("Remote host must be an HTTPS origin");
  const token = remote ? await readToken(remote.tokenFile) : undefined;
  return new Promise((resolve, reject) => {
    const payload = operation.method === "POST" ? JSON.stringify(body) : undefined;
    const headers = { ...(payload ? { "content-type": "application/json", "content-length": Buffer.byteLength(payload) } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}) };
    const options = { method: operation.method, path: operation.path, headers, ...(host ? { hostname: host.hostname, port: host.port || 443 } : { socketPath: join(state, "daemon.sock") }) };
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

async function main(args: string[]): Promise<void> {
  let state = defaultState();
  let config = defaultConfig();
  let host: string | undefined;
  let tokenFile: string | undefined;
  let requestId: string = randomUUID();
  let repo = "";
  let route: "answer" | "plan" = "answer";
  const positional: string[] = [];
  for (let index = 0; index < args.length; index++) {
    const value = args[index];
    if (["--state", "--config", "--request-id", "--repo", "--host", "--token-file"].includes(value)) {
      const next = args[++index];
      if (!next) throw new Error(`Missing value for ${value}`);
      if (value === "--state") state = next;
      if (value === "--config") config = next;
      if (value === "--request-id") requestId = next;
      if (value === "--repo") repo = next;
      if (value === "--host") host = next;
      if (value === "--token-file") tokenFile = next;
    } else if (value === "--plan") route = "plan";
    else positional.push(value);
  }
  const [op, ...rest] = positional;
  if (host && !tokenFile) throw new Error("--host requires --token-file");
  if (op === "daemon") return daemon(state, config);
  if (op === "backup") { console.log(await backup(state)); return; }
  if (!["run", "ls", "show", "plan", "steer", "abort"].includes(op)) throw new Error("Usage: etabli-durable [--state PATH] [--host HTTPS_ORIGIN --token-file PATH] run [--plan] --repo OWNER/REPO TASK | ls | show ID | plan ID | steer ID TEXT | abort ID | daemon | backup");
  const body = op === "run" ? { op, repo, prompt: rest.join(" "), requestId, route } : op === "steer" ? { op, id: rest[0], content: rest.slice(1).join(" "), requestId } : { op, id: rest[0] };
  console.log(JSON.stringify(await request(state, body, host && tokenFile ? { host, tokenFile } : undefined), null, 2));
}

if (import.meta.main) void main(process.argv.slice(2)).catch((error) => { console.error(error instanceof Error ? error.message : "Durable command failed"); process.exitCode = 1; });
