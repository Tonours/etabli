/**
 * RTK (https://github.com/rtk-ai/rtk) integration for pi.dev.
 *
 * Rewrites bash commands through `rtk rewrite` to compress tool output
 * and save tokens. Also preserves mitsupi's UV intercepted commands PATH.
 * Falls back to the original command on any RTK error.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { createBashTool } from "@mariozechner/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { createRtkCommandRewriter, createRtkSpawnHook } from "./lib/rtk-runtime.ts";

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
  const cwd = process.cwd();
  const interceptedCommandsPath = resolveInterceptedCommandsPath();
  const rewriteCommand = createRtkCommandRewriter((command, env) =>
    execFileSync("rtk", ["rewrite", command], {
      encoding: "utf-8",
      timeout: 3000,
      env,
    }),
  );
  const spawnHook = createRtkSpawnHook({ pathPrefix: interceptedCommandsPath, rewriteCommand });

  const bashTool = createBashTool(cwd, {
    // UV intercepted commands (pip→uv, python→uv run, etc.) plus RTK rewrite
    spawnHook,
  });

  pi.registerTool({
    ...bashTool,
    execute: async (id, params, signal, onUpdate) => {
      return bashTool.execute(id, params, signal, onUpdate);
    },
  });
}
