import { describe, expect, test } from "bun:test";
import filterOutput from "../filter-output.ts";

type TextContent = { type: "text"; text: string };
type NotifyLevel = "info" | "warning" | "error";
type Notification = { message: string; level: NotifyLevel };
type ToolResultEvent = {
  isError?: boolean;
  content: TextContent[];
  toolName: string;
  input: Record<string, unknown>;
};
type ToolResultResponse = { content: TextContent[] };
type ToolContext = {
  ui: {
    notifications: Notification[];
    notify(message: string, level: NotifyLevel): void;
  };
};
type ToolResultHandler = (
  event: ToolResultEvent,
  ctx: ToolContext,
) => Promise<ToolResultResponse | undefined>;

function setupExtension(): ToolResultHandler {
  let handler: ToolResultHandler | undefined;
  const pi = {
    on(event: "tool_result", nextHandler: ToolResultHandler): void {
      if (event === "tool_result") handler = nextHandler;
    },
  };

  filterOutput(pi as Parameters<typeof filterOutput>[0]);

  if (!handler) throw new Error("tool_result handler not registered");
  return handler;
}

function createContext(): ToolContext {
  const notifications: Notification[] = [];

  return {
    ui: {
      notifications,
      notify(message: string, level: NotifyLevel) {
        notifications.push({ message, level });
      },
    },
  };
}

describe("filter-output", () => {
  test("labels Anthropic and OpenAI keys distinctly", async () => {
    const handler = setupExtension();
    const ctx = createContext();
    const anthropicKey = `sk-ant-${"a".repeat(24)}`;
    const openAiKey = `sk-proj-${"b".repeat(24)}`;

    const result = await handler(
      {
        content: [{ type: "text", text: `anthropic=${anthropicKey}\nopenai=${openAiKey}` }],
        input: {},
        toolName: "bash",
      },
      ctx,
    );

    expect(result?.content[0]?.text).toContain("[ANTHROPIC_KEY_REDACTED]");
    expect(result?.content[0]?.text).toContain("[OPENAI_KEY_REDACTED]");
    expect(result?.content[0]?.text).not.toContain(anthropicKey);
    expect(result?.content[0]?.text).not.toContain(openAiKey);
    expect(ctx.ui.notifications).toEqual([
      { message: "Redacted 2 secrets from output", level: "warning" },
    ]);
  });
});
