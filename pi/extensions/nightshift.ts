/**
 * Nightshift extension for pi.
 *
 * Wraps the nightshift runner for overnight batch tasks.
 * Commands:
 *   /nightshift init [--force]     - Create tasks template
 *   /nightshift list               - List parsed tasks
 *   /nightshift run [--dry-run] [--verify-only] - Execute tasks
 *   /nightshift status             - Show task status
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const NIGHTSHIFT_BIN = join(homedir(), ".local", "bin", "nightshift");

const STATE_DIR = join(homedir(), ".local", "state", "nightshift");
const TASKS_FILE = join(STATE_DIR, "tasks.md");

function runNightshift(args: string[]): Promise<{ stdout: string; stderr: string; code: number }> {
  return new Promise((resolve) => {
    const bin = existsSync(NIGHTSHIFT_BIN) ? NIGHTSHIFT_BIN : "nightshift";
    const child = spawn(bin, args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, CLICOLOR_FORCE: "1" },
    });

    let stdout = "";
    let stderr = "";

    child.stdout?.on("data", (data) => {
      stdout += data.toString();
    });

    child.stderr?.on("data", (data) => {
      stderr += data.toString();
    });

    child.on("error", (error) => {
      resolve({ stdout, stderr: `${stderr}\n${error.message}`.trim(), code: 127 });
    });

    child.on("close", (code) => {
      resolve({ stdout, stderr, code: code ?? 1 });
    });
  });
}

export default function (pi: ExtensionAPI) {
  // Register /nightshift command
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.notify("Nightshift extension loaded — /nightshift {init,list,run,status}", "info");
  });

  pi.registerCommand({
    name: "nightshift",
    description: "Overnight batch task runner",
    parameters: {
      type: "object",
      properties: {
        subcommand: {
          type: "string",
          enum: ["init", "list", "run", "status"],
          description: "Subcommand to execute",
        },
        force: {
          type: "boolean",
          description: "Force overwrite for init",
        },
        dryRun: {
          type: "boolean",
          description: "Dry run mode for run command",
        },
        verifyOnly: {
          type: "boolean",
          description: "Run checks only, skip commit/push",
        },
        only: {
          type: "string",
          description: "Comma-separated task IDs to run",
        },
      },
      required: ["subcommand"],
    },
    async execute(params) {
      const { subcommand, force, dryRun, verifyOnly, only } = params as {
        subcommand: string;
        force?: boolean;
        dryRun?: boolean;
        verifyOnly?: boolean;
        only?: string;
      };

      const args: string[] = [subcommand];

      if (subcommand === "init" && force) {
        args.push("--force");
      }

      if (subcommand === "run") {
        if (dryRun) args.push("--dry-run");
        if (verifyOnly) args.push("--verify-only");
        if (only) {
          args.push("--only", only);
        }
      }

      const result = await runNightshift(args);

      if (result.code !== 0) {
        return {
          content: [
            { type: "text", text: `Nightshift ${subcommand} failed (exit ${result.code}):` },
            { type: "text", text: result.stderr || result.stdout },
          ],
          isError: true,
        };
      }

      return {
        content: [{ type: "text", text: result.stdout || result.stderr || "Done." }],
      };
    },
  });

  // Helper: quick task add via /nightshift-quick
  pi.registerCommand({
    name: "nightshift-quick",
    description: "Quickly add a nightshift task",
    parameters: {
      type: "object",
      properties: {
        repo: { type: "string", description: "Repository name (under $PI_PROJECT_ROOT)" },
        prompt: { type: "string", description: "Task prompt" },
        verify: { type: "string", description: "Verify command (optional)" },
        engine: { type: "string", enum: ["codex", "none"], default: "codex" },
        base: { type: "string", default: "main" },
      },
      required: ["repo", "prompt"],
    },
    async execute(params) {
      const { repo, prompt, verify, engine = "codex", base = "main" } = params as {
        repo: string;
        prompt: string;
        verify?: string;
        engine?: "codex" | "none";
        base?: string;
      };

      // Generate task ID from prompt
      const taskId = prompt
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .slice(0, 40)
        .replace(/^-+|-+$/g, "");

      const branch = `night/${taskId}`;

      // Read existing tasks or create new
      const { readFileSync, writeFileSync, mkdirSync } = await import("node:fs");
      
      try {
        mkdirSync(STATE_DIR, { recursive: true });
      } catch {
        // ignore
      }

      let existing = "";
      try {
        existing = readFileSync(TASKS_FILE, "utf-8");
      } catch {
        existing = "# Night Shift Tasks\n\n";
      }

      const taskBlock = `## TASK ${taskId}
repo: ${repo}
base: ${base}
branch: ${branch}
engine: ${engine}${verify ? "\nverify:\n- " + verify : ""}
prompt:
${prompt}
ENDPROMPT

`;

      writeFileSync(TASKS_FILE, existing + taskBlock, "utf-8");

      return {
        content: [
          { type: "text", text: `Added nightshift task: ${taskId}` },
          { type: "text", text: `Branch: ${branch}` },
          { type: "text", text: `\nRun with: /nightshift run --only ${taskId}` },
        ],
      };
    },
  });
}
