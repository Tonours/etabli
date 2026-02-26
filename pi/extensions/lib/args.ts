/**
 * Shared CLI argument parsing helpers for Pi extension commands.
 *
 * Used by: ship.ts, nightshift.ts
 */

import type { ExtensionCommandContext } from "@mariozechner/pi-coding-agent";

export interface ParsedCommandArgs {
  positional: string[];
  flags: Record<string, string | boolean>;
}

export function tokenizeArgs(input: string): string[] {
  const matches = input.match(/"([^"\\]|\\.)*"|'([^'\\]|\\.)*'|[^\s]+/g) ?? [];
  return matches.map((token) => {
    if ((token.startsWith('"') && token.endsWith('"')) || (token.startsWith("'") && token.endsWith("'"))) {
      const inner = token.slice(1, -1);
      return inner.replace(/\\\\/g, "\\").replace(/\\"/g, '"').replace(/\\'/g, "'");
    }
    return token;
  });
}

export function parseCommandArgs(raw: string): ParsedCommandArgs {
  const tokens = tokenizeArgs(raw);
  const positional: string[] = [];
  const flags: Record<string, string | boolean> = {};

  for (let i = 0; i < tokens.length; i += 1) {
    const token = tokens[i];
    if (!token) continue;

    if (!token.startsWith("--")) {
      positional.push(token);
      continue;
    }

    const rawFlag = token.slice(2);
    if (!rawFlag) continue;

    if (rawFlag.startsWith("no-")) {
      flags[rawFlag.slice(3)] = false;
      continue;
    }

    const eqIndex = rawFlag.indexOf("=");
    if (eqIndex >= 0) {
      const key = rawFlag.slice(0, eqIndex);
      const value = rawFlag.slice(eqIndex + 1);
      if (key) flags[key] = value;
      continue;
    }

    const next = tokens[i + 1];
    if (next && !next.startsWith("--")) {
      flags[rawFlag] = next;
      i += 1;
    } else {
      flags[rawFlag] = true;
    }
  }

  return { positional, flags };
}

export function getFlagValue(flags: Record<string, string | boolean>, names: string[]): string | boolean | undefined {
  for (const name of names) {
    if (Object.prototype.hasOwnProperty.call(flags, name)) {
      return flags[name];
    }
  }
  return undefined;
}

export function toBoolean(value: string | boolean | undefined, fallback: boolean): boolean {
  if (value === undefined) return fallback;
  if (typeof value === "boolean") return value;

  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "off"].includes(normalized)) return false;
  return fallback;
}

export function toOptionalString(value: string | boolean | undefined): string | undefined {
  if (value === undefined || typeof value === "boolean") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

export function notifyBlock(ctx: ExtensionCommandContext, text: string, level: "info" | "warning" | "error" = "info"): void {
  for (const line of text.split("\n")) {
    ctx.ui.notify(line.length > 0 ? line : " ", level);
  }
}
