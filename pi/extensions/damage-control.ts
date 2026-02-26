/**
 * Damage Control — PRE-EXECUTION safety gate for dangerous tool calls.
 *
 * Security layer 1 of 2 (with filter-output.ts):
 *   - damage-control.ts → intercepts tool_call BEFORE execution → blocks or asks
 *   - filter-output.ts  → intercepts tool_result AFTER execution  → redacts secrets
 *
 * Intercepts tool_call events and blocks or asks confirmation for dangerous
 * commands based on rules loaded from damage-control-rules.json.
 *
 * Rule file lookup order:
 *   1. <cwd>/.pi/damage-control-rules.json  (per-project override)
 *   2. ~/.pi/damage-control-rules.json       (global default)
 *
 * Usage: loaded via settings.json packages or `pi -e extensions/damage-control.ts`
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, isAbsolute, resolve, relative } from "node:path";

interface Rule {
  pattern: string;
  reason: string;
  ask?: boolean;
}

interface CompiledRule {
  regex: RegExp;
  reason: string;
  ask: boolean;
}

interface Rules {
  bashToolPatterns: Rule[];
  zeroAccessPaths: string[];
  readOnlyPaths: string[];
  noDeletePaths: string[];
}

const EMPTY_RULES: Rules = {
  bashToolPatterns: [],
  zeroAccessPaths: [],
  readOnlyPaths: [],
  noDeletePaths: [],
};

const RULES_FILENAME = "damage-control-rules.json";

function resolveTilde(p: string): string {
  return p.startsWith("~") ? join(homedir(), p.slice(1)) : p;
}

function isPathMatch(targetPath: string, pattern: string, cwd: string): boolean {
  const resolvedPattern = resolveTilde(pattern);

  if (resolvedPattern.endsWith("/")) {
    const abs = isAbsolute(resolvedPattern) ? resolvedPattern : resolve(cwd, resolvedPattern);
    return targetPath.startsWith(abs);
  }

  const escaped = resolvedPattern
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*");

  const regex = new RegExp(`^${escaped}$|^${escaped}/|/${escaped}$|/${escaped}/`);
  const rel = relative(cwd, targetPath);

  return (
    regex.test(targetPath) ||
    regex.test(rel) ||
    targetPath.includes(resolvedPattern) ||
    rel.includes(resolvedPattern)
  );
}

function loadRules(cwd: string): { rules: Rules; source: string } {
  const projectPath = join(cwd, ".pi", RULES_FILENAME);
  const globalPath = join(homedir(), ".pi", RULES_FILENAME);

  for (const candidate of [projectPath, globalPath]) {
    if (!existsSync(candidate)) continue;
    try {
      const raw = JSON.parse(readFileSync(candidate, "utf-8")) as Partial<Rules>;
      return {
        rules: {
          bashToolPatterns: raw.bashToolPatterns ?? [],
          zeroAccessPaths: raw.zeroAccessPaths ?? [],
          readOnlyPaths: raw.readOnlyPaths ?? [],
          noDeletePaths: raw.noDeletePaths ?? [],
        },
        source: candidate,
      };
    } catch (err) {
      return { rules: EMPTY_RULES, source: `${candidate} (parse error: ${err})` };
    }
  }

  return { rules: EMPTY_RULES, source: "none" };
}

function countRules(rules: Rules): number {
  return (
    rules.bashToolPatterns.length +
    rules.zeroAccessPaths.length +
    rules.readOnlyPaths.length +
    rules.noDeletePaths.length
  );
}

function blockMessage(reason: string): string {
  return (
    `BLOCKED by Damage-Control: ${reason}\n\n` +
    "DO NOT attempt to work around this restriction. " +
    "DO NOT retry with alternative commands, paths, or approaches that achieve the same result. " +
    "Report this block to the user exactly as stated and ask how they would like to proceed."
  );
}

export default function (pi: ExtensionAPI) {
  let rules: Rules = EMPTY_RULES;
  let compiledBashRules: CompiledRule[] = [];

  pi.on("session_start", async (_event, ctx) => {
    const loaded = loadRules(ctx.cwd);
    rules = loaded.rules;

    compiledBashRules = [];
    for (const rule of rules.bashToolPatterns) {
      try {
        compiledBashRules.push({
          regex: new RegExp(rule.pattern),
          reason: rule.reason,
          ask: !!rule.ask,
        });
      } catch (e) {
        ctx.ui.notify(`Damage-Control: invalid pattern "${rule.pattern}": ${e}`, "error");
      }
    }

    const total = countRules(rules);

    if (total > 0) {
      ctx.ui.notify(`Damage-Control: loaded ${total} rules from ${loaded.source}`, "info");
    } else {
      ctx.ui.notify("Damage-Control: no rules found", "warning");
    }

    ctx.ui.setStatus("damage-control", `${total} rules active`);
  });

  pi.on("tool_call", async (event, ctx) => {
    let violationReason: string | null = null;
    let shouldAsk = false;

    // --- Extract paths from tool input ---
    const inputPaths: string[] = [];
    if (
      isToolCallEventType("read", event) ||
      isToolCallEventType("write", event) ||
      isToolCallEventType("edit", event)
    ) {
      inputPaths.push(event.input.path);
    }

    // --- Check zero-access paths on file tools ---
    for (const p of inputPaths) {
      const resolved = isAbsolute(p) ? p : resolve(ctx.cwd, p);
      for (const zap of rules.zeroAccessPaths) {
        if (isPathMatch(resolved, zap, ctx.cwd)) {
          violationReason = `Access to protected path restricted: ${zap}`;
          break;
        }
      }
      if (violationReason) break;
    }

    // --- Check read-only paths for write/edit ---
    if (
      !violationReason &&
      (isToolCallEventType("write", event) || isToolCallEventType("edit", event))
    ) {
      for (const p of inputPaths) {
        const resolved = isAbsolute(p) ? p : resolve(ctx.cwd, p);
        for (const rop of rules.readOnlyPaths) {
          if (isPathMatch(resolved, rop, ctx.cwd)) {
            violationReason = `Modification of read-only path restricted: ${rop}`;
            break;
          }
        }
        if (violationReason) break;
      }
    }

    // --- Check bash commands ---
    if (!violationReason && isToolCallEventType("bash", event)) {
      const command = event.input.command;

      for (const rule of compiledBashRules) {
        if (rule.regex.test(command)) {
          violationReason = rule.reason;
          shouldAsk = rule.ask;
          break;
        }
      }

      if (!violationReason) {
        for (const zap of rules.zeroAccessPaths) {
          if (command.includes(zap) || command.includes(resolveTilde(zap))) {
            violationReason = `Bash command references protected path: ${zap}`;
            break;
          }
        }
      }

      if (!violationReason) {
        for (const rop of rules.readOnlyPaths) {
          const hasModifier = /[>|]/.test(command) || /\b(rm|mv|sed)\b/.test(command);
          if (hasModifier && (command.includes(rop) || command.includes(resolveTilde(rop)))) {
            violationReason = `Bash command may modify read-only path: ${rop}`;
            break;
          }
        }
      }

      if (!violationReason) {
        for (const ndp of rules.noDeletePaths) {
          const hasDelete = /\b(rm|mv)\b/.test(command);
          if (hasDelete && (command.includes(ndp) || command.includes(resolveTilde(ndp)))) {
            violationReason = `Bash command attempts to delete/move protected path: ${ndp}`;
            break;
          }
        }
      }
    }

    // --- Handle violation ---
    if (!violationReason) return { block: false };

    if (shouldAsk) {
      const input = isToolCallEventType("bash", event)
        ? event.input.command
        : JSON.stringify(event.input);

      const confirmed = await ctx.ui.confirm(
        "Damage-Control Confirmation",
        `Dangerous operation detected: ${violationReason}\n\nCommand: ${input}\n\nDo you want to proceed?`,
        { timeout: 30000 },
      );

      if (confirmed) {
        pi.appendEntry("damage-control-log", {
          tool: event.toolName,
          input: event.input,
          rule: violationReason,
          action: "confirmed_by_user",
        });
        return { block: false };
      }
    }

    ctx.ui.notify(`Damage-Control: blocked ${event.toolName} — ${violationReason}`, "warning");
    ctx.ui.setStatus("damage-control", `Blocked: ${violationReason.slice(0, 40)}...`);
    pi.appendEntry("damage-control-log", {
      tool: event.toolName,
      input: event.input,
      rule: violationReason,
      action: shouldAsk ? "blocked_by_user" : "blocked",
    });
    ctx.abort();
    return { block: true, reason: blockMessage(violationReason) };
  });
}
