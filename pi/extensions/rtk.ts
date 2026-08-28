/**
 * RTK (https://github.com/rtk-ai/rtk) integration for pi.dev.
 *
 * Rewrites bash commands through `rtk rewrite` to compress tool output
 * and save tokens. Falls back to the original command on any RTK error.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createBashTool } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { getAgentSettingsPath, readRtkConfig } from "./lib/pi-runtime.ts";
import { createRtkCommandRewriter, createRtkSpawnHook } from "./lib/rtk-runtime.ts";

export default function (pi: ExtensionAPI) {
  const cwd = process.cwd();
  const rtkConfig = readRtkConfig(getAgentSettingsPath());
  const rewriteCommand = createRtkCommandRewriter((command, env) =>
    execFileSync("rtk", ["rewrite", command], {
      encoding: "utf-8",
      timeout: rtkConfig.timeoutMs,
      env,
    }),
    rtkConfig,
  );
  const spawnHook = createRtkSpawnHook({ pathPrefix: null, rewriteCommand });

  const bashTool = createBashTool(cwd, {
    spawnHook,
  });

  pi.registerTool({
    ...bashTool,
  });
}
