/// <reference path="./bun-test.d.ts" />

type Level = "info" | "warning" | "error";

type EventHandler = (event: unknown, ctx: MockContext) => Promise<unknown> | unknown;
type CommandHandler = (args: string, ctx: MockContext) => Promise<void> | void;
type ToolExecute = (
  toolCallId: string,
  args: Record<string, unknown>,
  signal: AbortSignal | undefined,
  onUpdate: unknown,
  ctx: MockContext,
) => Promise<unknown> | unknown;

export interface MockContext {
  cwd: string;
  model?: { id: string; provider: string };
  sessionManager: {
    getBranch(): Array<unknown>;
  };
  ui: {
    notifications: Array<{ message: string; level: Level }>;
    notify(message: string, level?: Level): void;
    setStatus(): void;
    setWidget(): void;
  };
}

export function createMockContext(cwd: string, branch: Array<unknown> = []): MockContext {
  const notifications: Array<{ message: string; level: Level }> = [];
  return {
    cwd,
    model: { id: "gpt-5.4", provider: "openai-codex" },
    sessionManager: {
      getBranch() {
        return branch;
      },
    },
    ui: {
      notifications,
      notify(message: string, level: Level = "info") {
        notifications.push({ message, level });
      },
      setStatus() {},
      setWidget() {},
    },
  };
}

export function createHarness() {
  const commands = new Map<string, CommandHandler>();
  const tools = new Map<string, ToolExecute>();
  const events = new Map<string, EventHandler>();
  const messages: Array<{ customType: string; content: string; display: boolean }> = [];

  const api = {
    on(name: string, handler: EventHandler) {
      events.set(name, handler);
    },
    registerCommand(name: string, command: { handler: CommandHandler }) {
      commands.set(name, command.handler);
    },
    registerTool(tool: { name: string; execute: ToolExecute }) {
      tools.set(tool.name, tool.execute);
    },
    sendMessage(message: { customType: string; content: string; display: boolean }) {
      messages.push(message);
    },
    sendUserMessage() {},
  };

  return {
    api,
    messages,
    async emit(name: string, event: unknown, ctx: MockContext) {
      const handler = events.get(name);
      if (!handler) throw new Error(`Missing event handler: ${name}`);
      return await handler(event, ctx);
    },
    async command(name: string, args: string, ctx: MockContext) {
      const handler = commands.get(name);
      if (!handler) throw new Error(`Missing command: ${name}`);
      await handler(args, ctx);
    },
    async tool(name: string, args: Record<string, unknown>, ctx: MockContext) {
      const handler = tools.get(name);
      if (!handler) throw new Error(`Missing tool: ${name}`);
      return await handler("tool-call", args, undefined, undefined, ctx);
    },
  };
}
