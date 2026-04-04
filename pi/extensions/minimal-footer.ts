import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { basename } from "node:path";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

function applyMinimalFooter(ctx: ExtensionContext, getThinkingLevel: () => string): void {
  if (!ctx.hasUI) return;

  ctx.ui.setFooter((tui, theme, footerData) => {
    const dispose = footerData.onBranchChange(() => tui.requestRender());

    return {
      dispose,
      invalidate() {},
      render(width: number): string[] {
        const project = basename(ctx.cwd) || ctx.cwd;
        const branch = footerData.getGitBranch();
        const damageControl = footerData.getExtensionStatuses().get("damage-control");
        const left = theme.fg("dim", branch ? `${project} · ${branch}` : project);
        const modelLabel = `${ctx.model?.id ?? "no-model"} - ${getThinkingLevel()}`;
        const right = damageControl
          ? `${theme.fg("muted", modelLabel)} ${theme.fg("dim", "·")} ${damageControl}`
          : theme.fg("muted", modelLabel);
        const gap = Math.max(1, width - visibleWidth(left) - visibleWidth(right));
        return [truncateToWidth(left + " ".repeat(gap) + right, width)];
      },
    };
  });
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    applyMinimalFooter(ctx, () => pi.getThinkingLevel());
  });

  pi.on("model_select", async (_event, ctx) => {
    applyMinimalFooter(ctx, () => pi.getThinkingLevel());
  });

  pi.on("turn_start", async (_event, ctx) => {
    applyMinimalFooter(ctx, () => pi.getThinkingLevel());
  });
}
