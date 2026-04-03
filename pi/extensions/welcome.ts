/**
 * Welcome — compact branded greeting with session info.
 * Responsive: centered block on wide terminals, tight stacked layout on narrow ones.
 * Clears on first tool call.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { DynamicBorder, VERSION } from "@mariozechner/pi-coding-agent";
import { Container, Text, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { homedir, userInfo } from "node:os";

const COMPACT_THRESHOLD = 72;

function getUserName(): string {
  try {
    return userInfo().username;
  } catch {
    return "";
  }
}

function center(text: string, width: number): string {
  const vw = visibleWidth(text);
  if (vw >= width) return text;
  return " ".repeat(Math.floor((width - vw) / 2)) + text;
}

export default function (pi: ExtensionAPI) {
  let visible = false;

  pi.on("session_start", async (_event, ctx) => {
    visible = true;
    const model = ctx.model?.id ?? "?";
    const home = homedir();
    const dir = ctx.cwd.startsWith(home) ? "~" + ctx.cwd.slice(home.length) : ctx.cwd;
    const name = getUserName();
    const version = VERSION ?? "?";

    ctx.ui.setWidget(
      "welcome",
      (_tui, theme) => {
        const container = new Container();
        const borderFn = (s: string) => theme.fg("dim", s);
        container.addChild(new DynamicBorder(borderFn));
        const body = new Text("", 1, 0);
        container.addChild(body);
        container.addChild(new DynamicBorder(borderFn));

        return {
          render(width: number): string[] {
            const inner = Math.max(1, width - 4);
            const compact = inner < COMPACT_THRESHOLD;

            const brand = theme.bold(theme.fg("accent", "pi"));
            const greeting = name ? theme.fg("dim", ` Welcome ${name}`) : "";
            const headline = brand + greeting;
            const meta = theme.fg("dim", `v${version} · ${model}`);
            const dirLine = theme.fg("muted", truncateToWidth(dir, inner));

            const lines = compact
              ? [headline, meta, dirLine]
              : [center(headline, inner), center(meta, inner), center(dirLine, inner)];

            body.setText(lines.map((line) => truncateToWidth(line, inner)).join("\n"));
            return container.render(width);
          },
          invalidate() {
            container.invalidate();
          },
        };
      },
      { placement: "aboveEditor" },
    );
  });

  pi.on("turn_start", async (_event, ctx) => {
    if (visible) {
      visible = false;
      ctx.ui.setWidget("welcome", undefined);
    }
  });
}
