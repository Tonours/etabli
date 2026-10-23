import { readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

export type RtkMode = "always" | "off";
export type RtkConfig = {
  enabled: boolean;
  mode: RtkMode;
  timeoutMs: number;
  maxCacheEntries: number;
  maxCommandLength: number;
};

export const DEFAULT_RTK_CONFIG: RtkConfig = {
  enabled: true,
  mode: "always",
  timeoutMs: 2500,
  maxCacheEntries: 256,
  maxCommandLength: 4000,
};

export function getAgentSettingsPath(): string {
  const agentDir = process.env.PI_CODING_AGENT_DIR?.trim() || join(homedir(), ".pi", "agent");
  return join(agentDir, "settings.json");
}

function asPositiveInteger(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0
    ? value
    : fallback;
}

function deriveRtkConfig(raw: unknown): RtkConfig {
  if (!raw || typeof raw !== "object") return { ...DEFAULT_RTK_CONFIG };
  const config = raw as Record<string, unknown>;
  return {
    enabled: typeof config.enabled === "boolean" ? config.enabled : DEFAULT_RTK_CONFIG.enabled,
    mode: config.mode === "off" ? "off" : "always",
    timeoutMs: asPositiveInteger(config.timeoutMs, DEFAULT_RTK_CONFIG.timeoutMs),
    maxCacheEntries: asPositiveInteger(config.maxCacheEntries, DEFAULT_RTK_CONFIG.maxCacheEntries),
    maxCommandLength: asPositiveInteger(config.maxCommandLength, DEFAULT_RTK_CONFIG.maxCommandLength),
  };
}

export function readRtkConfig(settingsPath = getAgentSettingsPath()): RtkConfig {
  try {
    const settings = JSON.parse(readFileSync(settingsPath, "utf-8")) as { rtk?: unknown } | null;
    return deriveRtkConfig(settings?.rtk);
  } catch {
    return { ...DEFAULT_RTK_CONFIG };
  }
}
