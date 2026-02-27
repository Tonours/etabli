/**
 * Welcome — pixel-art bear banner with session info.
 * Responsive: full centered layout or compact 2-line when wide enough.
 * Clears on first tool call.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { DynamicBorder, VERSION } from "@mariozechner/pi-coding-agent";
import { Container, Text, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { basename } from "node:path";
import { userInfo } from "node:os";

// Pixel-art bear using block characters — 9 lines tall, ~19 cols wide
const BEAR_ART = [
  "    ██      ██    ",
  "  ██░░██  ██░░██  ",
  "  ██░░████░░░░██  ",
  "██░░░░░░░░░░░░░░██",
  "██░░██░░░░██░░░░██",
  "██░░░░░░██░░░░░░██",
  "  ██░░░░░░░░░░██  ",
  "    ██░░░░░░██    ",
  "      ██████      ",
];

// Compact bear — 3 lines tall
const BEAR_COMPACT = [
  " ██  ██ ",
  "██░░░░██",
  " ██░░██ ",
];

const COMPACT_THRESHOLD = 80;

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
  const pad = Math.floor((width - vw) / 2);
  return " ".repeat(pad) + text;
}

export default function (pi: ExtensionAPI) {
  let visible = false;

  pi.on("session_start", async (_event, ctx) => {
    visible = true;
    const model = ctx.model?.id ?? "?";
    const dir = basename(ctx.cwd);
    const name = getUserName();
    const version = VERSION ?? "?";

    ctx.ui.setWidget(
      "welcome",
      (_tui, theme) => {
        const container = new Container();
        const borderFn = (s: string) => theme.fg("dim", s);
        container.addChild(new Text("", 0, 0));
        container.addChild(new DynamicBorder(borderFn));
        const body = new Text("", 1, 0);
        container.addChild(body);
        container.addChild(new DynamicBorder(borderFn));
        container.addChild(new Text("", 0, 0));

        return {
          render(width: number): string[] {
            const inner = width - 4;
            const compact = inner < COMPACT_THRESHOLD;

            if (compact) {
              // --- Compact: bear left, info right ---
              const art = BEAR_COMPACT;
              const artWidth = visibleWidth(art[0]);
              const gap = 2;
              const infoWidth = inner - artWidth - gap;

              const greeting = name
                ? theme.fg("accent", `Welcome ${name}`)
                : theme.fg("accent", "Welcome");

              const infoParts = [
                greeting,
                theme.fg("warning", `Pi v${version}`) +
                  theme.fg("dim", "  ·  ") +
                  theme.fg("success", model),
                theme.fg("dim", dir + "/"),
              ];

              const maxLines = Math.max(art.length, infoParts.length);
              const lines: string[] = [];
              for (let i = 0; i < maxLines; i++) {
                const artLine = i < art.length ? theme.fg("warning", art[i]) : " ".repeat(artWidth);
                const infoLine = i < infoParts.length ? infoParts[i] : "";
                const combined = " " + artLine + " ".repeat(gap) + truncateToWidth(infoLine, infoWidth);
                lines.push(truncateToWidth(combined, inner));
              }

              body.setText(lines.join("\n"));
            } else {
              // --- Full: centered bear + info below ---
              const lines: string[] = [];

              lines.push("");
              for (const row of BEAR_ART) {
                lines.push(center(theme.fg("warning", row), inner));
              }
              lines.push("");

              const greeting = name
                ? theme.fg("accent", `Welcome ${name}`)
                : theme.fg("accent", "Welcome");
              lines.push(center(greeting, inner));

              lines.push("");

              const info =
                theme.fg("warning", `Pi v${version}`) +
                theme.fg("dim", "  ·  ") +
                theme.fg("success", model);
              lines.push(center(info, inner));

              const dirLine = theme.fg("dim", dir + "/");
              lines.push(center(dirLine, inner));

              lines.push("");

              body.setText(lines.join("\n"));
            }

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

  pi.on("tool_call", async (_event, ctx) => {
    if (visible) {
      visible = false;
      ctx.ui.setWidget("welcome", undefined);
    }
  });
}
