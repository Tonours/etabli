import { expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { BACKGROUND_CONTEXT as context } from "@earendil-works/chord/context";
import { fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import { AgentDoc } from "@earendil-works/pi-durable";
import { fixture, until } from "./helpers.ts";

const call = (name: string, text: string) => fauxAssistantMessage(fauxToolCall(name, name === "tool_search" ? { query: text } : { text }), { stopReason: "toolUse" });

for (const fault of ["exit", "list-hang"]) {
  test(`persisted loaded names are unavailable during ${fault}, then recover the same target with byte-identical config`, async () => {
    const root = await mkdtemp(join(tmpdir(), "durable-mcp-identity-"));
    const stateFile = join(root, "availability");
    await writeFile(stateFile, "ready");
    const vaultCalls = join(root, "vault.calls"), healthyCalls = join(root, "healthy.calls");
    const pidFiles = [join(root, "vault.pid"), join(root, "healthy.pid")];
    const mcpServers = {
      vault: { command: process.execPath, args: [join(import.meta.dirname, "fixtures/mcp-server.ts")], timeout: 1, env: { STATE_FILE: stateFile, CALLS_FILE: vaultCalls, PID_FILE: pidFiles[0]! } },
      healthy: { command: process.execPath, args: [join(import.meta.dirname, "fixtures/mcp-server.ts")], env: { CALLS_FILE: healthyCalls, PID_FILE: pidFiles[1]! } },
    };
    const configBytes = JSON.stringify(mcpServers);
    const pids = new Set<number>();
    const rememberPids = async () => { for (const path of pidFiles) pids.add(Number(await readFile(path, "utf8"))); };
    const f = await fixture({ mcpServers });
    try {
      await rememberPids();
      f.faux.setResponses([call("tool_search", "mcp__vault__echo"), call("tool_search", "mcp__healthy__echo"), call("mcp__vault__echo", "vault-before"), call("mcp__healthy__echo", "healthy-before"), fauxAssistantMessage("done")]);
      const run = await f.core.runs.submit("Tonours/fixture", "load actual native names", `identity-${fault}`);
      await f.core.runs.tick(); await f.core.harness.waitForIdle(context);
      const loaded = JSON.stringify((await f.core.harness.snapshot(AgentDoc, run.conversationId, context))?.modelTools);
      expect(loaded).toContain("mcp__vault__echo");
      expect(loaded).toContain("mcp__healthy__echo");
      const before = await readFile(vaultCalls, "utf8");
      expect(before).toContain('"name":"echo"'); expect(before).toContain("vault-before");
      expect(await readFile(healthyCalls, "utf8")).toContain("healthy-before");

      await writeFile(stateFile, fault);
      await f.reopen(); await rememberPids();
      expect(JSON.stringify(mcpServers)).toBe(configBytes);
      expect(JSON.stringify((await f.core.harness.snapshot(AgentDoc, run.conversationId, context))?.modelTools)).toBe(loaded);
      const down = (await f.core.harness.conversation(run.conversationId, context))!;
      f.faux.setResponses([call("mcp__vault__echo", "must-not-transfer"), call("mcp__healthy__echo", "healthy-during"), fauxAssistantMessage("done")]);
      await (await down.submit({ type: "input", content: "use persisted names during outage", requestId: "outage" }, context)).wait(context);
      const entries = (await down.entries({ order: "ascending" }, 100, undefined, context)).items;
      const unavailable = entries.flatMap((entry) => (entry.model ?? []).flatMap((message) => message.role === "toolResult" && message.toolName === "mcp__vault__echo" ? [{ isError: message.isError, content: message.content }] : [])).at(-1);
      expect(unavailable?.isError).toBe(true); expect(JSON.stringify(unavailable)).toContain("not available");
      expect(await readFile(vaultCalls, "utf8")).toBe(before);
      const neighbor = await readFile(healthyCalls, "utf8");
      expect(neighbor).toContain("healthy-during"); expect(neighbor).not.toContain("must-not-transfer");

      await writeFile(stateFile, "ready");
      await f.reopen(); await rememberPids();
      expect(JSON.stringify(mcpServers)).toBe(configBytes);
      expect(JSON.stringify((await f.core.harness.snapshot(AgentDoc, run.conversationId, context))?.modelTools)).toBe(loaded);
      f.faux.setResponses([call("mcp__vault__echo", "vault-after"), call("mcp__healthy__echo", "healthy-after"), fauxAssistantMessage("done")]);
      const recovered = (await f.core.harness.conversation(run.conversationId, context))!;
      await (await recovered.submit({ type: "input", content: "use persisted names after recovery", requestId: "recovery" }, context)).wait(context);
      expect(await readFile(vaultCalls, "utf8")).toContain("vault-after");
      const finalNeighbor = await readFile(healthyCalls, "utf8");
      expect(finalNeighbor).toContain("healthy-after"); expect(finalNeighbor).not.toContain("vault-after");
    } finally {
      await f.cleanup();
      await until(async () => [...pids].every((pid) => { try { process.kill(pid, 0); return false; } catch { return true; } }));
      await rm(root, { recursive: true, force: true });
    }
  });
}
