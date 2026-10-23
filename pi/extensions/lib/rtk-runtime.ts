import { delimiter } from "node:path";
import { hash as cryptoHash } from "node:crypto";
import type { RtkConfig } from "./pi-runtime.ts";
import { rtkDataFlowReason } from "../../../workflow/runtime/rtk-data-flow.mjs";

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
  signal?: unknown;
};

type ManagedRtkConfig = Pick<RtkConfig, "enabled" | "mode" | "maxCacheEntries" | "maxCommandLength">;

const HEREDOC = /(^|\s)<<-?\s*['"]?[A-Za-z0-9_]+['"]?/;

function isRtkUnavailableError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const { code, signal } = error as RewriteError;
  return code === "ENOENT" || code === "ETIMEDOUT" || typeof signal === "string";
}

export function readRtkRewrite(run: () => string): string {
  try {
    return run();
  } catch (error) {
    const stdout = typeof error === "object" && error !== null ? (error as { stdout?: unknown }).stdout : undefined;
    if ((error as RewriteError).status === 3 && typeof stdout === "string" && stdout.trim() !== "") return stdout;
    throw error;
  }
}

function isExpectedNoRewriteError(error: unknown): boolean {
  return typeof error === "object" && error !== null && (error as RewriteError).status === 1;
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

function findBypassReason(
  command: string,
  enabled: boolean,
  mode: string,
  maxCommandLength: number,
): string | null {
  const trimmed = command.trim();
  if (!enabled || mode === "off") return "disabled";
  if (trimmed.includes("\n")) return "multiline";
  if (HEREDOC.test(trimmed)) return "heredoc";
  if (trimmed.length > maxCommandLength) return "command-too-long";
  const dataFlow = rtkDataFlowReason(command);
  if (dataFlow !== null) return `data-flow-${dataFlow}`;
  if (trimmed.includes("|")) return "pipeline";
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

export function createRtkCommandRewriter(
  runRewrite: RewriteRunner,
  config: ManagedRtkConfig,
): (command: string, env?: RewriteEnv) => string {
  const { enabled, mode, maxCacheEntries, maxCommandLength } = config;
  const cache = new Map<string, string | null>();
  const disabledFingerprints = new Set<string>();

  const remember = (key: string, value: string | null): void => {
    cache.delete(key);
    cache.set(key, value);
    while (cache.size > maxCacheEntries) cache.delete(cache.keys().next().value as string);
  };

  const bypassPipeline = (command: string, key: string): string => {
    remember(key, null);
    return command;
  };

  const rewritePipeline = (command: string, env: RewriteEnv, fingerprint: string, key: string): string => {
    const seenBefore = cache.has(key);
    const parts = splitPipelineParts(command);
    if (parts === null || parts.length < 2) return bypassPipeline(command, key);
    for (const { segment } of parts) {
      if (segment.includes("\n") || segment.includes("|") || HEREDOC.test(segment) || segment.length > maxCommandLength) {
        return bypassPipeline(command, key);
      }
    }
    const cachedValues = parts.map(({ segment }) => cache.get(`${fingerprint}\0${segment}`) ?? undefined);
    if (!seenBefore && cachedValues.every((value) => value === undefined)) return bypassPipeline(command, key);

    let rebuilt = "";
    for (let i = 0; i < parts.length; i += 1) {
      const { raw, segment } = parts[i];
      let value = cachedValues[i];
      if (value === undefined) {
        try {
          const rewritten = runRewrite(segment, env).trim();
          value = rewritten.length > 0 ? rewritten : segment;
        } catch (error) {
          if (isRtkUnavailableError(error)) disabledFingerprints.add(fingerprint);
          return bypassPipeline(command, key);
        }
        remember(`${fingerprint}\0${segment}`, value);
      }
      const lead = raw.length - raw.trimStart().length;
      rebuilt += value === segment ? raw : raw.slice(0, lead) + value + raw.slice(lead + segment.length);
      if (i < parts.length - 1) rebuilt += "|";
    }
    remember(key, rebuilt);
    return rebuilt;
  };

  return (command: string, env?: RewriteEnv): string => {
    if (command.trim().length === 0) return command;
    const fingerprint = envFingerprint(env);
    if (disabledFingerprints.has(fingerprint)) return command;
    const key = `${fingerprint}\0${command}`;
    const cached = cache.get(key);
    if (cached != null) return cached;

    const bypassReason = findBypassReason(command, enabled, mode, maxCommandLength);
    if (bypassReason === "pipeline") return rewritePipeline(command, env, fingerprint, key);
    if (bypassReason !== null) return command;

    try {
      const rewritten = runRewrite(command, env).trim();
      const resolved = rewritten.length > 0 ? rewritten : command;
      remember(key, resolved);
      return resolved;
    } catch (error) {
      if (isRtkUnavailableError(error)) disabledFingerprints.add(fingerprint);
      else if (isExpectedNoRewriteError(error)) remember(key, command);
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
