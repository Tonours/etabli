import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

export interface HandoffInfo {
  path: string;
  ageHours: number;
  activeSlice?: string;
  nextAction?: string;
}

export function findHandoff(cwd: string): HandoffInfo | null {
  for (const relativePath of [".pi/handoff-implement.md", ".pi/handoff.md"]) {
    const path = join(cwd, relativePath);
    if (!existsSync(path)) continue;

    const content = readFileSync(path, "utf-8");
    const ageHours = (Date.now() - statSync(path).mtimeMs) / 3600000;
    return {
      path,
      ageHours,
      activeSlice: content.match(/Active slice:\s*(.+)/)?.[1]?.trim(),
      nextAction: content.match(/Next recommended action:\s*(.+)/)?.[1]?.trim(),
    };
  }

  return null;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const handoff = findHandoff(ctx.cwd);
    if (!handoff || handoff.ageHours > 24) return;

    const lines = [
      `Handoff detected (${Math.round(handoff.ageHours * 60)} min ago)`,
      handoff.activeSlice ? `Active: ${handoff.activeSlice}` : "",
      handoff.nextAction ? `Next: ${handoff.nextAction}` : "",
      "",
      "Commands:",
      "  /resume-from-handoff - Show resume tasks",
      "  /handoff-show - View the handoff file",
    ].filter(Boolean);

    pi.sendMessage({ customType: "auto-resume", content: lines.join("\n"), display: true });
  });

  pi.registerCommand("resume-from-handoff", {
    description: "Create suggested resume tasks from a handoff file",
    handler: async (_args, ctx) => {
      const handoff = findHandoff(ctx.cwd);
      if (!handoff) {
        ctx.ui.notify("No handoff found", "warning");
        return;
      }

      const tasks = ["Review handoff context"];
      if (handoff.activeSlice) tasks.push(`Resume: ${handoff.activeSlice}`);
      if (handoff.nextAction) tasks.push(handoff.nextAction);

      pi.sendMessage({
        customType: "resume-cmd",
        content: `Suggested tasks:\n${tasks.map((task, index) => `${index + 1}. ${task}`).join("\n")}`,
        display: true,
      });
      ctx.ui.notify(`${tasks.length} resume task(s) ready`, "info");
    },
  });

  pi.registerCommand("handoff-show", {
    description: "Show handoff content",
    handler: async (_args, ctx) => {
      const handoff = findHandoff(ctx.cwd);
      if (!handoff) {
        ctx.ui.notify("No handoff found", "warning");
        return;
      }

      pi.sendMessage({
        customType: "handoff-content",
        content: readFileSync(handoff.path, "utf-8"),
        display: true,
      });
    },
  });
}
