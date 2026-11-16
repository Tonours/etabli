import { homedir } from "node:os";
import { unsafe } from "@earendil-works/pi-schema";
import { defineExtension, defineTool } from "@earendil-works/pi-durable";
import { createToolSearchTool } from "@earendil-works/pi-durable/tool-search";
import { McpClient, StdioTransport, createMcpToolName, normalizeMcpInputSchema, limitMcpContent, toLlmContent, validateMcpServerConfig, type McpStdioServerConfig, type McpTransport } from "@earendil-works/pi-mcp";

const compareNames = (a: string, b: string) => a < b ? -1 : a > b ? 1 : 0;

export function mcpConfig(raw: unknown): Record<string, unknown> {
  if (raw === undefined) return {};
  if (!raw || typeof raw !== "object" || Array.isArray(raw) || Object.keys(raw).length > 16 || Object.keys(raw).some((name) => !/^[A-Za-z0-9_-]{1,64}$/.test(name))) throw new Error("mcpServers must be an object with at most 16 named servers");
  // Native 1.5.2 retains this prefix even when its 64-character name needs a hash suffix.
  const prefixes = Object.keys(raw).map((server) => createMcpToolName(server, "", () => true).replace(/_[a-f0-9]{8}$/, ""));
  if (prefixes.some((prefix, i) => prefixes.some((other, j) => i !== j && other.startsWith(prefix)))) throw new Error("mcpServers names must have disjoint native prefixes; rename overlapping servers");
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
  const connected = await Promise.all(Object.entries(mcpConfig(servers)).sort(([a], [b]) => compareNames(a, b)).map(async ([server, raw]) => {
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
      const names = new Set<string>();
      const upstream = new Set<string>();
      const registered = tools.toSorted((a, b) => compareNames(a.name, b.name)).map((tool) => {
        const name = createMcpToolName(server, tool.name, (value) => names.has(value));
        if (upstream.has(tool.name) || names.has(name)) throw new Error("Ambiguous MCP tool identity");
        upstream.add(tool.name);
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
  return { extension: defineExtension({ name: "etabli-mcp", tools: [createToolSearchTool(), ...connected.flat()] }), close: async () => { await Promise.all(clients.map((client) => client.close())); } };
}
