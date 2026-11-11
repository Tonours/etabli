import { expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PI = process.env.GEMMA_PI_BIN ?? resolve(import.meta.dir, "../../../node_modules/.bin/pi");
const profile = resolve(import.meta.dir, "..");
type Call = { name: string; arguments: Record<string, unknown> };
interface Body { messages: { role: string; content?: string }[] }
const finish = { name: "finish_task", arguments: { status: "answer", claims: [], note: "fixture" } };

async function scenario(reply: (body: Body, n: number) => Call[] | string, extraArgs: string[] = []) {
  const root = await mkdtemp(join(tmpdir(), "gemma-native-"));
  let requests = 0;
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, async fetch(req) {
    const body = await req.json() as Body; const value = reply(body, ++requests);
    if (requests > 5) return new Response("Too many model requests", { status: 500 });
    const delta = typeof value === "string" ? { content: value } : {
      tool_calls: value.map((call, index) => ({ index, id: `call_${index}`, type: "function", function: { name: call.name, arguments: JSON.stringify(call.arguments) } })),
    };
    return new Response(`data: ${JSON.stringify({ choices: [{ index: 0, delta, finish_reason: typeof value === "string" ? "stop" : "tool_calls" }], usage: { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 } })}\n\ndata: [DONE]\n\n`, { headers: { "Content-Type": "text/event-stream" } });
  } });
  try {
    await writeFile(join(root, "models.json"), JSON.stringify({ providers: { fixture: { api: "openai-completions", apiKey: "public-unit-fixture", baseUrl: `http://127.0.0.1:${server.port}/v1`, models: [{ id: "fixture", name: "fixture", contextWindow: 32768, maxTokens: 1024, reasoning: false, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, compat: { supportsDeveloperRole: false, supportsReasoningEffort: false } }] } } }));
    await writeFile(join(root, "settings.json"), JSON.stringify({ retry: { enabled: false, maxRetries: 0 }, compaction: { enabled: false } }));
    const proc = Bun.spawn([PI, "--offline", "--no-extensions", "--no-mcp", "--no-skills", "--no-context-files", "--no-prompt-templates", "--no-builtin-tools", "--tools", "execute,read_file,write_file,open_page,finish_task", "-e", join(profile, "extension.ts"), "--system-prompt", join(profile, "system.md"), "--provider", "fixture", "--model", "fixture", "--session", join(root, "trace.jsonl"), "--mode", "json", "-p", "Run the fixture", ...extraArgs],
      { cwd: root, env: { ...process.env, PI_CODING_AGENT_DIR: root, PI_OFFLINE: "1" }, stdout: "pipe", stderr: "pipe" });
    const timeout = setTimeout(() => proc.kill(), 15000);
    const [stdout, stderr, exit] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text(), proc.exited]);
    clearTimeout(timeout);
    expect(exit, stderr).toBe(0);
    const entries = (await readFile(join(root, "trace.jsonl"), "utf8")).trim().split("\n").map((line) => JSON.parse(line) as { type: string; customType?: string; data?: { state?: string } });
    return { requests, stdout, root, entries, markerExists: await Bun.file(join(root, "SHOULD_NOT_EXIST")).exists() };
  } finally { server.stop(true); await rm(root, { recursive: true, force: true }); }
}

test("native accepted finish stops without another HTTP request", async () => {
  const result = await scenario(() => [finish]); expect(result.requests).toBe(1);
}, 20000);
test("finish then execute blocks the trailing effect and no new HTTP", async () => {
  const result = await scenario(() => [finish, { name: "execute", arguments: { command: "touch SHOULD_NOT_EXIST" } }]);
  expect(result.requests).toBe(1); expect(result.markerExists).toBe(false);
}, 20000);
test("execute then finish refuses premature completion and continues", async () => {
  const result = await scenario((_body, n) => n === 1 ? [{ name: "execute", arguments: { command: "printf evidence" } }, finish] : [finish]);
  expect(result.requests).toBe(2); expect(result.stdout).toContain("finish_alone");
}, 20000);
test("unknown then finish cannot pass as first completion", async () => {
  const result = await scenario((_body, n) => n === 1 ? [{ name: "unknown", arguments: {} }, finish] : [finish]);
  expect(result.requests).toBe(2); expect(result.stdout).toContain("finish_alone");
}, 20000);
test("invalid arguments then finish cannot pass as first completion", async () => {
  const result = await scenario((_body, n) => n === 1 ? [{ name: "execute", arguments: { command: 123 } }, finish] : [finish]);
  expect(result.requests).toBe(2); expect(result.stdout).toContain("finish_alone");
}, 20000);
test("unknown after accepted finish aborts without another HTTP", async () => {
  const result = await scenario(() => [finish, { name: "unknown", arguments: {} }]);
  expect(result.requests).toBe(1);
}, 20000);
test("malformed known call after accepted finish cannot relaunch HTTP", async () => {
  const result = await scenario(() => [finish, { name: "execute", arguments: { command: 123 } }]);
  expect(result.requests).toBe(1);
}, 20000);
test("two prose-only stops use one correction and finish unvalidated", async () => {
  const result = await scenario(() => "I am doing it now.");
  expect(result.requests).toBe(2); expect(result.stdout).toContain("gemma_validation");
  expect(result.entries.some((entry) => entry.customType === "gemma_status" && entry.data?.state === "unvalidated")).toBe(true);
}, 20000);
test("ninth call aborts without another HTTP request", async () => {
  const result = await scenario(() => Array.from({ length: 9 }, () => ({ name: "execute", arguments: { command: "printf ok" } })));
  expect(result.requests).toBe(1);
  expect(result.entries.some((entry) => entry.customType === "gemma_status" && entry.data?.state === "budget")).toBe(true);
}, 20000);
test("rejected completions share the one-correction budget with prose stops", async () => {
  for (const proseFirst of [false, true]) {
    const result = await scenario((_body, n) => proseFirst && n === 1 ? "I will do it now." : [{ name: "finish_task", arguments: { status: "done", claims: [], note: "invented" } }]);
    expect(result.requests).toBe(2);
    expect(result.entries.filter((entry) => entry.customType === "gemma_retry")).toHaveLength(1);
    expect(result.entries.some((entry) => entry.customType === "gemma_completion")).toBe(false);
    expect(result.entries.some((entry) => entry.customType === "gemma_status" && entry.data?.state === "unvalidated")).toBe(true);
  }
}, 20000);

test("invalid extension target never falls back to local execution", async () => {
  const result = await scenario(() => [{ name: "execute", arguments: { command: "touch SHOULD_NOT_EXIST" } }], ["--gemma-target", "host:22"]);
  expect(result.markerExists).toBe(false);
  expect(result.entries.some((entry) => entry.customType === "gemma_completion")).toBe(false);
  expect(result.entries.some((entry) => entry.customType === "gemma_status" && entry.data?.state === "invalid_target")).toBe(true);
}, 20000);
