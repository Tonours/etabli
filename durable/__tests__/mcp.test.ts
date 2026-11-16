import { expect, test } from "bun:test";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { createModels } from "@earendil-works/pi-ai";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { Harness, createRegistry, type Extension } from "@earendil-works/pi-durable";
import { MemoryStorage } from "@earendil-works/pi-durable/storage/memory";
import { createInMemoryTransportPair } from "@earendil-works/pi-mcp/testing";
import type { JsonRpcMessage } from "@earendil-works/pi-mcp";
import { mcpConfig, mcpStdio, openMcp } from "../src/mcp.ts";
import { daemonConfig } from "../src/daemon.ts";
import { fixture, until } from "./helpers.ts";

const call = (name: string, args: { [key: string]: string }) => fauxAssistantMessage(fauxToolCall(name, args), { stopReason: "toolUse" });
async function native(extension: Extension) {
  const registry = createRegistry(); registry.install(extension);
  const faux = fauxProvider({ provider: "fixture", models: [{ id: "fixture" }] });
  const models = createModels(); models.setProvider(faux.provider);
  const harness = await Harness.open(new MemoryStorage(), { models, registry, settings: { extensions: [extension], compaction: { enabled: false } } }, context);
  const root = await harness.root(context);
  await root.configure({ model: { provider: "fixture", modelId: "fixture" } }, context);
  return { harness, faux, root };
}
async function memoryServer(handler?: (message: JsonRpcMessage) => boolean) {
  const pair = createInMemoryTransportPair();
  const calls: string[] = [];
  let closed = false;
  pair.server.onClose(() => { closed = true; });
  pair.server.onMessage((message) => {
    if (handler?.(message)) return;
    if (!("method" in message) || !("id" in message)) return;
    const result = message.method === "initialize" ? { protocolVersion: "2025-11-25", capabilities: { tools: {} }, serverInfo: { name: "fixture", version: "1" } }
      : message.method === "tools/list" ? { tools: [{ name: "echo", description: "Echo fixture", inputSchema: { type: "object", properties: { text: { type: "string" } }, required: ["text"], additionalProperties: false } }] }
      : { content: [{ type: "text", text: "native MCP answer" }] };
    if (message.method === "tools/call") calls.push(String((message.params as { name?: string } | undefined)?.name));
    void pair.server.send({ jsonrpc: "2.0", id: message.id, result });
  });
  await pair.server.start();
  return { transport: pair.client, calls, get closed() { return closed; } };
}

test("native pi-mcp testing transport tools are deferred, searched, loaded, validated and callable", async () => {
  const server = await memoryServer();
  const bridge = await openMcp({ vault: { command: "fixture" } }, { transport: () => server.transport, report: () => {} });
  const n = await native(bridge.extension);
  try {
    let first: string[] = [];
    n.faux.setResponses([
      async (input) => { first = input.messages.flatMap((message) => message.role === "system" ? (message.toolsAdded ?? []).map((tool) => tool.name) : []); return call("tool_search", { query: "mcp__vault__echo" }); },
      call("mcp__vault__echo", { text: "hello" }), fauxAssistantMessage("done"),
    ]);
    await (await n.root.submit({ type: "input", content: "discover tools", requestId: "discover" }, context)).wait(context);
    expect(first).toEqual(["tool_search"]);
    expect(server.calls).toEqual(["echo"]);
    const entries = JSON.stringify((await n.root.entries({}, 100, undefined, context)).items);
    expect(entries).toContain("native MCP answer");
    expect(bridge.extension.tools?.find((tool) => tool.name === "mcp__vault__echo")?.replay).toBe("unsafe");
    n.faux.setResponses([call("mcp__vault__echo", { wrong: "schema" }), fauxAssistantMessage("done")]);
    await (await n.root.submit({ type: "input", content: "invalid args", requestId: "invalid" }, context)).wait(context);
    expect(server.calls).toHaveLength(1);
  } finally { await n.harness.close(context); await bridge.close(); }
  expect(server.closed).toBe(true);
});

test("a failed/disabled server is skipped independently and no config, exception or stderr marker is reported", async () => {
  const good = await memoryServer();
  const events: unknown[] = [];
  const marker = "s7-private-config-fixture-marker";
  const bridge = await openMcp({ good: { command: "good" }, bad: { command: marker, env: { SECRET: marker } }, disabled: { command: "disabled", enabled: false }, invalid: { command: 42 } }, {
    transport: (config) => { if (config.command !== "good") throw new Error(marker); return good.transport; },
    report: (event) => { events.push(event); },
  });
  try {
    expect(bridge.extension.tools?.some((tool) => tool.name === "mcp__good__echo")).toBe(true);
    expect(events).toContainEqual({ server: "good", status: "ready" });
    expect(events).toContainEqual({ server: "bad", status: "skipped" });
    expect(events).toContainEqual({ server: "invalid", status: "skipped" });
    expect(JSON.stringify(events)).not.toContain(marker);
  } finally { await bridge.close(); }
});

test("startup timeout is bounded, closes the hanging server and retains a healthy neighbor", async () => {
  const good = await memoryServer();
  const stalled = createInMemoryTransportPair();
  await stalled.server.start();
  let closed = false;
  stalled.server.onClose(() => { closed = true; });
  const started = Date.now();
  const bridge = await openMcp({ hang: { command: "hang", timeout: 1 }, good: { command: "good" } }, { transport: (config) => config.command === "hang" ? stalled.client : good.transport, report: () => {} });
  try {
    expect(Date.now() - started).toBeLessThan(3000);
    expect(closed).toBe(true);
    expect(bridge.extension.tools?.some((tool) => tool.name === "mcp__good__echo")).toBe(true);
  } finally { await bridge.close(); }
});

test("stdio forwards only PATH, HOME and configured env, hides stderr, and tears down its process", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-mcp-env-"));
  const old = process.env.ETABLI_S7_PARENT_MARKER;
  process.env.ETABLI_S7_PARENT_MARKER = "private-parent-marker";
  const events: unknown[] = [];
  const pidPath = join(root, "pid");
  const bridge = await openMcp({ fixture: { command: process.execPath, args: [join(import.meta.dirname, "fixtures/mcp-server.ts")], env: { MCP_MODE: "environment", CONFIGURED: "${HOME}/configured", PID_FILE: pidPath, STDERR_MARKER: "private-stderr-marker" } } }, { report: (event) => { events.push(event); } });
  const n = await native(bridge.extension);
  const pid = Number(await readFile(pidPath, "utf8"));
  try {
    n.faux.setResponses([call("tool_search", { query: "mcp__fixture__echo" }), call("mcp__fixture__echo", { text: "env" }), fauxAssistantMessage("done")]);
    await (await n.root.submit({ type: "input", content: "env", requestId: "env" }, context)).wait(context);
    const entries = (await n.root.entries({}, 100, undefined, context)).items;
    const output = entries.flatMap((entry) => (entry.model ?? []).flatMap((message) => message.role === "toolResult" && message.toolName === "mcp__fixture__echo" ? message.content.flatMap((part) => part.type === "text" ? [part.text] : []) : []));
    expect(JSON.parse(output.join(""))).toEqual({ parentMarker: null, configured: `${process.env.HOME}/configured`, home: process.env.HOME, path: process.env.PATH });
    expect(JSON.stringify(events)).not.toContain("private-");
  } finally {
    await n.harness.close(context); await bridge.close();
    if (old === undefined) delete process.env.ETABLI_S7_PARENT_MARKER; else process.env.ETABLI_S7_PARENT_MARKER = old;
    await until(async () => { try { process.kill(pid, 0); return false; } catch { return true; } });
    await rm(root, { recursive: true, force: true });
  }
});

test("daemon reopens with a configured server down after search loaded it and settles unavailable calls", async () => {
  const mcpServers = { fixture: { command: process.execPath, args: [join(import.meta.dirname, "fixtures/mcp-server.ts")] } };
  const f = await fixture({ mcpServers });
  try {
    f.faux.setResponses([call("tool_search", { query: "mcp__fixture__echo" }), fauxAssistantMessage("loaded")]);
    const run = await f.core.runs.submit("Tonours/fixture", "load", "reopen-mcp");
    await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
    mcpServers.fixture.command = "/nonexistent-etabli-s7-fixture";
    await f.reopen();
    f.faux.setResponses([call("mcp__fixture__echo", { text: "reopened" }), fauxAssistantMessage("done")]);
    const conversation = (await f.core.harness.conversation(run.conversationId, context))!;
    await (await conversation.submit({ type: "input", content: "reopened", requestId: "reopened" }, context)).wait(context);
    expect(JSON.stringify((await conversation.entries({}, 100, undefined, context)).items)).toContain("not available");
  } finally { await f.cleanup(); }
});

test("native abort cancels in-flight MCP request and drains task ownership", async () => {
  let calling = false;
  let canceled = false;
  const server = await memoryServer((message) => {
    if ("method" in message && message.method === "tools/call") { calling = true; return true; }
    if ("method" in message && message.method === "notifications/cancelled") canceled = true;
    return false;
  });
  const bridge = await openMcp({ fixture: { command: "fixture" } }, { transport: () => server.transport, report: () => {} });
  const n = await native(bridge.extension);
  try {
    n.faux.setResponses([call("tool_search", { query: "mcp__fixture__echo" }), call("mcp__fixture__echo", { text: "wait" })]);
    await n.root.submit({ type: "input", content: "cancel MCP", requestId: "cancel-mcp" }, context);
    await until(async () => calling);
    await n.root.abort(context, { background: true });
    await n.harness.waitForIdle(context);
    await until(async () => canceled);
    const graph = await n.harness.watchTaskGraph(context);
    try { expect(Object.keys(graph.value.tasks)).toHaveLength(0); } finally { graph.stop(); }
  } finally { await n.harness.close(context); await bridge.close(); }
});

test("config bounds, HOME-only expansion, exact package pin and isolated headless example", async () => {
  expect(daemonConfig({}).mcpServers).toEqual({});
  for (const value of [[], null, "bad", { "bad-name!": {} }, Object.fromEntries(Array.from({ length: 17 }, (_, i) => [`server${i}`, {}]))]) expect(() => mcpConfig(value)).toThrow("mcpServers");
  expect(() => mcpStdio({ command: "${UNSUPPORTED}/command" })).toThrow("Unsupported");
  const pkg = JSON.parse(await readFile(join(import.meta.dirname, "../package.json"), "utf8"));
  expect(pkg.dependencies["@earendil-works/pi-mcp"]).toBe("1.5.2");
  const example = JSON.parse(await readFile(join(import.meta.dirname, "../config.example.json"), "utf8"));
  expect(example.mcpServers["chrome-devtools"].args).toEqual(["--yes", "chrome-devtools-mcp@1.7.0", "--isolated", "--headless"]);
});


test("failed real stdio startup cannot expose argv, env or stderr markers", async () => {
  const marker = "s7-private-stdio-failure-marker";
  const events: unknown[] = [];
  const bridge = await openMcp({ broken: { command: process.execPath, args: [join(import.meta.dirname, "fixtures/mcp-server.ts"), marker], env: { MCP_MODE: "exit", SECRET: marker, STDERR_MARKER: marker } } }, { report: (event) => { events.push(event); } });
  try {
    expect(events).toEqual([{ server: "broken", status: "skipped" }]);
    expect(JSON.stringify(events)).not.toContain(marker);
    expect(bridge.extension.tools?.map((tool) => tool.name)).toEqual(["tool_search"]);
  } finally { await bridge.close(); }
});
