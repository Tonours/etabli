import { spawn } from "node:child_process";

type CliRecord = Record<string, unknown>;
function record(value: unknown): CliRecord {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid CLI review event");
  return value as CliRecord;
}

export type CliReview = { body: string; provider: "anthropic"; modelId: string; tools: string[] };

export function parseCliReview(output: string, expectedModel: string): CliReview {
  let initialized = false;
  let observed = false;
  let body: string | undefined;
  let tools: string[] = [];
  for (const line of output.split("\n").filter((value) => value.trim())) {
    const event = record(JSON.parse(line));
    if (event.type === "system" && event.subtype === "init") {
      if (event.model !== expectedModel || !Array.isArray(event.tools) || event.tools.some((tool) => !["Read", "Grep", "Glob"].includes(String(tool)))) throw new Error("CLI review model or tool provenance refused");
      tools = event.tools.map(String);
      initialized = true;
    }
    if (event.type === "assistant" && event.parent_tool_use_id == null) {
      const message = record(event.message);
      if (message.model !== expectedModel) throw new Error("CLI review used a different model");
      observed = true;
    }
    if (event.type === "result") {
      if (event.subtype !== "success" || event.is_error !== false || !Array.isArray(event.permission_denials) || event.permission_denials.length || typeof event.result !== "string") throw new Error("CLI review did not complete with permitted tools");
      body = event.result;
    }
  }
  if (!initialized || !observed || !body?.trim()) throw new Error("CLI review effective provenance is missing");
  return { body, provider: "anthropic", modelId: expectedModel, tools };
}

export async function runCliReview(input: { cwd: string; prompt: string; modelId: string }, options: { signal?: AbortSignal; timeoutMs?: number; command?: readonly string[] } = {}): Promise<CliReview> {
  options.signal?.throwIfAborted();
  const command = options.command ?? ["claude"];
  const timeout = options.timeoutMs ?? 600_000;
  if (!command.length || !Number.isSafeInteger(timeout) || timeout < 1 || timeout > 600_000) throw new Error("Invalid CLI review execution bounds");
  const args = [...command.slice(1), "-p", "--model", input.modelId, "--verbose", "--output-format", "stream-json", "--tools", "Read,Grep,Glob", "--allowedTools", "Read,Grep,Glob", "--setting-sources", "", "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}', "--permission-mode", "plan", "--permission-prompts", "none", "--no-session-persistence"];
  const output = await new Promise<string>((resolve, reject) => {
    const child = spawn("timeout", ["--signal=KILL", `${timeout / 1000}s`, command[0], ...args], { cwd: input.cwd, detached: true, stdio: ["pipe", "pipe", "ignore"] });
    let text = "";
    let failure: string | undefined;
    const kill = () => { if (child.pid) { try { process.kill(-child.pid, "SIGKILL"); } catch { } } };
    const abort = () => { failure = "CLI review aborted"; kill(); };
    const timer = setTimeout(() => { failure = "CLI review timed out"; kill(); }, timeout + 1000);
    options.signal?.addEventListener("abort", abort, { once: true });
    if (options.signal?.aborted) abort();
    child.stdin.on("error", () => undefined);
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      text += chunk;
      if (text.length > 16_000_000) { failure = "CLI review response exceeds the limit"; kill(); }
    });
    child.once("exit", kill);
    child.once("error", () => { failure = "CLI review process unavailable"; });
    child.once("close", (code, signal) => {
      clearTimeout(timer);
      options.signal?.removeEventListener("abort", abort);
      if (failure || code !== 0) reject(new Error(failure ?? (code === 124 || signal === "SIGKILL" ? "CLI review timed out" : "CLI review failed")));
      else resolve(text);
    });
    child.stdin.end(input.prompt);
  });
  return parseCliReview(output, input.modelId);
}
