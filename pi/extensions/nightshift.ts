/**
 * Nightshift extension for pi.
 *
 * Wraps the nightshift runner for overnight batch tasks.
 * Commands:
 *   /nightshift init [--force]     - Create tasks template
 *   /nightshift list               - List parsed tasks
 *   /nightshift run [--dry-run] [--verify-only] [--require-verify] - Execute tasks
 *   /nightshift status             - Show task status
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { parseCommandArgs, getFlagValue, toBoolean, toOptionalString, notifyBlock } from "./lib/args.ts";

const NIGHTSHIFT_BIN = join(homedir(), ".local", "bin", "nightshift");
const NIGHTSHIFT_SUBCOMMANDS = new Set(["init", "list", "run", "status"] as const);

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
  pi.registerCommand("nightshift", {
    description: "Overnight batch task runner",
    handler: async (args, ctx) => {
      const parsed = parseCommandArgs(args);
      const firstPositional = parsed.positional[0];
      const subcommand = NIGHTSHIFT_SUBCOMMANDS.has(firstPositional as "init" | "list" | "run" | "status")
        ? (firstPositional as "init" | "list" | "run" | "status")
        : undefined;

      if (!subcommand) {
        ctx.ui.notify("Usage: /nightshift <init|list|run|status> [--flags]", "warning");
        return;
      }

      const force = toBoolean(getFlagValue(parsed.flags, ["force"]), false);
      const dryRun = toBoolean(getFlagValue(parsed.flags, ["dry-run", "dryRun"]), false);
      const verifyOnly = toBoolean(getFlagValue(parsed.flags, ["verify-only", "verifyOnly"]), false);
      const requireVerify = toBoolean(getFlagValue(parsed.flags, ["require-verify", "requireVerify"]), false);
      const only = toOptionalString(getFlagValue(parsed.flags, ["only"]));

      const commandArgs: string[] = [subcommand];

      if (subcommand === "init" && force) {
        commandArgs.push("--force");
      }

      if (subcommand === "run") {
        if (dryRun) commandArgs.push("--dry-run");
        if (verifyOnly) commandArgs.push("--verify-only");
        if (requireVerify) commandArgs.push("--require-verify");
        if (only) {
          commandArgs.push("--only", only);
        }
      }

      const result = await runNightshift(commandArgs);

      if (result.code !== 0) {
        notifyBlock(ctx, `Nightshift ${subcommand} failed (exit ${result.code}):\n${result.stderr || result.stdout}`, "error");
        return;
      }

      notifyBlock(ctx, result.stdout || result.stderr || "Done.", "info");
    },
  });

  // Helper: quick task add via /nightshift-quick
  pi.registerCommand("nightshift-quick", {
    description: "Quickly add a nightshift task",
    handler: async (args, ctx) => {
      const parsed = parseCommandArgs(args);
      const repoFromFlag = toOptionalString(getFlagValue(parsed.flags, ["repo"]));
      const promptFromFlag = toOptionalString(getFlagValue(parsed.flags, ["prompt"]));
      const verify = toOptionalString(getFlagValue(parsed.flags, ["verify"]));
      const base = toOptionalString(getFlagValue(parsed.flags, ["base"])) ?? "main";
      const engineRaw = (toOptionalString(getFlagValue(parsed.flags, ["engine"])) ?? "codex").toLowerCase();
      const engine = engineRaw === "none" ? "none" : engineRaw === "codex" ? "codex" : undefined;

      const repo = repoFromFlag ?? parsed.positional[0];
      const promptPositional = parsed.positional.slice(1).join(" ").trim();
      const prompt = promptFromFlag ?? (promptPositional.length > 0 ? promptPositional : undefined);

      if (!repo || !prompt) {
        ctx.ui.notify("Usage: /nightshift-quick --repo <name> --prompt \"...\" [--verify \"...\"] [--engine codex|none] [--base main]", "warning");
        return;
      }
      if (!engine) {
        ctx.ui.notify("Invalid engine. Allowed values: codex, none.", "warning");
        return;
      }

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

      notifyBlock(
        ctx,
        `Added nightshift task: ${taskId}\nBranch: ${branch}\n\nRun with: /nightshift run --only ${taskId}`,
        "info",
      );
    },
  });
}
