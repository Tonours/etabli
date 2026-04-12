/// <reference path="./node-runtime.d.ts" />
import { readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

export const FALLBACK_MODEL = "openai-codex/gpt-5.4";
export type RtkMode = "always" | "off";
export type RtkConfig = {
  enabled: boolean;
  mode: RtkMode;
  timeoutMs: number;
  maxCacheEntries: number;
  maxCommandLength: number;
  dangerousCommandBypass: boolean;
};

type AgentSettings = {
  defaultProvider?: unknown;
  defaultModel?: unknown;
  rtk?: unknown;
};

type FileCacheEntry<T> = {
  mtimeMs: number;
  size: number;
  value: T;
};

const agentSettingsCache = new Map<string, FileCacheEntry<AgentSettings>>();

export const DEFAULT_RTK_CONFIG: RtkConfig = {
  enabled: true,
  mode: "always",
  timeoutMs: 2500,
  maxCacheEntries: 256,
  maxCommandLength: 4000,
  dangerousCommandBypass: true,
};

export function getAgentDir(): string {
  return process.env.PI_CODING_AGENT_DIR?.trim() || join(homedir(), ".pi", "agent");
}

export function getAgentSettingsPath(): string {
  return join(getAgentDir(), "settings.json");
}

function readAgentSettings(settingsPath: string): AgentSettings | undefined {
  try {
    const stats = statSync(settingsPath);
    const cached = agentSettingsCache.get(settingsPath);
    if (cached && cached.mtimeMs === stats.mtimeMs && cached.size === stats.size) {
      return cached.value;
    }

    const value = JSON.parse(readFileSync(settingsPath, "utf-8")) as AgentSettings;
    agentSettingsCache.set(settingsPath, { mtimeMs: stats.mtimeMs, size: stats.size, value });
    return value;
  } catch {
    agentSettingsCache.delete(settingsPath);
    return undefined;
  }
}

function asPositiveInteger(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0 ? value : fallback;
}

function normalizeRtkMode(value: unknown): RtkMode {
  return value === "off" ? "off" : "always";
}

export function readDefaultModelSpec(settingsPath: string, fallback = FALLBACK_MODEL): string {
  const raw = readAgentSettings(settingsPath);
  if (raw) {
    const provider = typeof raw.defaultProvider === "string" ? raw.defaultProvider.trim() : "";
    const model = typeof raw.defaultModel === "string" ? raw.defaultModel.trim() : "";
    if (provider && model) return `${provider}/${model}`;
  }
  return fallback;
}

export function readRtkConfig(settingsPath = getAgentSettingsPath()): RtkConfig {
  const settings = readAgentSettings(settingsPath);
  const raw = settings?.rtk;
  if (!raw || typeof raw !== "object" || raw === null) {
    return { ...DEFAULT_RTK_CONFIG };
  }

  const config = raw as Record<string, unknown>;
  return {
    enabled: typeof config.enabled === "boolean" ? config.enabled : DEFAULT_RTK_CONFIG.enabled,
    mode: normalizeRtkMode(config.mode),
    timeoutMs: asPositiveInteger(config.timeoutMs, DEFAULT_RTK_CONFIG.timeoutMs),
    maxCacheEntries: asPositiveInteger(config.maxCacheEntries, DEFAULT_RTK_CONFIG.maxCacheEntries),
    maxCommandLength: asPositiveInteger(config.maxCommandLength, DEFAULT_RTK_CONFIG.maxCommandLength),
    dangerousCommandBypass:
      typeof config.dangerousCommandBypass === "boolean"
        ? config.dangerousCommandBypass
        : DEFAULT_RTK_CONFIG.dangerousCommandBypass,
  };
}

export function resetRuntimeCaches(): void {
  agentSettingsCache.clear();
}
