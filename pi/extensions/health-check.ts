import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function getHomeDir(): string {
  return process.env.HOME || process.env.USERPROFILE || homedir();
}

export interface HealthCheck {
  component: string;
  status: "ok" | "warn" | "error";
  message: string;
  fix?: string;
}

export interface HealthReport {
  timestamp: string;
  cwd: string;
  checks: HealthCheck[];
  summary: {
    ok: number;
    warn: number;
    error: number;
    total: number;
  };
}

const EXTENSIONS = [
  "fast-handoff",
  "tilldone-ops-sync",
  "review-plan-bridge",
  "auto-validate",
  "workflow-metrics",
  "project-switcher",
  "task-templates",
  "auto-resume",
  "scope-guard",
  "pre-flight",
  "smart-context",
  "health-check",
  "error-recovery",
  "context-help",
];

export function checkExtensionFiles(cwd: string): HealthCheck[] {
  const extDir = join(cwd, "pi", "extensions");
  return EXTENSIONS.map((extension) => {
    const extFile = join(extDir, `${extension}.ts`);
    if (existsSync(extFile)) {
      return {
        component: `extension:${extension}`,
        status: "ok" as const,
        message: `${extension}.ts found`,
      };
    }
    return {
      component: `extension:${extension}`,
      status: "error" as const,
      message: `${extension}.ts missing`,
      fix: `Create pi/extensions/${extension}.ts`,
    };
  });
}

export function checkSettings(cwd: string): HealthCheck[] {
  const settingsPath = join(cwd, "pi", "agent", "settings.json");
  if (!existsSync(settingsPath)) {
    return [
      {
        component: "settings",
        status: "error",
        message: "settings.json not found",
        fix: "Create pi/agent/settings.json",
      },
    ];
  }

  try {
    const settings = JSON.parse(readFileSync(settingsPath, "utf-8")) as {
      packages?: Array<string | { source?: string; extensions?: string[] }>;
      subagents?: { scout?: { model?: string } };
    };

    const localWorkflowPackage = settings.packages?.find(
      (entry): entry is { source?: string; extensions?: string[] } =>
        typeof entry === "object" && (entry.source?.includes("etabli") || entry.source === "local:etabli-workflow"),
    );
    const packageRegistered = Boolean(localWorkflowPackage) || settings.packages?.some((entry) => typeof entry === "string" && entry.includes("etabli"));
    const missingRegisteredExtensions = (localWorkflowPackage?.extensions || []).filter(
      (extension) => !existsSync(join(cwd, "pi", "extensions", extension)),
    );

    return [
      {
        component: "settings:extensions",
        status: packageRegistered ? "ok" : "warn",
        message: packageRegistered ? "Etabli extensions registered" : "Extensions not registered in settings",
        fix: packageRegistered ? undefined : "Add local:etabli-workflow package to settings.json",
      },
      {
        component: "settings:local-package",
        status: missingRegisteredExtensions.length === 0 ? "ok" : "warn",
        message:
          missingRegisteredExtensions.length === 0
            ? "Local workflow package points at existing extension files"
            : `Missing extension files in settings: ${missingRegisteredExtensions.join(", ")}`,
        fix:
          missingRegisteredExtensions.length === 0
            ? undefined
            : "Sync pi/agent/settings.json with files in pi/extensions/",
      },
      {
        component: "settings:subagents",
        status: settings.subagents?.scout?.model ? "ok" : "warn",
        message: settings.subagents?.scout?.model ? "Subagent models configured" : "Subagent models not configured",
        fix: settings.subagents?.scout?.model ? undefined : "Add subagent configuration to settings.json",
      },
    ];
  } catch {
    return [
      {
        component: "settings",
        status: "error",
        message: "settings.json is invalid JSON",
        fix: "Fix JSON syntax in settings.json",
      },
    ];
  }
}

export function checkOpsSync(cwd: string): HealthCheck[] {
  const sanitized = cwd.replace(/[^a-zA-Z0-9._-]+/g, "_");
  const statusDir = join(getHomeDir(), ".pi", "status");
  const opsPath = join(statusDir, `${sanitized}.ops.json`);
  const tilldonePath = join(statusDir, `${sanitized}.tilldone-ops.json`);

  return [
    {
      component: "ops:snapshot",
      status: existsSync(opsPath) ? "ok" : "warn",
      message: existsSync(opsPath) ? "OPS snapshot exists" : "No OPS snapshot for this cwd",
      fix: existsSync(opsPath) ? undefined : "Open Neovim in this project to generate the OPS snapshot",
    },
    {
      component: "ops:tilldone",
      status: existsSync(tilldonePath) ? "ok" : "warn",
      message: existsSync(tilldonePath) ? "TillDone sync active" : "TillDone not synced",
      fix: existsSync(tilldonePath) ? undefined : "Create or sync TillDone tasks in Pi",
    },
  ];
}

export function checkNeovimIntegration(cwd: string): HealthCheck[] {
  const modulePath = join(cwd, "nvim", "lua", "config", "ops", "tilldone.lua");
  const initPath = join(cwd, "nvim", "lua", "config", "ops", "init.lua");
  const initContent = existsSync(initPath) ? readFileSync(initPath, "utf-8") : "";

  return [
    {
      component: "nvim:tilldone",
      status: existsSync(modulePath) ? "ok" : "warn",
      message: existsSync(modulePath) ? "TillDone module exists" : "TillDone module not found",
      fix: existsSync(modulePath) ? undefined : "Add nvim/lua/config/ops/tilldone.lua",
    },
    {
      component: "nvim:ops-init",
      status: initContent.includes('require("config.ops.tilldone")') || initContent.includes("config.ops.tilldone") ? "ok" : "warn",
      message:
        initContent.includes("config.ops.tilldone") ? "TillDone module wired in OPS init" : "TillDone module may not be wired in OPS init",
      fix: initContent.includes("config.ops.tilldone") ? undefined : "Require config.ops.tilldone from nvim/lua/config/ops/init.lua",
    },
  ];
}

export function checkClaudeCommands(cwd: string): HealthCheck[] {
  const commandsDir = join(cwd, "claude", "commands");
  return ["ops-status.md", "ops-pi-status.md"].map((command) => {
    const commandPath = join(commandsDir, command);
    return {
      component: `claude:${command}`,
      status: existsSync(commandPath) ? ("ok" as const) : ("warn" as const),
      message: existsSync(commandPath) ? `${command} exists` : `${command} missing`,
      fix: existsSync(commandPath) ? undefined : `Create claude/commands/${command}`,
    };
  });
}

export function runHealthCheck(cwd: string): HealthReport {
  const checks = [
    ...checkExtensionFiles(cwd),
    ...checkSettings(cwd),
    ...checkOpsSync(cwd),
    ...checkNeovimIntegration(cwd),
    ...checkClaudeCommands(cwd),
  ];

  return {
    timestamp: new Date().toISOString(),
    cwd,
    checks,
    summary: {
      ok: checks.filter((check) => check.status === "ok").length,
      warn: checks.filter((check) => check.status === "warn").length,
      error: checks.filter((check) => check.status === "error").length,
      total: checks.length,
    },
  };
}

export function formatReport(report: HealthReport): string {
  const icons = { ok: "✓", warn: "⚠", error: "✗" } as const;
  const errors = report.checks.filter((check) => check.status === "error");
  const warnings = report.checks.filter((check) => check.status === "warn");
  const lines = ["Health Check Report", "===================", "", `Time: ${report.timestamp}`, `CWD: ${report.cwd}`, ""];

  if (errors.length > 0) {
    lines.push("Errors:");
    for (const check of errors) {
      lines.push(`  ${icons.error} ${check.component}: ${check.message}`);
      if (check.fix) lines.push(`    Fix: ${check.fix}`);
    }
    lines.push("");
  }

  if (warnings.length > 0) {
    lines.push("Warnings:");
    for (const check of warnings) {
      lines.push(`  ${icons.warn} ${check.component}: ${check.message}`);
    }
    lines.push("");
  }

  lines.push(`Summary: ${report.summary.ok} ok, ${report.summary.warn} warn, ${report.summary.error} error`);
  if (report.summary.error === 0 && report.summary.warn === 0) {
    lines.push("", "All systems operational.");
  }

  return lines.join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("health", {
    description: "Run unified health check",
    handler: async (_args, ctx) => {
      const report = runHealthCheck(ctx.cwd);
      pi.sendMessage({ customType: "health-check", content: formatReport(report), display: true });

      if (report.summary.error > 0) {
        ctx.ui.notify(`${report.summary.error} error(s) found`, "error");
      } else if (report.summary.warn > 0) {
        ctx.ui.notify(`${report.summary.warn} warning(s)`, "warning");
      } else {
        ctx.ui.notify("All systems operational", "info");
      }
    },
  });

  pi.registerTool({
    name: "health_check",
    label: "Health Check",
    description: "Run a workflow health check for this repo.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _args, _signal, _onUpdate, ctx) {
      const report = runHealthCheck(ctx.cwd);
      return {
        content: [{ type: "text" as const, text: formatReport(report) }],
        details: {
          healthy: report.summary.error === 0,
          summary: report.summary,
          errors: report.checks.filter((check) => check.status === "error"),
          warnings: report.checks.filter((check) => check.status === "warn"),
        },
      };
    },
  });
}
