import { expect, test } from "bun:test";
import { mkdtemp, rm, writeFile, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { parseCliReview, runCliReview } from "../src/review-cli.ts";
import { until } from "./helpers.ts";

const model = "claude-opus-5-5";
const stream = (assistant = model, tools = ["Read", "Grep", "Glob"]) => [
  { type: "system", subtype: "init", model, tools },
  { type: "assistant", parent_tool_use_id: null, message: { model: assistant } },
  { type: "result", subtype: "success", is_error: false, permission_denials: [], result: "Verdict: GO\nSTATUS: complete", modelUsage: { "claude-haiku-5-5": {}, [model]: {} } },
].map((event) => JSON.stringify(event)).join("\n");

test("CLI provenance uses actual primary response and offered tools, not aggregate usage", () => {
  expect(parseCliReview(stream(), model)).toMatchObject({ provider: "anthropic", modelId: model });
  expect(() => parseCliReview(stream("claude-haiku-5-5"), model)).toThrow("different model");
  expect(() => parseCliReview(stream(model, ["Read", "Bash"]), model)).toThrow("provenance");
  expect(() => parseCliReview(JSON.stringify({ type: "result", subtype: "success", is_error: false, permission_denials: [], result: "GO", modelUsage: { [model]: {} } }), model)).toThrow("provenance");
});

test("CLI deadline survives its daemon process being killed", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-cli-orphan-"));
  let pid = 0;
  const running = async () => {
    const text = await readFile(`/proc/${pid}/stat`, "utf8").catch(() => "");
    return text !== "" && !/^\d+ \([^)]*\) Z /.test(text);
  };
  try {
    const script = join(root, "fake.cjs"), marker = join(root, "pid");
    await writeFile(script, `require('node:fs').writeFileSync(${JSON.stringify(marker)},String(process.pid));setInterval(()=>{},1000);process.stdin.resume();`);
    const source = `import {runCliReview} from ${JSON.stringify(new URL("../src/review-cli.ts", import.meta.url).href)}; await runCliReview({cwd:${JSON.stringify(root)},prompt:'read-only fixture',modelId:'claude-opus-5-5'},{command:['/usr/bin/node',${JSON.stringify(script)}],timeoutMs:500});`;
    const parent = spawn("/usr/bin/node", ["--input-type=module", "-e", source], { stdio: "ignore" });
    const ended = new Promise((resolve) => parent.once("exit", resolve));
    await until(async () => { pid = Number(await readFile(marker, "utf8").catch(() => "0")); return pid > 0; }, 2000);
    parent.kill("SIGKILL");
    await ended;
    await until(async () => !await running(), 2000);
    expect(await running()).toBe(false);
  } finally {
    if (pid && await running() && (await readFile(`/proc/${pid}/cmdline`, "utf8").catch(() => "")).includes(root)) process.kill(pid, "SIGKILL");
    await rm(root, { recursive: true, force: true });
  }
});

test("CLI review fixes read-only argv and interrupts a bounded subprocess", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-cli-review-"));
  try {
    const script = join(root, "fake.cjs");
    const argv = join(root, "argv.json");
    await writeFile(script, `require('node:fs').writeFileSync(${JSON.stringify(argv)},JSON.stringify(process.argv.slice(2)));process.stdin.resume();process.stdin.on('end',()=>console.log(${JSON.stringify(stream())}));`);
    const input = { cwd: root, prompt: "review fixture", modelId: model };
    expect((await runCliReview(input, { command: ["/usr/bin/node", script] })).modelId).toBe(model);
    const actual = JSON.parse(await readFile(argv, "utf8")) as string[];
    expect(actual[actual.indexOf("--tools") + 1]).toBe("Read,Grep,Glob");
    expect(actual).not.toContain("--dangerously-skip-permissions");
    await writeFile(script, "setInterval(()=>{},1000);process.stdin.resume();");
    await expect(runCliReview(input, { command: ["/usr/bin/node", script], timeoutMs: 50 })).rejects.toThrow("timed out");
    const abort = new AbortController();
    const pending = runCliReview(input, { command: ["/usr/bin/node", script], signal: abort.signal });
    setTimeout(() => abort.abort(), 50);
    await expect(pending).rejects.toThrow("aborted");
  } finally { await rm(root, { recursive: true, force: true }); }
});
