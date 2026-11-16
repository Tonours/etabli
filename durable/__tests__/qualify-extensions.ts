import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { homedir, hostname, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { createModels, type JsonObject, type TranscriptContext } from "@earendil-works/pi-ai";
import { fauxAssistantMessage, fauxProvider, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { zaiProvider } from "@earendil-works/pi-ai/providers/zai";
import { AgentDoc, type AgentState, type Conversation, type EntryRecord } from "@earendil-works/pi-durable";
import { checkout, openCore, type Core } from "../src/daemon.ts";
import { serve, type ApiServer } from "../src/api.ts";
import { request } from "../src/client.ts";
import { SharedCredentialStore } from "../src/credentials.ts";
import { ChildOwnerDoc } from "../src/guards.ts";
import { OwnerPolicy } from "../src/policy.ts";
import { Repositories } from "../src/repositories.ts";
import { subagentModel } from "../src/subagents.ts";
import { localRepo, until } from "./helpers.ts";

const head = () => execFileSync("git", ["-C", checkout, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
const hash = (value: unknown) => createHash("sha256").update(JSON.stringify(value)).digest("hex");
const exited = (pid: number) => { try { process.kill(pid, 0); return false; } catch { return true; } };
const inventory = (input: TranscriptContext) => input.messages.flatMap((message) => message.role === "system" ? (message.toolsAdded ?? []).map((tool) => tool.name) : []);

async function output(path: string, value: unknown) {
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
}

async function runtime() {
  assert.equal(Number(process.versions.node.split(".")[0]), 26, "Use Node 26");
  const version = JSON.parse(await readFile(join(checkout, "durable/node_modules/@earendil-works/pi-mcp/package.json"), "utf8")) as { version: string };
  assert.equal(version.version, "1.5.2");
  return { node: process.version, piMcp: version.version, head: head(), harnessSha256: createHash("sha256").update(await readFile(import.meta.filename)).digest("hex") };
}

export async function preflightExtensions(proofPath: string) {
  const versions = await runtime();
  const root = await mkdtemp(join(tmpdir(), "etabli-s7-preflight-"));
  let core: Core | undefined;
  let api: ApiServer | undefined;
  let pid = 0;
  try {
    const source = await localRepo(root);
    const state = join(root, "state");
    const policy = new OwnerPolicy(["ForestAdmin"]);
    const options = { state, policy, models: createModels(), repositories: new Repositories(state, policy, () => source, async (repo) => repo), mcpServers: { fixture: { command: process.execPath, args: [join(import.meta.dirname, "fixtures/mcp-server.ts")], env: { PID_FILE: join(root, "fixture.pid") } } } };
    core = await openCore(options);
    pid = Number(await readFile(join(root, "fixture.pid"), "utf8"));
    api = await serve(core, state);
    assert.deepEqual(await request(state, { op: "ls" }), []);
    await api.shutdown(); api = undefined;
    await core.close(); core = undefined;
    await until(async () => exited(pid));
    pid = 0;
    core = await openCore(options);
    pid = Number(await readFile(join(root, "fixture.pid"), "utf8"));
    assert.deepEqual(await core.runs.list(), []);
    const graph = await core.harness.watchTaskGraph(context);
    try { assert.equal(Object.keys(graph.value.tasks).length, 0); } finally { await graph.stop(); }
    await core.close(); core = undefined;
    await until(async () => exited(pid)); pid = 0;
    const routes = { scout: await subagentModel(checkout, "scout"), worker: await subagentModel(checkout, "worker") };
    assert.ok((await stat(join(homedir(), "work/alambic/_meta/mcp/server.mjs"))).isFile());
    assert.ok((await stat(join(homedir(), "work/obvault/kb/harness-engineering-integration-points.md"))).isFile());
    const browser = execFileSync("/usr/bin/chromium", ["--version"], { encoding: "utf8", timeout: 5000 }).trim();
    const proof = { mode: "preflight", qualificationAttempt: false, status: "complete", ...versions, routes, browser, emptyApi: true, reopenEmpty: true, zeroNativeTasks: true, fixturePidsExited: true, realModelsCalled: false, realMcpConnected: false, personalMcpPathsExist: true, productionTouched: false };
    await output(proofPath, proof);
    return proof;
  } finally {
    await api?.shutdown();
    await core?.close();
    if (pid && !exited(pid)) process.kill(pid, "SIGKILL");
    await rm(root, { recursive: true, force: true });
  }
}

export async function qualifyExtensions(evidence: string, reviewedHead: string, attempt: number) {
  const versions = await runtime();
  assert.equal(hostname(), "gromarchy");
  assert.match(reviewedHead, /^[a-f0-9]{40}$/);
  assert.equal(versions.head, reviewedHead, "Qualification requires the exact closing-reviewed head");
  assert.equal(execFileSync("git", ["-C", checkout, "status", "--porcelain"], { encoding: "utf8" }).trim(), "", "Qualification requires a clean reviewed checkout");
  assert.ok(attempt === 1 || attempt === 2, "Use the remaining program attempt number (1 or 2)");
  await mkdir(evidence, { recursive: false, mode: 0o700 });
  const source = await localRepo(evidence);
  const state = join(evidence, "state");
  const policy = new OwnerPolicy(["ForestAdmin"]);
  const parent = fauxProvider({ provider: "s7-root", models: [{ id: "s7-root" }] });
  const models = createModels({ credentials: new SharedCredentialStore(join(homedir(), ".pi/agent/auth.json")) });
  models.setProvider(parent.provider);
  models.setProvider(zaiProvider());
  const config = JSON.parse(await readFile(join(checkout, "durable/config.example.json"), "utf8")) as { mcpServers: Record<string, { command: string; args: string[]; timeout?: number }> };
  config.mcpServers["chrome-devtools"]!.args.push("--executablePath=/usr/bin/chromium");
  const runner = join(evidence, "mcp-owner.mjs");
  await writeFile(runner, `import {spawn} from 'node:child_process';
import {writeFile} from 'node:fs/promises';
const [pidFile, command, ...args] = process.argv.slice(2);
const child = spawn(command, args, {stdio:'inherit'});
child.once('error', () => process.exit(1));
child.once('exit', (code) => process.exit(code ?? 1));
await writeFile(pidFile, String(process.pid), {mode:0o600});
`, { mode: 0o600 });
  const pidFiles: string[] = [];
  for (const [name, server] of Object.entries(config.mcpServers)) {
    const pidFile = join(evidence, `${name}.pid`);
    pidFiles.push(pidFile);
    server.args = [runner, pidFile, server.command, ...server.args];
    server.command = process.execPath;
    server.timeout = 30;
  }
  const ownedPids = new Set<number>();
  const capture = async (pid: number): Promise<void> => {
    if (ownedPids.has(pid)) return;
    assert.ok(Number.isSafeInteger(pid) && pid > 1 && ownedPids.size < 256);
    ownedPids.add(pid);
    const text = await readFile(`/proc/${pid}/task/${pid}/children`, "utf8").catch((error: NodeJS.ErrnoException) => { if (error.code === "ENOENT") return ""; throw error; });
    for (const child of text.trim().split(/\s+/).filter(Boolean)) await capture(Number(child));
  };
  const steps: [string, JsonObject][] = [
    ["scout", { task: "Read check.sh with your read tool, then return scout-complete and a short summary. Do not write or use external services." }],
    ["worker", { task: "Use write to create qualification.txt containing exactly: s7 native worker followed by a newline. Return worker-complete. No other changes, shell commands, network, commits or publication." }],
    ["tool_search", { query: "mcp__alambic_obvault__vault_read", limit: 1 }],
    ["mcp__alambic_obvault__vault_read", { path: "kb/harness-engineering-integration-points.md", max_bytes: 128 }],
    ["tool_search", { query: "mcp__chrome_devtools__list_pages", limit: 1 }],
    ["mcp__chrome_devtools__list_pages", {}],
  ];
  let firstTools: string[] = [];
  parent.setResponses([...steps.map(([name, args], index) => async (input: TranscriptContext) => {
    if (index === 0) firstTools = inventory(input);
    return fauxAssistantMessage(fauxToolCall(name, args, { id: `s7-${index}` }), { stopReason: "toolUse" });
  }), fauxAssistantMessage("qualification complete")]);
  let core: Core | undefined;
  let api: ApiServer | undefined;
  let proof: Record<string, unknown> = { mode: "qualification", attempt, ...versions, status: "incomplete", productionTouched: false };
  try {
    core = await openCore({ state, policy, models, workflow: true, model: async () => ({ provider: "s7-root", modelId: "s7-root" }), repositories: new Repositories(state, policy, () => source, async (repo) => repo), mcpServers: config.mcpServers, wallMs: 180_000 });
    api = await serve(core, state);
    const run = await core.runs.submit("Tonours/fixture", "S7 isolated native qualification", "s7-ac15");
    await core.runs.tick();
    const conversation = (await core.harness.conversation(run.conversationId, context))!;
    await conversation.waitForIdle(context);
    assert.equal(firstTools.some((name) => name.startsWith("mcp__")), false);
    assert.ok(firstTools.includes("tool_search"));
    const entries = (await conversation.entries({ order: "ascending" }, 100, undefined, context)).items;
    const results = entries.flatMap((entry) => (entry.model ?? []).filter((message) => message.role === "toolResult"));
    for (const [name] of steps) assert.ok(results.some((result) => result.toolName === name && !result.isError), `Native tool did not succeed: ${name}`);
    const owned = (await core.harness.commit((tx) => tx.scanConversations({ ownerConversationId: run.conversationId }, 100), context)).items;
    assert.equal(owned.length, 2);
    const childEvidence = [];
    for (const child of owned) {
      assert.ok(child.owner?.taskId);
      assert.equal((await core.harness.snapshot(ChildOwnerDoc, child.id, context))?.parentId, run.conversationId);
      const agent: Readonly<AgentState> | undefined = await core.harness.snapshot(AgentDoc, child.id, context);
      const childConversation: Conversation = (await core.harness.conversation(child.id, context))!;
      const history: readonly EntryRecord[] = (await childConversation.entries({ order: "ascending" }, 100, undefined, context)).items;
      const requestTools = history.flatMap((entry) => (entry.model ?? []).flatMap((message) => message.role === "system" ? (message.toolsAdded ?? []).map((tool) => tool.name) : []));
      const messages = history.flatMap((entry) => (entry.model ?? []).filter((message) => message.role === "assistant"));
      const role = messages.some((message) => message.model === "glm-5.3-flash") ? "scout" : "worker";
      const expected = await subagentModel(checkout, role);
      assert.ok(messages.length > 0 && messages.every((message) => message.provider === expected.provider && message.model === expected.modelId));
      assert.deepEqual([...new Set(requestTools)].sort(), role === "scout" ? ["read"] : ["bash", "edit", "read", "write"]);
      assert.ok(agent?.extensions && Array.isArray(agent.extensions) && agent.extensions.includes("etabli-guards"));
      const rootResult = results.find((result) => result.toolName === role);
      const final = messages.at(-1)!.content.flatMap((part) => part.type === "text" ? [part.text] : []).join("\n");
      assert.ok(rootResult?.content.some((part) => part.type === "text" && part.text === final.slice(0, 32_000)));
      childEvidence.push({ role, route: expected, taskOwned: true, guard: true, tools: requestTools, resultSha256: hash(rootResult?.content) });
      await output(join(evidence, `${role}-entries.json`), history);
    }
    assert.equal(await readFile(join(run.worktree, "qualification.txt"), "utf8"), "s7 native worker\n");
    assert.equal(execFileSync("git", ["-C", run.worktree, "status", "--porcelain"], { encoding: "utf8" }).trim(), "?? qualification.txt", "Worker must leave only its authorized fixture file");
    const graph = await core.harness.watchTaskGraph(context);
    try { assert.equal(Object.keys(graph.value.tasks).length, 0); } finally { await graph.stop(); }
    await output(join(evidence, "root-entries.json"), entries);
    const expectedResults = results.map((result) => ({ name: result.toolName, isError: result.isError, contentSha256: hash(result.content) }));
    proof = { ...proof, status: "checks_passed", firstTools, children: childEvidence, results: expectedResults, workerFile: true, zeroNativeTasks: true };
  } finally {
    try {
      for (const path of pidFiles) {
        const pid = await readFile(path, "utf8").catch((error: NodeJS.ErrnoException) => { if (error.code === "ENOENT") return ""; throw error; });
        if (pid) await capture(Number(pid));
      }
    } finally {
      try { await api?.shutdown(); }
      finally { try { await core?.close(); } finally { await output(join(evidence, "proof.json"), proof); } }
    }
  }
  const socketGone = await stat(join(state, "daemon.sock")).then(() => false, () => true);
  assert.ok(socketGone, "Unix socket must be released on shutdown");
  await until(async () => [...ownedPids].every(exited), 10_000);
  proof = { ...proof, status: "complete", socketReleased: true, coreClosed: true, mcpAndBrowserPidsExited: [...ownedPids] };
  await output(join(evidence, "proof.json"), proof);
  return proof;
}

if (import.meta.main) {
  const [mode, destination, reviewedHead, attempt] = process.argv.slice(2);
  if (mode === "--preflight" && destination) console.log(JSON.stringify(await preflightExtensions(resolve(destination))));
  else if (mode === "--qualify" && destination && reviewedHead && attempt) console.log(JSON.stringify(await qualifyExtensions(resolve(destination), reviewedHead, Number(attempt))));
  else throw new Error("Use Node26: qualify-extensions.ts --preflight <proof.json>; after closing review only: --qualify <new-evidence-dir> <reviewed-head> <attempt1|2>");
}
