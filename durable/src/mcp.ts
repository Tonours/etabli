import { homedir } from "node:os";
import { unsafe } from "@earendil-works/pi-schema";
import { defineExtension, defineTool } from "@earendil-works/pi-durable";
import { createToolSearchTool } from "@earendil-works/pi-durable/tool-search";
import { McpClient, StdioTransport, createMcpToolName, mcpNamespace, normalizeMcpInputSchema, limitMcpContent, toLlmContent, validateMcpServerConfig, type McpStdioServerConfig, type McpTransport } from "@earendil-works/pi-mcp";

export function mcpConfig(raw: unknown): Record<string, unknown> {
  if (raw === undefined) return {};
  if (!raw || typeof raw !== "object" || Array.isArray(raw) || Object.keys(raw).length > 16 || Object.keys(raw).some((name) => !/^[A-Za-z0-9_-]{1,64}$/.test(name)) || new Set(Object.keys(raw).map(mcpNamespace)).size !== Object.keys(raw).length) throw new Error("mcpServers must be an object with at most 16 distinct normalized server names");
  return raw as Record<string, unknown>;
}

export function mcpStdio(config: McpStdioServerConfig): StdioTransport {
  const home = process.env.HOME ?? homedir();
  const expand = (value: string) => {
    const expanded = value.replaceAll("${HOME}", home);
    if (/\$\{[^}]*\}/.test(expanded)) throw new Error("Unsupported MCP environment reference");
    return expanded;
  };
  return new StdioTransport({
    command: expand(config.command), args: config.args?.map(expand), cwd: config.cwd ? expand(config.cwd) : home,
    inheritEnv: false, env: { PATH: process.env.PATH ?? "/usr/bin:/bin", HOME: home, ...Object.fromEntries(Object.entries(config.env ?? {}).map(([key, value]) => [key, expand(value)])) },
    stderr: "pipe", closeTimeoutMs: 1000,
  });
}

export async function openMcp(servers: Record<string, unknown> = {}, options: {
  transport?: (config: McpStdioServerConfig) => McpTransport;
  report?: (event: { server: string; status: "ready" | "skipped" }) => void;
} = {}) {
  const clients: McpClient[] = [];
  const report = options.report ?? ((event) => console.error(`MCP ${event.server}: ${event.status}`));
  const names = new Set<string>();
  const connected = await Promise.all(Object.entries(mcpConfig(servers)).sort(([a], [b]) => a.localeCompare(b)).map(async ([server, raw]) => {
    const validated = validateMcpServerConfig(server, raw);
    if (validated.kind !== "stdio" || !Number.isFinite(validated.config.timeout ?? 10) || (validated.config.timeout ?? 10) > 120 || (validated.config.timeout ?? 10) < 1) {
      report({ server, status: "skipped" });
      return [];
    }
    const config = validated.config;
    if (config.enabled === false) return [];
    const client = new McpClient({ name: "etabli-durable", version: "1", requestTimeoutMs: (config.timeout ?? 10) * 1000 });
    clients.push(client);
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const tools = await Promise.race([
        (async () => { await client.connect((options.transport ?? mcpStdio)(config)); return client.listTools(); })(),
        new Promise<never>((_resolve, reject) => { timer = setTimeout(() => reject(new Error("MCP startup timeout")), (config.timeout ?? 10) * 1000); }),
      ]);
      const registered = tools.toSorted((a, b) => a.name.localeCompare(b.name)).map((tool) => () => {
        const name = createMcpToolName(server, tool.name, (value) => names.has(value));
        if (names.has(name)) return undefined;
        names.add(name);
        return defineTool({
          name, description: tool.description ?? tool.name,
          parameters: unsafe<Record<string, unknown>>(normalizeMcpInputSchema(tool.inputSchema)), deferred: true, replay: "unsafe",
          async execute(args, _api, context) {
            try {
              const result = await client.callTool(tool.name, args, { signal: context.abortSignal });
              const limited = await limitMcpContent(toLlmContent(result));
              return { output: limited.content, isError: result.isError === true };
            } catch {
              context.abortSignal?.throwIfAborted();
              return { output: [{ type: "text" as const, text: `MCP ${server}: tool call failed` }], isError: true };
            }
          },
        });
      });
      report({ server, status: "ready" });
      return registered;
    } catch {
      await client.close();
      report({ server, status: "skipped" });
      return [];
    } finally { clearTimeout(timer); }
  }));
  // Assign names after parallel discovery, in stable server/tool order.
  return { extension: defineExtension({ name: "etabli-mcp", tools: [createToolSearchTool(), ...connected.flat().map((register) => register()).filter((tool) => tool !== undefined)] }), close: async () => { await Promise.all(clients.map((client) => client.close())); } };
}
