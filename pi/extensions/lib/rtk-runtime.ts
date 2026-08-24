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

type PipelinePart = { raw: string; segment: string };

/**
 * Splits a command on single top-level `|` pipe separators. `||` (logical
 * or), `|&`, escaped or quoted pipes, and pipes inside subshells are not
 * split points. Returns null when no safe pipe split exists (no top-level
 * single pipe, unbalanced quotes/parens, or an empty segment) — callers
 * then keep the conservative pipeline bypass.
 */
function splitPipelineParts(command: string): PipelinePart[] | null {
  const parts: PipelinePart[] = [];
  let depth = 0;
  let quote: string | null = null;
  let start = 0;
  let pipes = 0;
  for (let i = 0; i < command.length; i += 1) {
    const ch = command[i];
    if (quote !== null) {
      if (ch === "\\" && quote !== "'") i += 1;
      else if (ch === quote) quote = null;
      continue;
    }
    if (ch === "'" || ch === '"' || ch === "`") {
      quote = ch;
      continue;
    }
    if (ch === "\\") {
      i += 1;
      continue;
    }
    if (ch === "(") depth += 1;
    else if (ch === ")") {
      depth -= 1;
      if (depth < 0) return null;
    } else if (ch === "|" && depth === 0) {
      const next = command[i + 1];
      if (next === "|" || next === "&") return null;
      const raw = command.slice(start, i);
      const segment = raw.trim();
      if (segment.length === 0) return null;
      parts.push({ raw, segment });
      pipes += 1;
      start = i + 1;
    }
  }
  if (quote !== null || depth !== 0 || pipes === 0) return null;
  const tail = command.slice(start);
  const tailSegment = tail.trim();
  if (tailSegment.length === 0) return null;
  parts.push({ raw: tail, segment: tailSegment });
  return parts;
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
    const existing = entries.get(command);
    if (existing !== undefined && existing.bypass !== null) return;
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
      if (entry !== undefined) bypassOnlyCount -= 1;
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

  // Two-tier pipeline handling. Piped commands (~30% of agent traffic) are
  // still bypassed whenever any segment fails the standard safety checks,
  // but (a) a pipeline whose segments all resolve from the value cache is
  // rebuilt from cache without invoking the rewrite runner, and (b) a
  // pipeline with at least one already-vetted (cached) segment — or one seen
  // before — may rewrite its uncached segments individually. Pipelines with
  // zero vetted segments on a first sighting are never split, so the runner
  // is only ever invoked on segments already trusted standalone.
  const rewritePipeline = (
    command: string,
    env: RewriteEnv,
    fingerprint: string,
    disabledNow: boolean,
    seenBefore: boolean,
  ): string | null => {
    const parts = splitPipelineParts(command);
    if (parts === null || parts.length < 2) return null;

    for (const { segment } of parts) {
      if (segment.includes("\n")) return null;
      if (segment.includes("|")) return null; // subshell pipelines stay opaque
      if (/(^|\s)<<-?\s*['"]?[A-Za-z0-9_]+['"]?/.test(segment)) return null;
      if (segment.length > maxCommandLength) return null;
      if (dangerousCommandBypass && isDangerousCommand(segment)) return null;
    }
    if (disabledNow) return null;

    const cachedValues: (string | undefined)[] = [];
    let cachedCount = 0;
    for (const { segment } of parts) {
      const segEntry = entries.get(segment);
      if (segEntry !== undefined && segEntry.bypass === null) {
        if (segEntry.fingerprint === fingerprint) {
          cachedValues.push(segEntry.value);
          cachedCount += 1;
          continue;
        }
        const extra = segEntry.extra !== null ? segEntry.extra.get(fingerprint) : undefined;
        if (extra !== undefined) {
          cachedValues.push(extra);
          cachedCount += 1;
          continue;
        }
      }
      cachedValues.push(undefined);
    }
    if (cachedCount < parts.length && !(seenBefore || cachedCount >= 1)) return null;

    const values: string[] = [];
    for (let i = 0; i < parts.length; i += 1) {
      const segment = parts[i].segment;
      const cached = cachedValues[i];
      if (cached !== undefined) {
        values.push(cached);
        continue;
      }
      cacheMisses += 1;
      let rewritten: string;
      try {
        rewritten = runRewrite(segment, env).trim();
      } catch (error) {
        if (isMissingBinaryError(error)) {
          disabledFingerprints.add(fingerprint);
          if (env === undefined) noneDisabled = true;
          disabled = true;
        }
        return null;
      }
      const resolvedSegment = rewritten.length > 0 && rewritten !== segment ? rewritten : segment;
      rememberResult(segment, fingerprint, resolvedSegment);
      values.push(resolvedSegment);
    }

    let rebuilt = "";
    let changed = false;
    for (let i = 0; i < parts.length; i += 1) {
      const { raw, segment } = parts[i];
      const value = values[i];
      if (value === segment) {
        rebuilt += raw;
      } else {
        const lead = raw.length - raw.trimStart().length;
        rebuilt += raw.slice(0, lead) + value + raw.slice(lead + segment.length);
        changed = true;
      }
      if (i < parts.length - 1) rebuilt += "|";
    }
    const resolved = changed ? rebuilt : command;
    if (resolved !== command) rewrites += 1;
    rememberResult(command, fingerprint, resolved);
    cacheHits += cachedCount;
    return resolved;
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
    const pipelineRetry = entry !== undefined && entry.bypass === "pipeline";
    if (entry !== undefined && entry.bypass !== null && !pipelineRetry) {
      noteBypass(entry.bypass);
      return command;
    }
    if (entry === undefined || pipelineRetry) {
      const bypassReason = entry === undefined
        ? findBypassReason(command, enabled, mode, maxCommandLength, dangerousCommandBypass)
        : "pipeline";
      if (bypassReason !== null) {
        if (bypassReason === "pipeline") {
          const resolved = rewritePipeline(command, env, fingerprint, disabledNow, pipelineRetry);
          if (resolved !== null) return resolved;
        }
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
