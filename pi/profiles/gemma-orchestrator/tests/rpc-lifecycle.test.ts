import { expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

async function queuedCase(mode: "completion" | "prose" | "steer") {
  const root = await mkdtemp(join(tmpdir(), "gemma-rpc-"));
  const pi = process.env.GEMMA_PI_BIN ?? resolve(import.meta.dir, "../../../node_modules/.bin/pi");
  let requests = 0, oldReceipt = "";
  const expectedRequests = mode === "steer" ? 2 : 4;
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, async fetch(req) {
    const body = await req.json() as { messages: { role: string; content?: string }[] };
    requests++;
    for (const message of body.messages) {
      if (message.role !== "tool" || typeof message.content !== "string") continue;
      try {
        const data = JSON.parse(message.content) as { id?: string; kind?: string };
        if (data.id && data.kind === "command_executed") oldReceipt = data.id;
      } catch { /* not a receipt */ }
    }
    if (requests > expectedRequests) return new Response("Unexpected provider request", { status: 500 });
    if (mode === "prose" && requests === 2) return new Response(`data: ${JSON.stringify({ choices: [{ index: 0, delta: { content: "I did the first part." }, finish_reason: "stop" }] })}\n\ndata: [DONE]\n\n`, { headers: { "Content-Type": "text/event-stream" } });
    const call = requests === 1 ? { name: "execute", arguments: { command: "printf fixture" } }
      : { name: "finish_task", arguments: { status: requests === 4 ? "blocked" : "done", claims: requests === 4 ? [] : [{ receipt_id: oldReceipt, kind: "command_executed" }], note: "fixture" } };
    return new Response(`data: ${JSON.stringify({ choices: [{ index: 0, delta: { tool_calls: [{ index: 0, id: "call_0", type: "function", function: { name: call.name, arguments: JSON.stringify(call.arguments) } }] }, finish_reason: "tool_calls" }] })}\n\ndata: [DONE]\n\n`, { headers: { "Content-Type": "text/event-stream" } });
  } });
  try {
    await writeFile(join(root, "models.json"), JSON.stringify({ providers: { fixture: { api: "openai-completions", apiKey: "public-fixture", baseUrl: `http://127.0.0.1:${server.port}/v1`, models: [{ id: "fixture", name: "fixture", contextWindow: 32768, maxTokens: 1024, reasoning: false, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }] } } }));
    await writeFile(join(root, "settings.json"), JSON.stringify({ retry: { enabled: false, maxRetries: 0 } }));
    const settledProbe = join(root, "settled-probe.ts");
    await writeFile(settledProbe, `export default function(pi) {
      pi.on("agent_settled", async () => {
        await new Promise(resolve => setTimeout(resolve, 100));
        pi.appendEntry("fixture_settled", {});
      });
    }`);
    const proc = Bun.spawn([pi, "--offline", "--no-extensions", "--no-mcp", "--no-skills", "--no-context-files", "--no-prompt-templates", "--no-builtin-tools", "--tools", "execute,read_file,write_file,open_page,finish_task", "-e", resolve(import.meta.dir, "../extension.ts"), "-e", settledProbe, "--provider", "fixture", "--model", "fixture", "--session", join(root, "session.jsonl"), "--mode", "rpc"],
      { cwd: root, env: { ...process.env, PI_CODING_AGENT_DIR: root }, stdin: "pipe", stdout: "pipe", stderr: "pipe" });
    const timeout = setTimeout(() => proc.kill(), 15000);
    proc.stdin.write('{"type":"prompt","message":"first task","id":"first"}\n');
    let queued = false, pending = "", output = "";
    const consume = (async () => {
      for await (const bytes of proc.stdout) {
        const text = new TextDecoder().decode(bytes);output += text;pending += text;
        while (pending.includes("\n")) {
          const index = pending.indexOf("\n"), line = pending.slice(0, index);pending = pending.slice(index + 1);
          let event: { type: string };
          try { event = JSON.parse(line) as { type: string }; } catch { continue; }
          if (event.type === "tool_execution_start" && !queued) {
            queued = true;
            proc.stdin.write(JSON.stringify({ type: "prompt", message: "next owner input", streamingBehavior: mode === "steer" ? "steer" : "followUp", id: "second" }) + "\n");
          }
          if (event.type === "agent_settled") proc.stdin.end();
        }
      }
    })();
    const [exit, stderr] = await Promise.all([proc.exited, new Response(proc.stderr).text(), consume]);
    clearTimeout(timeout);
    expect(exit, stderr).toBe(0);expect(requests).toBe(expectedRequests);
    if (mode !== "steer") expect(output).toContain("unknown_receipt");
    const rows = (await readFile(join(root, "session.jsonl"), "utf8")).trim().split("\n").map((line) => JSON.parse(line) as { customType?: string; data?: { taskId: string; status?: string } });
    expect(rows.some((row) => row.customType === "fixture_settled")).toBe(true);
    const completions = rows.filter((r) => r.customType === "gemma_completion");
    expect(completions).toHaveLength(mode === "completion" ? 2 : 1);
    expect(completions.at(-1)?.data?.status).toBe(mode === "steer" ? "done" : "blocked");
    const tasks = rows.filter((r) => r.customType === "gemma_task");
    expect(tasks).toHaveLength(mode === "steer" ? 1 : 2);
    if (mode === "completion") expect(completions[0]?.data?.taskId).not.toBe(completions[1]?.data?.taskId);
    if (mode === "prose") expect(rows.some((r) => r.customType === "gemma_status" && (r.data as { state?: string })?.state === "unvalidated")).toBe(true);
  } finally { server.stop(true);await rm(root, { recursive: true, force: true }); }
}
test("queued follow-up starts fresh proof scope after completion", () => queuedCase("completion"), 20000);
test("queued follow-up starts fresh proof scope after unvalidated prose", () => queuedCase("prose"), 20000);
test("owner steering preserves current task evidence and budget", () => queuedCase("steer"), 20000);
