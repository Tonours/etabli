/**
 * Welcome — startup banner with session info + random message.
 * Clears on first tool call.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { DynamicBorder } from "@mariozechner/pi-coding-agent";
import { Container, Text, truncateToWidth } from "@mariozechner/pi-tui";
import { basename } from "node:path";

const BEAR = [
  "  ʕ •ᴥ•ʔ",
  " ʕ￫ᴥ￩ʔ",
  " ʕ •ᴥ•ʔﾉ",
  " ʕ·ᴥ·ʔ☆",
  " ʕ ꈍᴥꈍʔ",
  " ʕ ᵔᴥᵔ ʔ",
  " ʕ •̀ᴥ•́ʔ",
];

const MESSAGES = [
  "Café chargé. Code en approche.",
  "Il n'y a pas de bug, que des features non documentées.",
  "La réponse est 42. La question est ailleurs.",
  "YAGNI, KISS, DRY — dans cet ordre.",
  "Aujourd'hui on ship, demain on fix.",
  "Un bon code est un code supprimé.",
  "C'est pas un bug, c'est du machine learning.",
  "La perfection, c'est quand il n'y a plus rien à enlever.",
  "Ça marchait sur ma machine...",
  "Première règle : on ne parle pas du code legacy.",
  "Le meilleur moment pour refactorer c'était hier.",
  "Pas de tests, pas de bugs. Logique.",
  "On déploie vendredi soir ? Pourquoi pas.",
  "Simple > clever. Obvious > elegant.",
  "Three similar lines > one premature helper.",
  "Mesure deux fois, coupe une fois.",
  "Keep calm and git rebase.",
  "La doc, c'est pour les faibles. Et les gens intelligents.",
  "Ctrl+Z est mon meilleur ami.",
  "Tout est possible avec assez de stack overflow.",
];

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

export default function (pi: ExtensionAPI) {
  let visible = false;

  pi.on("session_start", async (_event, ctx) => {
    visible = true;
    const model = ctx.model?.id ?? "?";
    const dir = basename(ctx.cwd);
    const bear = pick(BEAR);
    const msg = pick(MESSAGES);

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
            const lines = [
              theme.fg("accent", ` ${bear}  Pi`) +
                theme.fg("dim", "  —  ") +
                theme.fg("success", model),
              theme.fg("dim", " DC: ") +
                theme.fg("success", "light") +
                theme.fg("dim", "  │  ") +
                theme.fg("accent", dir) +
                theme.fg("dim", "/"),
              "",
              theme.fg("dim", ` "${msg}"`),
            ];
            body.setText(lines.map((l) => truncateToWidth(l, inner)).join("\n"));
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
