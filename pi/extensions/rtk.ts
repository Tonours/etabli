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

  const bashTool = createBashTool(cwd, {
    // UV intercepted commands (pip→uv, python→uv run, etc.)
    commandPrefix: interceptedCommandsPath
      ? `export PATH="${interceptedCommandsPath}:$PATH"`
      : undefined,

    // RTK rewrite (git→rtk git, cat→rtk read, etc.)
    spawnHook: ({ command, cwd, env }) => {
      try {
        const rewritten = execFileSync("rtk", ["rewrite", command], {
          encoding: "utf-8",
          timeout: 3000,
          env,
        }).trim();

        if (rewritten.length > 0 && rewritten !== command) {
          return { command: rewritten, cwd, env };
        }
      } catch {
        // rtk rewrite exits 1 when no rewrite applies — expected
      }
      return { command, cwd, env };
    },
  });

  pi.registerTool({
    ...bashTool,
    execute: async (id, params, signal, onUpdate) => {
      return bashTool.execute(id, params, signal, onUpdate);
    },
  });
}
