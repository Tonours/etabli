/**
 * UV interceptor override.
 *
 * This extension keeps mitsupi's intercepted command behavior, but it wraps
 * the bash tool with a compatibility layer for both legacy and current
 * registerTool execute signatures.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { createBashTool } from "@mariozechner/pi-coding-agent";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

function isAbortSignal(value: unknown): value is AbortSignal {
  return (
    typeof value === "object" &&
    value !== null &&
    "aborted" in value &&
    "addEventListener" in value &&
    typeof (value as AbortSignal).addEventListener === "function"
  );
}

function isUpdateCallback(value: unknown): value is (update: unknown) => void {
  return typeof value === "function";
}

function resolveInterceptedCommandsPath(): string | null {
  try {
    const require = createRequire(import.meta.url);
    const packageJsonPath = require.resolve("mitsupi/package.json");
    return join(dirname(packageJsonPath), "intercepted-commands");
  } catch {
    return null;
  }
}

export default function (pi: ExtensionAPI) {
  const interceptedCommandsPath = resolveInterceptedCommandsPath();

  if (!interceptedCommandsPath) {
    pi.on("session_start", (_event, ctx) => {
      ctx.ui.notify("UV interceptor unavailable: npm:mitsupi not found", "warning");
    });
    return;
  }

  const bashTool = createBashTool(process.cwd(), {
    commandPrefix: `export PATH="${interceptedCommandsPath}:$PATH"`,
  });

  pi.on("session_start", (_event, ctx) => {
    ctx.ui.notify("UV interceptor loaded", "info");
  });

  pi.registerTool({
    ...bashTool,
    async execute(id, params, arg3, arg4, arg5) {
      let signal: AbortSignal | undefined;
      let onUpdate: ((update: unknown) => void) | undefined;

      // Current signature: (id, params, signal, onUpdate, ctx)
      if (isAbortSignal(arg3)) {
        signal = arg3;
        onUpdate = isUpdateCallback(arg4) ? arg4 : undefined;
      } else {
        // Legacy signature fallback: (id, params, onUpdate, ctx, signal)
        onUpdate = isUpdateCallback(arg3) ? arg3 : undefined;
        signal = isAbortSignal(arg5) ? arg5 : undefined;
      }

      return bashTool.execute(id, params, signal, onUpdate);
    },
  });
}
