import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { buildContextBudgetReport, formatContextBudgetReport } from "./lib/context-budget.ts";

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "context_budget_read",
    label: "Context Budget Read",
    description:
      "Inspect current cwd workflow artifacts and estimate context budget hotspots so you can decide what to compact or refresh first.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _args, _signal, _onUpdate, ctx) {
      const report = buildContextBudgetReport(ctx.cwd);
      return {
        content: [{ type: "text" as const, text: formatContextBudgetReport(report) }],
        details: { report },
      };
    },
    renderResult(result, _options, theme) {
      const firstBlock = result.content[0];
      const report =
        firstBlock?.type === "text"
          ? firstBlock.text
          : "Context budget report unavailable.";
      return new Text(theme.fg("muted", report), 0, 0);
    },
  });

  pi.registerCommand("context-budget", {
    description: "Show estimated context budget hotspots for the current cwd",
    handler: async (_args, ctx) => {
      const report = buildContextBudgetReport(ctx.cwd);
      pi.sendMessage({
        customType: "context-budget",
        content: formatContextBudgetReport(report),
        display: true,
      });
      ctx.ui.notify("Context budget report added to the session.", "info");
    },
  });
}
