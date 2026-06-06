import { delimiter } from "node:path";
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

const runtimeState: RtkRuntimeState = {
  cacheSize: 0,
  cacheHits: 0,
  cacheMisses: 0,
  rewrites: 0,
  bypasses: 0,
  disabled: false,
  lastBypassReason: null,
};

function isMissingBinaryError(error: unknown): boolean {
  return typeof error === "object" && error !== null && (error as RewriteError).code === "ENOENT";
}

function isExpectedNoRewriteError(error: unknown): boolean {
  return typeof error === "object" && error !== null && (error as RewriteError).status === 1;
}

function noteBypass(reason: string): void {
  runtimeState.bypasses += 1;
  runtimeState.lastBypassReason = reason;
}

function findBypassReason(command: string, config: ManagedRtkConfig): string | null {
  const trimmed = command.trim();
  if (trimmed.length === 0) return null;
  if (!config.enabled || config.mode === "off") return "disabled";
  if (trimmed.includes("\n")) return "multiline";
  if (/(^|\s)<<-?\s*['"]?[A-Za-z0-9_]+['"]?/.test(trimmed)) return "heredoc";
  if (trimmed.length > config.maxCommandLength) return "command-too-long";
  if (trimmed.includes("|")) return "pipeline";
  if (
    config.dangerousCommandBypass &&
    /(^|\s)(sudo\b|rm\s+-rf\b|dd\b|mkfs\b|fdisk\b|parted\b|diskutil\b|mount\b|umount\b|chmod\b|chown\b|chgrp\b|git\s+reset\s+--hard\b|git\s+clean\s+-fdx\b)/.test(trimmed)
  ) {
    return "dangerous-command";
  }
  return null;
}

function remember(cache: Map<string, string>, key: string, value: string, maxEntries: number): void {
  if (cache.has(key)) cache.delete(key);
  cache.set(key, value);

  while (cache.size > maxEntries) {
    const oldest = cache.keys().next().value;
    if (oldest === undefined) break;
    cache.delete(oldest);
  }

  runtimeState.cacheSize = cache.size;
}

function updateFingerprint(hash: bigint, text: string): bigint {
  let nextHash = hash;
  for (let index = 0; index < text.length; index += 1) {
    nextHash ^= BigInt(text.charCodeAt(index));
    nextHash = BigInt.asUintN(64, nextHash * 1099511628211n);
  }
  return nextHash;
}

function envFingerprint(env: RewriteEnv): string {
  if (!env) return "none";

  let hash = 14695981039346656037n;
  for (const key of Object.keys(env).sort()) {
    const value = env[key];
    hash = updateFingerprint(hash, `${key.length}:${key}`);
    hash = updateFingerprint(hash, value === undefined ? ":-1:" : `:${value.length}:${value}`);
  }

  return hash.toString(16).padStart(16, "0");
}

function cacheKeyFor(command: string, fingerprint: string): string {
  return `${command}\0env:${fingerprint}`;
}

export function prependPathToEnv(env: RewriteEnv, pathPrefix: string | null): RewriteEnv {
  if (!pathPrefix) return env;
  return {
    ...(env ?? {}),
    PATH: env?.PATH ? `${pathPrefix}${delimiter}${env.PATH}` : pathPrefix,
  };
}

export function getRtkRuntimeState(): RtkRuntimeState {
  return { ...runtimeState };
}

export function resetRtkRuntimeState(): void {
  runtimeState.cacheSize = 0;
  runtimeState.cacheHits = 0;
  runtimeState.cacheMisses = 0;
  runtimeState.rewrites = 0;
  runtimeState.bypasses = 0;
  runtimeState.disabled = false;
  runtimeState.lastBypassReason = null;
}

export function createRtkCommandRewriter(
  runRewrite: RewriteRunner,
  config: ManagedRtkConfig,
): (command: string, env?: RewriteEnv) => string {
  const cache = new Map<string, string>();
  const disabledFingerprints = new Set<string>();
  resetRtkRuntimeState();

  return (command: string, env?: RewriteEnv): string => {
    if (command.trim().length === 0) return command;

    const bypassReason = findBypassReason(command, config);
    if (bypassReason) {
      noteBypass(bypassReason);
      return command;
    }

    const fingerprint = envFingerprint(env);

    if (disabledFingerprints.has(fingerprint)) {
      noteBypass("missing-binary");
      return command;
    }

    const cacheKey = cacheKeyFor(command, fingerprint);
    const cached = cache.get(cacheKey);
    if (cached) {
      runtimeState.cacheHits += 1;
      return cached;
    }

    runtimeState.cacheMisses += 1;

    try {
      const rewritten = runRewrite(command, env).trim();
      const resolved = rewritten.length > 0 && rewritten !== command ? rewritten : command;
      if (resolved !== command) runtimeState.rewrites += 1;
      remember(cache, cacheKey, resolved, config.maxCacheEntries);
      return resolved;
    } catch (error) {
      if (isMissingBinaryError(error)) {
        disabledFingerprints.add(fingerprint);
        runtimeState.disabled = true;
        noteBypass("missing-binary");
        remember(cache, cacheKey, command, config.maxCacheEntries);
        return command;
      }

      if (isExpectedNoRewriteError(error)) {
        remember(cache, cacheKey, command, config.maxCacheEntries);
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
