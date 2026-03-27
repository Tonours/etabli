import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import {
  buildSetupChecks,
  formatSetupChecks,
  getAgentSettingsPath,
  getExtensionDirFromModule,
} from "./lib/pi-runtime.ts";

const EXTENSION_DIR = getExtensionDirFromModule(import.meta.url);
const SETTINGS_PATH = getAgentSettingsPath();

function buildReport(): string {
  return formatSetupChecks(
    buildSetupChecks({
      extensionDir: EXTENSION_DIR,
      settingsPath: SETTINGS_PATH,
    }),
  );
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "pi_setup_check",
    label: "Pi Setup Check",
    description:
      "Check the repo-local Pi setup. Reports agent settings wiring, extension symlinks, RTK, and subagent prerequisites.",
    parameters: Type.Object({}),
    async execute() {
      return {
        content: [{ type: "text" as const, text: buildReport() }],
        details: { report: buildReport() },
      };
    },
    renderResult(result, _options, theme) {
      const report =
        typeof result.details === "object" && result.details && "report" in result.details
          ? String((result.details as { report: string }).report)
          : result.content[0]?.type === "text"
            ? result.content[0].text
            : "";
      return new Text(theme.fg("muted", report), 0, 0);
    },
  });

  pi.registerCommand("pi-setup", {
    description: "Run a repo-local Pi setup health check",
    handler: async (_args, ctx) => {
      const report = buildReport();
      pi.sendMessage({
        customType: "pi-setup-check",
        content: report,
        display: true,
      });
      ctx.ui.notify("Pi setup check added to the session.", "info");
    },
  });
}
