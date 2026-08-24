import { delimiter } from "node:path";
import { hash as cryptoHash } from "node:crypto";
import type { RtkConfig } from "./pi-runtime.ts";

export type RewriteEnv = Record<string, string | undefined> | undefined;
export type RewriteRunner = (command: string, env: RewriteEnv) => string;
export type RtkSpawnContext = {
  command: string;
  cwd: string;
  env: Record<string, string | undefined>;
};

type RewriteError = {
  code?: unknown;
  status?: unknown;
};

export type RtkRuntimeState = {
  cacheSize: number;
  cacheHits: number;
  cacheMisses: number;
  rewrites: number;
  bypasses: number;
  disabled: boolean;
  lastBypassReason: string | null;
};

type ManagedRtkConfig = Pick<
  RtkConfig,
  "enabled" | "mode" | "maxCacheEntries" | "maxCommandLength" | "dangerousCommandBypass"
>;

let cacheSize = 0;
let cacheHits = 0;
let cacheMisses = 0;
let rewrites = 0;
let bypasses = 0;
let disabled = false;
let lastBypassReason: string | null = null;

function isMissingBinaryError(error: unknown): boolean {
  return typeof error === "object" && error !== null && (error as RewriteError).code === "ENOENT";
}

function isExpectedNoRewriteError(error: unknown): boolean {
  return typeof error === "object" && error !== null && (error as RewriteError).status === 1;
}

function noteBypass(reason: string): void {
  bypasses += 1;
  lastBypassReason = reason;
}

function commandFlags(command: string, pattern: RegExp): string[] {
  const match = command.match(pattern);
  if (!match) return [];

  return match[2]?.match(/--[A-Za-z-]+|-[A-Za-z]+/g) ?? [];
}

function flagsInclude(flags: string[], shortFlag: string, longFlag: string): boolean {
  return flags.some((flag) => {
    if (flag === longFlag) return true;
    if (!flag.startsWith("--")) return flag.toLowerCase().includes(shortFlag);
    return false;
  });
}

function hasRecursiveForceRm(command: string): boolean {
  const flags = commandFlags(command, /(^|[\s;&()])rm\s+((?:(?:--[A-Za-z-]+|-[A-Za-z]+)(?:\s+|$))*)/);
  return flagsInclude(flags, "r", "--recursive") && flagsInclude(flags, "f", "--force");
}

function hasForceDirectoryGitClean(command: string): boolean {
  const flags = commandFlags(command, /(^|[\s;&()])git\s+clean\s+((?:(?:--[A-Za-z-]+|-[A-Za-z]+)(?:\s+|$))*)/);
  return flagsInclude(flags, "f", "--force") && flagsInclude(flags, "d", "--directory");
}

function isDangerousCommand(command: string): boolean {
  return (
    /(^|[\s;&()])(sudo\b|dd\b|mkfs\b|fdisk\b|parted\b|diskutil\b|mount\b|umount\b|chmod\b|chown\b|chgrp\b|git\s+reset\s+--hard\b)/.test(command)
    || hasRecursiveForceRm(command)
    || hasForceDirectoryGitClean(command)
  );
}

function isWsCharCode(code: number): boolean {
  if (code === 32 || (code >= 9 && code <= 13)) return true;
  if (code < 128) return false;
  return (
    code === 0x00a0
    || code === 0x1680
    || (code >= 0x2000 && code <= 0x200a)
    || code === 0x2028
    || code === 0x2029
    || code === 0x202f
    || code === 0x205f
    || code === 0x3000
    || code === 0xfeff
  );
}

function findBypassReason(
  command: string,
  enabled: boolean,
  mode: string,
  maxCommandLength: number,
  dangerousCommandBypass: boolean,
): string | null {
  const trimmed = command.trim();
  if (trimmed.length === 0) return null;
  if (!enabled || mode === "off") return "disabled";
  if (trimmed.includes("\n")) return "multiline";
  if (/(^|\s)<<-?\s*['"]?[A-Za-z0-9_]+['"]?/.test(trimmed)) return "heredoc";
  if (trimmed.length > maxCommandLength) return "command-too-long";
  if (trimmed.includes("|")) return "pipeline";
  if (dangerousCommandBypass && isDangerousCommand(trimmed)) {
    return "dangerous-command";
  }
  return null;
}

function envFingerprint(env: RewriteEnv): string {
  if (!env) return "none";

  let payload = "";
  for (const key of Object.keys(env).sort()) {
    const value = env[key];
    payload += `${key.length}:${key}:${value === undefined ? "" : `${value.length}:${value}`}`;
  }

  return cryptoHash("sha256", payload, "hex").slice(0, 16);
}

export function prependPathToEnv(env: RewriteEnv, pathPrefix: string | null): RewriteEnv {
  if (!pathPrefix) return env;
  return {
    ...(env ?? {}),
    PATH: env?.PATH ? `${pathPrefix}${delimiter}${env.PATH}` : pathPrefix,
  };
}

export function getRtkRuntimeState(): RtkRuntimeState {
  return {
    cacheSize,
    cacheHits,
    cacheMisses,
    rewrites,
    bypasses,
    disabled,
    lastBypassReason,
  };
}

export function resetRtkRuntimeState(): void {
  cacheSize = 0;
  cacheHits = 0;
  cacheMisses = 0;
  rewrites = 0;
  bypasses = 0;
  disabled = false;
  lastBypassReason = null;
}

export function createRtkCommandRewriter(
  runRewrite: RewriteRunner,
  config: ManagedRtkConfig,
): (command: string, env?: RewriteEnv) => string {
  const { enabled, mode, maxCacheEntries, maxCommandLength, dangerousCommandBypass } = config;

  type RewriterEntry = {
    command: string;
    bypass: string | null;
    fingerprint: string | null;
    value: string;
    extra: Map<string, string> | null;
    slotIdx: number;
  };

  type RewriterSlot = {
    command: string;
    fingerprint: string;
    value: string;
  };

  // Single map keyed by command: memoized bypass decision + cached results.
  // fingerprint/value act as a single-entry fast path (pointer-comparable
  // fingerprint for the common one-env case); extra holds additional envs.
  const entries = new Map<string, RewriterEntry>();
  const disabledFingerprints = new Set<string>();
  let noneDisabled = false;
  const bypassOnlyCap = Math.max(maxCacheEntries, 16);
  let bypassOnlyCount = 0;
  let cachePairCount = 0;
  // L1 direct-mapped accelerator over the entries map (invalidated on pair
  // eviction so it can never serve a value the LRU would have evicted).
  const slots = Array.from({ length: 64 }, (): RewriterSlot | undefined => undefined);
  resetRtkRuntimeState();

  const slotIndex = (command: string): number => {
    const length = command.length;
    return (command.charCodeAt(0) * 31 + command.charCodeAt(length - 1) + length) & 63;
  };

  const rememberBypass = (command: string, reason: string): void => {
    entries.set(command, { command, bypass: reason, fingerprint: null, value: "", extra: null, slotIdx: -1 });
    bypassOnlyCount += 1;

    while (bypassOnlyCount > bypassOnlyCap) {
      let removed = false;
      for (const [oldestCommand, oldestEntry] of entries) {
        if (oldestEntry.bypass === null) continue;
        entries.delete(oldestCommand);
        removed = true;
        break;
      }
      if (!removed) break;
      bypassOnlyCount -= 1;
    }
  };

  const rememberResult = (command: string, fingerprint: string, value: string): void => {
    let entry = entries.get(command);
    if (entry === undefined || entry.bypass !== null) {
      entry = { command, bypass: null, fingerprint: null, value: "", extra: null, slotIdx: -1 };
      entries.set(command, entry);
    }

    if (entry.fingerprint === fingerprint) {
      entry.value = value;
      if (entry.slotIdx >= 0) slots[entry.slotIdx]!.value = value;
    } else if (entry.extra !== null && entry.extra.has(fingerprint)) {
      entry.extra.set(fingerprint, value);
    } else if (entry.fingerprint === null) {
      entry.fingerprint = fingerprint;
      entry.value = value;
      cachePairCount += 1;

      const idx = slotIndex(command);
      const existing = slots[idx];
      if (existing !== undefined) {
        const other = entries.get(existing.command);
        if (other !== undefined && other.slotIdx === idx) other.slotIdx = -1;
      }
      slots[idx] = { command, fingerprint, value };
      entry.slotIdx = idx;
    } else {
      if (entry.extra === null) entry.extra = new Map();
      entry.extra.set(fingerprint, value);
      cachePairCount += 1;
    }

    while (cachePairCount > maxCacheEntries) {
      let dropped = false;
      for (const [oldestCommand, oldestEntry] of entries) {
        if (oldestEntry.bypass !== null) continue;
        if (oldestEntry.extra !== null && oldestEntry.extra.size > 0) {
          const oldestFingerprint = oldestEntry.extra.keys().next().value;
          if (oldestFingerprint === undefined) break;
          oldestEntry.extra.delete(oldestFingerprint);
          cachePairCount -= 1;
          dropped = true;
        } else if (oldestEntry.fingerprint !== null) {
          const slotIdx = oldestEntry.slotIdx;
          if (slotIdx >= 0) {
            const slot = slots[slotIdx];
            if (slot !== undefined && slot.command === oldestCommand) slots[slotIdx] = undefined;
            oldestEntry.slotIdx = -1;
          }
          oldestEntry.fingerprint = null;
          oldestEntry.value = "";
          cachePairCount -= 1;
          dropped = true;
        }
        if (dropped) {
          if (oldestEntry.fingerprint === null && (oldestEntry.extra === null || oldestEntry.extra.size === 0)) {
            entries.delete(oldestCommand);
          }
          break;
        }
      }
      if (!dropped) break;
    }

    cacheSize = cachePairCount;
  };

  return (command: string, env?: RewriteEnv): string => {
    const length = command.length;
    const first = command.charCodeAt(0);
    const last = command.charCodeAt(length - 1);
    const fingerprint = env === undefined ? "none" : envFingerprint(env);

    // L1 slot probe: slots only ever hold non-empty, non-bypassed cached pairs,
    // so a hit also proves the whitespace check below unnecessary. The
    // disabled-fingerprint flag can flip after insertion, so verify it here.
    // (For the empty string, NaN & 63 === 0 and slot.command !== "".)
    const disabledNow = env === undefined ? noneDisabled : disabledFingerprints.has(fingerprint);
    if (!disabledNow) {
      const slot = slots[(first * 31 + last + length) & 63];
      if (
        slot !== undefined
        && slot.command === command
        && slot.fingerprint === fingerprint
      ) {
        cacheHits += 1;
        return slot.value;
      }
    }

    if (length === 0 || isWsCharCode(first) || isWsCharCode(last)) {
      if (command.trim().length === 0) return command;
    }

    const entry = entries.get(command);
    if (entry !== undefined) {
      if (entry.bypass !== null) {
        noteBypass(entry.bypass);
        return command;
      }
    } else {
      const bypassReason = findBypassReason(command, enabled, mode, maxCommandLength, dangerousCommandBypass);
      if (bypassReason !== null) {
        rememberBypass(command, bypassReason);
        noteBypass(bypassReason);
        return command;
      }
    }

    if (disabledNow) {
      noteBypass("missing-binary");
      return command;
    }

    if (entry !== undefined) {
      if (entry.fingerprint === fingerprint) {
        cacheHits += 1;
        return entry.value;
      }
      const cached = entry.extra !== null ? entry.extra.get(fingerprint) : undefined;
      if (cached !== undefined) {
        cacheHits += 1;
        return cached;
      }
    }

    cacheMisses += 1;

    try {
      const rewritten = runRewrite(command, env).trim();
      const resolved = rewritten.length > 0 && rewritten !== command ? rewritten : command;
      if (resolved !== command) rewrites += 1;
      rememberResult(command, fingerprint, resolved);
      return resolved;
    } catch (error) {
      if (isMissingBinaryError(error)) {
        disabledFingerprints.add(fingerprint);
        if (env === undefined) noneDisabled = true;
        disabled = true;
        noteBypass("missing-binary");
        rememberResult(command, fingerprint, command);
        return command;
      }

      if (isExpectedNoRewriteError(error)) {
        rememberResult(command, fingerprint, command);
      }

      return command;
    }
  };
}

export function createRtkSpawnHook(options: {
  pathPrefix: string | null;
  rewriteCommand: (command: string, env?: RewriteEnv) => string;
}): (context: RtkSpawnContext) => RtkSpawnContext {
  return (context: RtkSpawnContext): RtkSpawnContext => {
    const env = prependPathToEnv(context.env, options.pathPrefix) ?? context.env;
    const command = options.rewriteCommand(context.command, env);
    return { command, cwd: context.cwd, env };
  };
}
