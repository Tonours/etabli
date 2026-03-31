import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { formatOpsReadError, formatOpsStatus, readOpsSnapshotForCwd } from "./lib/ops-snapshot.ts";

function sync(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  const result = readOpsSnapshotForCwd(ctx.cwd);
  ctx.ui.setStatus("ops-status", result.ok && result.value ? formatOpsStatus(result.value) : formatOpsReadError(result));
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
