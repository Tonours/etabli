import type { ExtensionAPI, ToolResultEvent } from "@mariozechner/pi-coding-agent";

export interface ErrorStrategy {
  pattern: RegExp;
  action: "retry" | "fallback" | "notify" | "compact";
  message: string;
}

export const ERROR_STRATEGIES: ErrorStrategy[] = [
  {
    pattern: /rate.limit|too.many.requests|429/i,
    action: "retry",
    message: "Rate limited. Wait a moment, then retry the same step.",
  },
  {
    pattern: /context.*exceeded|token.*limit|maximum.context/i,
    action: "compact",
    message: "Context limit reached. Compact or start a fresh session.",
  },
  {
    pattern: /timeout|timed.out|deadline/i,
    action: "retry",
    message: "Request timed out. Retry the step.",
  },
  {
    pattern: /service.*unavailable|503|502|500/i,
    action: "fallback",
    message: "Service unavailable. Try a fallback model.",
  },
];

const retryCounts = new Map<string, number>();
const MAX_RETRIES = 3;

export function classifyError(errorMessage: string): ErrorStrategy | null {
  for (const strategy of ERROR_STRATEGIES) {
    if (strategy.pattern.test(errorMessage)) {
      return strategy;
    }
  }
  return null;
}

export function getFallbackModel(currentModel: string): string | null {
  const fallbacks: Record<string, string> = {
    "gpt-4": "gpt-3.5-turbo",
    "gpt-4-turbo": "gpt-3.5-turbo",
    "claude-3-opus": "claude-3-sonnet",
    "claude-3-sonnet": "claude-3-haiku",
  };

  for (const [high, low] of Object.entries(fallbacks)) {
    if (currentModel.includes(high)) {
      return low;
    }
  }
  return null;
}

function getSessionKey(cwd: string): string {
  return cwd;
}

function readErrorText(event: ToolResultEvent): string {
  return event.content
    .filter((part) => part.type === "text")
    .map((part) => part.text)
    .join("\n")
    .trim();
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event, ctx) => {
    if (!event.isError) return;

    const errorMessage = readErrorText(event) || `${event.toolName} failed`;
    const strategy = classifyError(errorMessage);
    if (!strategy) {
      ctx.ui.notify(`Error: ${errorMessage.slice(0, 100)}`, "error");
      return;
    }

    const sessionKey = getSessionKey(ctx.cwd);
    const retryCount = retryCounts.get(sessionKey) || 0;

    if (strategy.action === "retry") {
      if (retryCount < MAX_RETRIES) {
        retryCounts.set(sessionKey, retryCount + 1);
        ctx.ui.notify(`${strategy.message} Attempt ${retryCount + 1}/${MAX_RETRIES}.`, "warning");
      } else {
        retryCounts.delete(sessionKey);
        ctx.ui.notify("Max retries reached. Try a different model or a smaller request.", "error");
      }

      pi.sendMessage({
        customType: "error-recovery",
        content: `${strategy.message}\n\nLast error: ${errorMessage.slice(0, 200)}`,
        display: true,
      });
      return;
    }

    if (strategy.action === "fallback") {
      const fallbackModel = getFallbackModel(ctx.model?.id || "");
      const message = fallbackModel
        ? `${strategy.message} Suggested fallback: ${fallbackModel}`
        : "No fallback model available. Try again later.";
      ctx.ui.notify(message, fallbackModel ? "warning" : "error");
      pi.sendMessage({ customType: "error-recovery", content: message, display: true });
      return;
    }

    if (strategy.action === "compact") {
      ctx.ui.notify(strategy.message, "warning");
      pi.sendMessage({
        customType: "error-recovery",
        content: `${strategy.message}\nUse /compact before you continue.`,
        display: true,
      });
      return;
    }

    ctx.ui.notify(strategy.message, "info");
  });

  pi.on("agent_end", async (_event, ctx) => {
    retryCounts.delete(getSessionKey(ctx.cwd));
  });

  pi.registerCommand("error-status", {
    description: "Show error recovery status",
    handler: async (_args, ctx) => {
      const sessionKey = getSessionKey(ctx.cwd);
      const retryCount = retryCounts.get(sessionKey) || 0;
      const lines = [
        "Error Recovery Status",
        "",
        `Current retries: ${retryCount}/${MAX_RETRIES}`,
        "",
        "Handled error types:",
        ...ERROR_STRATEGIES.map((strategy) => `  - ${strategy.action}: ${strategy.pattern.source.slice(0, 40)}...`),
      ];

      pi.sendMessage({
        customType: "error-status",
        content: lines.join("\n"),
        display: true,
      });
      ctx.ui.notify(`${retryCount} retries tracked for this cwd`, "info");
    },
  });
}
