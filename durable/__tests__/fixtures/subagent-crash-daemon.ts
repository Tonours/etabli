import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { createModels } from "@earendil-works/pi-ai";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { openCore } from "../../src/daemon.ts";
import { serve } from "../../src/api.ts";
import { OwnerPolicy } from "../../src/policy.ts";
import { Repositories } from "../../src/repositories.ts";

const [root, source, stage] = process.argv.slice(2) as [string, string, string];
const parent = fauxProvider({ provider: "parent", models: [{ id: "parent" }] });
const child = fauxProvider({ provider: "child", models: [{ id: "child" }] });
parent.setResponses(Array.from({ length: 8 }, () => async (input) => input.messages.some((message) => message.role === "toolResult" && message.toolName === "worker") ? fauxAssistantMessage("parent answer") : fauxAssistantMessage(fauxToolCall("worker", { task: "native crash child" }, { id: "worker-crash" }), { stopReason: "toolUse" })));
child.setResponses(Array.from({ length: 8 }, () => async (input, options) => {
  if (!input.messages.some((message) => message.role === "toolResult" && message.toolName === "bash")) return fauxAssistantMessage(fauxToolCall("bash", { command: "printf 'effect\\n' >> effects" }, { id: "child-effect" }), { stopReason: "toolUse" });
  await writeFile(join(root, "phase"), String(process.pid));
  if (stage === "initial") await new Promise<void>((resolve) => { if (options?.signal?.aborted) resolve(); else options?.signal?.addEventListener("abort", () => resolve(), { once: true }); });
  return fauxAssistantMessage("recovered child answer");
}));
const models = createModels(); models.setProvider(parent.provider); models.setProvider(child.provider);
const policy = new OwnerPolicy(["ForeignOrg"]);
const state = join(root, "state");
const core = await openCore({ state, policy, models, model: async () => ({ provider: "parent", modelId: "parent" }), subagentModel: async () => ({ provider: "child", modelId: "child" }), repositories: new Repositories(state, policy, () => source, async (repo) => repo), retry: { maxRetries: 2, baseDelayMs: 10 }, mcpServers: { fixture: { command: process.execPath, args: [join(import.meta.dirname, "mcp-server.ts")], env: { PID_FILE: join(root, "mcp-pid") } } } });
const api = await serve(core, state);
const timer = setInterval(() => { void core.runs.tick().catch(() => process.exit(1)); }, 30);
await writeFile(join(root, "ready"), String(process.pid));
process.once("SIGTERM", () => { clearInterval(timer); void api.shutdown().then(() => core.close()).then(() => process.exit(0)); });
