import { request } from "./client.ts";
export { request } from "./client.ts";
import { randomUUID } from "node:crypto";
import { daemon, defaultConfig, defaultState } from "./daemon.ts";
import { backup } from "./backup.ts";

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
  if (op === "tui") { const { tui } = await import("../tui/app.ts"); await tui(state, host && tokenFile ? { host, tokenFile } : undefined); return; }
  if (op === "daemon") return daemon(state, config);
  if (op === "backup") { console.log(await backup(state)); return; }
  if (!["run", "ls", "show", "plan", "steer", "abort"].includes(op)) throw new Error("Usage: etabli-durable [--state PATH] [--host HTTPS_ORIGIN --token-file PATH] run [--plan] --repo OWNER/REPO TASK | ls | show ID | plan ID | steer ID TEXT | abort ID | tui | daemon | backup");
  const body = op === "run" ? { op, repo, prompt: rest.join(" "), requestId, route } : op === "steer" ? { op, id: rest[0], content: rest.slice(1).join(" "), requestId } : { op, id: rest[0] };
  console.log(JSON.stringify(await request(state, body, host && tokenFile ? { host, tokenFile } : undefined), null, 2));
}

if (import.meta.main) void main(process.argv.slice(2)).catch((error) => { console.error(error instanceof Error ? error.message : "Durable command failed"); process.exitCode = 1; });
