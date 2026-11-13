import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import subagents from "../../subagents.ts";

type Tool = { name: string; execute: (...args: unknown[]) => Promise<{ details: Record<string, unknown> }> };
const tools = new Map<string, Tool>();
const pi = { registerTool: (tool: Tool) => tools.set(tool.name, tool), on: () => undefined };
subagents(pi as unknown as ExtensionAPI);
const started = await tools.get("subagent")!.execute("call", { agent: "worker", task: "hang", background: true }, undefined, undefined, { cwd: process.cwd() });
const run = await tools.get("subagent_supervisor")!.execute("call", { action: "status", run_id: started.details.run_id }, undefined, undefined, { cwd: process.cwd() });
await new Promise((done) => setTimeout(done, 600));
console.log(JSON.stringify({ pgid: run.details.pgid }));
setInterval(() => undefined, 1000);
