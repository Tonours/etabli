import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { createModels } from "@earendil-works/pi-ai";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { Harness, createRegistry } from "@earendil-works/pi-durable";
import { MemoryStorage } from "@earendil-works/pi-durable/storage/memory";
import { openMcp } from "../../src/mcp.ts";

const [configPath, proofPath] = process.argv.slice(2);
assert.ok(configPath && proofPath);
const config = JSON.parse(await readFile(configPath, "utf8")) as { mcpServers: Record<string, unknown> };
assert.deepEqual(Object.keys(config.mcpServers).sort(), ["alambic-obvault", "chrome-devtools"]);
const cgroup = (await readFile("/proc/self/cgroup", "utf8")).trim().split("\n").find(line => line.startsWith("0::"))!.slice(3);
assert.ok(cgroup.includes("etabli-operations-preflight"));
const processes = async () => (await readFile(`/sys/fs/cgroup${cgroup}/cgroup.procs`, "utf8")).trim().split(/\s+/).map(Number).filter(pid => pid && pid !== process.pid);
const seen = new Set<number>();
let observing: Promise<void> = Promise.resolve();
const timer = setInterval(() => { observing = observing.then(async () => { for (const pid of await processes()) seen.add(pid); }); }, 20);
const events: { server: string; status: string }[] = [];
let harness: Harness | undefined;
let bridge: Awaited<ReturnType<typeof openMcp>> | undefined;
try {
  bridge = await openMcp(config.mcpServers, { report: event => events.push(event) });
  assert.equal(events.filter(event => event.status === "ready").length, 2);
  const registry = createRegistry(); registry.install(bridge.extension);
  const faux = fauxProvider({ provider: "fixture", models: [{ id: "fixture" }] });
  const models = createModels(); models.setProvider(faux.provider);
  harness = await Harness.open(new MemoryStorage(), { models, registry, settings: { extensions: [bridge.extension], compaction: { enabled: false } } }, context);
  const root = await harness.root(context); await root.configure({ model: { provider: "fixture", modelId: "fixture" } }, context);
  const steps: [string, Record<string, string | number>][] = [
    ["tool_search", { query: "mcp__alambic_obvault__vault_health" }], ["mcp__alambic_obvault__vault_health", {}],
    ["tool_search", { query: "mcp__alambic_obvault__vault_read" }], ["mcp__alambic_obvault__vault_read", { path: "kb/harness-engineering-integration-points.md", max_bytes: 128 }],
    ["tool_search", { query: "mcp__chrome_devtools__list_pages" }], ["mcp__chrome_devtools__list_pages", {}],
  ];
  faux.setResponses([...steps.map(([name, args]) => fauxAssistantMessage(fauxToolCall(name, args), { stopReason: "toolUse" })), fauxAssistantMessage("complete")]);
  await (await root.submit({ type: "input", content: "bounded read-only MCP preflight", requestId: "operations-preflight" }, context)).wait(context);
  const entries = (await root.entries({ order: "ascending" }, 100, undefined, context)).items;
  const results = entries.flatMap(entry => (entry.model ?? []).filter(message => message.role === "toolResult"));
  for (const [name] of steps) assert.ok(results.some(result => result.toolName === name && !result.isError), `Native tool failed: ${name}`);
  await harness.close(context); harness = undefined; await bridge.close(); bridge = undefined;
  const deadline = Date.now() + 3000;
  while ((await processes()).length && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 25));
  clearInterval(timer); await observing;
  assert.deepEqual(await processes(), []);
  await writeFile(proofPath, JSON.stringify({ pass: true, runtime: process.version, events, toolResults: results.map(result => ({ tool: result.toolName, ok: !result.isError })), observedProcesses: seen.size, remainingProcesses: 0, actualModelRequests: 0, productionRunCreated: false }, null, 2) + "\n", { mode: 0o600 });
  console.log("Native MCP preflight passed; owned process group empty");
} finally { clearInterval(timer); await observing; await harness?.close(context); await bridge?.close(); }
