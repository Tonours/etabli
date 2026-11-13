import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import subagents from "../../subagents.ts";

type Tool = { name: string; execute: (...args: unknown[]) => Promise<{ details: Record<string, unknown> }> };
const tools = new Map<string, Tool>();
const pi = { registerTool: (tool: Tool) => tools.set(tool.name, tool), on: () => undefined };
subagents(pi as unknown as ExtensionAPI);
const pgids: number[] = [];
for (let i = 0; i < Number(process.env.FAKE_PARENT_RUNS ?? 1); i += 1) {
	const started = await tools.get("subagent")!.execute("call", { agent: "worker", task: process.env.FAKE_PARENT_TASK ?? "hang", background: true }, undefined, undefined, { cwd: process.cwd() });
	const run = await tools.get("subagent_supervisor")!.execute("call", { action: "status", run_id: started.details.run_id }, undefined, undefined, { cwd: process.cwd() });
	pgids.push(run.details.pgid as number);
}
console.log(JSON.stringify({ pgid: pgids[0], pgids }));
setInterval(() => undefined, 1000);
