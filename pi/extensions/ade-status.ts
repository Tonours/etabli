import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { formatAdeReadError, formatAdeStatus, readAdeSnapshotForCwd } from "./lib/ade-snapshot.ts";

function sync(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  const result = readAdeSnapshotForCwd(ctx.cwd);
  ctx.ui.setStatus("ade-status", result.ok && result.value ? formatAdeStatus(result.value) : formatAdeReadError(result));
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    sync(ctx);
  });

  pi.on("session_switch", async (_event, ctx) => {
    sync(ctx);
  });

  pi.on("input", async (_event, ctx) => {
    sync(ctx);
  });

  pi.on("agent_end", async (_event, ctx) => {
    sync(ctx);
  });
}
