/**
 * Tool Counter — Two-line footer with real-time session metrics.
 *
 * Line 1: model + context bar + % (left) | tokens in/out + cost (right)
 * Line 2: cwd + git branch (left) | tool call tally (right)
 *
 * Usage: loaded via settings.json packages or `pi -e extensions/tool-counter.ts`
 */

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { basename } from "node:path";

export default function (pi: ExtensionAPI) {
  const counts: Record<string, number> = {};

  pi.on("tool_execution_end", async (event) => {
    counts[event.toolName] = (counts[event.toolName] ?? 0) + 1;
  });

  pi.on("session_start", async (_event, ctx) => {
    for (const key of Object.keys(counts)) delete counts[key];

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          let tokIn = 0;
          let tokOut = 0;
          let cost = 0;

          for (const entry of ctx.sessionManager.getBranch()) {
            if (entry.type === "message" && entry.message.role === "assistant") {
              const m = entry.message as AssistantMessage;
              tokIn += m.usage.input;
              tokOut += m.usage.output;
              cost += m.usage.cost.total;
            }
          }

          const fmt = (n: number) =>
            n < 1000 ? `${n}` : `${(n / 1000).toFixed(1)}k`;

          const dir = basename(ctx.cwd);
          const branch = footerData.getGitBranch();
          const usage = ctx.getContextUsage();
          const pct = usage ? usage.percent : 0;
          const filled = Math.round(pct / 10) || 1;
          const model = ctx.model?.id ?? "no-model";

          // --- Line 1: model + context bar (left) | tokens + cost (right) ---
          const l1Left =
            theme.fg("dim", ` ${model} `) +
            theme.fg("warning", "[") +
            theme.fg("success", "#".repeat(filled)) +
            theme.fg("dim", "-".repeat(10 - filled)) +
            theme.fg("warning", "]") +
            theme.fg("dim", " ") +
            theme.fg("accent", `${Math.round(pct)}%`);

          const l1Right =
            theme.fg("success", `${fmt(tokIn)}`) +
            theme.fg("dim", " in ") +
            theme.fg("accent", `${fmt(tokOut)}`) +
            theme.fg("dim", " out ") +
            theme.fg("warning", `$${cost.toFixed(4)}`) +
            theme.fg("dim", " ");

          const pad1 = " ".repeat(
            Math.max(1, width - visibleWidth(l1Left) - visibleWidth(l1Right)),
          );
          const line1 = truncateToWidth(l1Left + pad1 + l1Right, width, "");

          // --- Line 2: cwd + branch (left) | tool tally (right) ---
          const l2Left =
            theme.fg("dim", ` ${dir}`) +
            (branch
              ? theme.fg("dim", " ") +
                theme.fg("warning", "(") +
                theme.fg("success", branch) +
                theme.fg("warning", ")")
              : "");

          const entries = Object.entries(counts);
          const l2Right =
            entries.length === 0
              ? theme.fg("dim", "waiting for tools ")
              : entries
                  .map(
                    ([name, count]) =>
                      theme.fg("accent", name) +
                      theme.fg("dim", " ") +
                      theme.fg("success", `${count}`),
                  )
                  .join(theme.fg("warning", " | ")) +
                theme.fg("dim", " ");

          const pad2 = " ".repeat(
            Math.max(1, width - visibleWidth(l2Left) - visibleWidth(l2Right)),
          );
          const line2 = truncateToWidth(l2Left + pad2 + l2Right, width, "");

          return [line1, line2];
        },
      };
    });
  });
}
