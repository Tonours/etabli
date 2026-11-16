import { createInterface } from "node:readline";
import { writeFile } from "node:fs/promises";

if (process.env.PID_FILE) await writeFile(process.env.PID_FILE, String(process.pid));
process.stderr.write(process.env.STDERR_MARKER ?? "");
if (process.env.MCP_MODE === "exit") process.exit(1);
const input = createInterface({ input: process.stdin });
input.on("close", () => process.exit(0));
for await (const line of input) {
  const message = JSON.parse(line) as { id?: number; method?: string; params?: { name?: string; arguments?: Record<string, unknown> } };
  if (message.id === undefined) continue;
  if (process.env.MCP_MODE === "hang") continue;
  const result = message.method === "initialize" ? { protocolVersion: "2025-11-25", capabilities: { tools: {} }, serverInfo: { name: "fixture", version: "1" } }
    : message.method === "tools/list" ? { tools: [{ name: "echo", description: "Echo a fixture value", inputSchema: { type: "object", properties: { text: { type: "string" } }, required: ["text"], additionalProperties: false } }] }
    : message.method === "tools/call" ? { content: [{ type: "text", text: process.env.MCP_MODE === "environment" ? JSON.stringify({ parentMarker: process.env.ETABLI_S7_PARENT_MARKER ?? null, configured: process.env.CONFIGURED, home: process.env.HOME, path: process.env.PATH }) : message.params?.arguments?.text ?? "echo" }] }
    : {};
  process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id: message.id, result })}\n`);
}
