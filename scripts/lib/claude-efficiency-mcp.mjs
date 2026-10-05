import { appendFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { corpus } from "./claude-efficiency-fixtures.mjs";
const tools = [
  { name: "get_ticket", description: "Read one synthetic ticket" },
  { name: "get_document", description: "Read one synthetic document" },
].map((tool) => ({
  ...tool,
  inputSchema: {
    type: "object",
    properties: { id: { type: "string" } },
    required: ["id"],
    additionalProperties: false,
  },
}));
export function dispatch(request, record = () => {}) {
  let result;
  if (request.method === "initialize")
    result = {
      protocolVersion: request.params?.protocolVersion,
      capabilities: { tools: {} },
      serverInfo: { name: "efficiency-read-only-corpus", version: "1.0.0" },
    };
  else if (request.method === "ping") result = {};
  else if (request.method === "tools/list") result = { tools };
  else if (request.method === "tools/call") {
    const name = request.params?.name,
      args = request.params?.arguments;
    const item =
      name === "get_ticket"
        ? corpus.ticket
        : name === "get_document"
          ? corpus.document
          : null;
    const ok = Boolean(
      item && args?.id === item.id && Object.keys(args).length === 1,
    );
    record({ tool: name, argument: args?.id ?? null, ok });
    result = {
      content: [
        {
          type: "text",
          text: ok ? JSON.stringify(item) : "Unknown synthetic item",
        },
      ],
      isError: !ok,
    };
  } else if (request.id === undefined) return null;
  else
    return {
      jsonrpc: "2.0",
      id: request.id,
      error: { code: -32601, message: "Unknown method" },
    };
  return request.id === undefined
    ? null
    : { jsonrpc: "2.0", id: request.id, result };
}
if (process.argv[1]?.endsWith("/claude-efficiency-mcp.mjs")) {
  const journal = process.argv[2];
  if (!journal) throw new Error("private journal path required");
  const input = createInterface({ input: process.stdin });
  for await (const line of input) {
    try {
      const response = dispatch(JSON.parse(line), (entry) =>
        appendFileSync(journal, JSON.stringify(entry) + "\n", { mode: 0o600 }),
      );
      if (response) process.stdout.write(JSON.stringify(response) + "\n");
    } catch {
      process.stdout.write(
        JSON.stringify({
          jsonrpc: "2.0",
          id: null,
          error: { code: -32700, message: "Invalid request" },
        }) + "\n",
      );
    }
  }
}
