import fs, { type FSWatcher } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

export const UNKNOWN_MODEL_SPEC = "unknown";
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

type FileCacheEntry = {
  mtimeMs: number;
  size: number;
  validatedAt: number;
  /** Direct ref to the path's watch state: skips a second map lookup per hit. */
  watchState: WatchState | undefined;
  /** Memoized normalized config for this entry's settings.rtk (frozen). */
  rtkConfig?: RtkConfig;
  /** Rolling counter gating how often the freshness clock is consulted. */
  clockTick: number;
  value: AgentSettings;
};

type WatchState = {
  /** Active watcher; invalidates the cache entry on file change. */
  watcher: FSWatcher | null;
  /** True when watching is unavailable for this path: validate via stat instead. */
  statValidated: boolean;
};

const agentSettingsCache = new Map<string, FileCacheEntry>();
const fileWatchers = new Map<string, WatchState>();

// Single-slot memo of the most recently read entry: skips the map hash lookup
// on repeated reads of the same settings path.
let lastReadPath: string | undefined;
let lastReadEntry: FileCacheEntry | undefined;

/** Upper bound on concurrently held settings watchers (guards runaway growth). */
const MAX_FILE_WATCHERS = 16;
/**
 * Watcher-backed entries skip stat on every hit; a periodic stat revalidation
 * bounds staleness if change events are delayed or unavailable.
 */
const STAT_RECHECK_INTERVAL_MS = 1000;
/** The wall-clock check itself costs ~40ns, so run it every Nth read only. */
const CLOCK_CHECK_MASK = 15;

export const DEFAULT_RTK_CONFIG: RtkConfig = {
  enabled: true,
  mode: "always",
  timeoutMs: 2500,
  maxCacheEntries: 256,
  maxCommandLength: 4000,
  dangerousCommandBypass: true,
};

export function getAgentDir(): string {
  return (
    process.env.PI_CODING_AGENT_DIR?.trim() || join(homedir(), ".pi", "agent")
  );
}

export function getAgentSettingsPath(): string {
  return join(getAgentDir(), "settings.json");
}

function invalidateSettings(settingsPath: string): void {
  agentSettingsCache.delete(settingsPath);
  if (lastReadPath === settingsPath) {
    lastReadPath = undefined;
    lastReadEntry = undefined;
  }
}

function releaseWatcher(settingsPath: string, state: WatchState): void {
  if (state.watcher) {
    try {
      state.watcher.close();
    } catch {
      // watcher already closed
    }
    // Mutate in place so cache entries holding this ref fall back to stat.
    state.watcher = null;
  }
  fileWatchers.delete(settingsPath);
}

/**
 * Establish a change watcher for the settings path so cache hits need no stat.
 * On any failure the path permanently falls back to stat-based validation.
 */
function ensureWatched(settingsPath: string): void {
  const existing = fileWatchers.get(settingsPath);
  if (existing && (existing.watcher || !existing.statValidated)) return;
  if (existing) releaseWatcher(settingsPath, existing);

  try {
    const watcher = fs.watch(settingsPath, { persistent: false }, () => {
      invalidateSettings(settingsPath);
    });
    watcher.on("error", () => {
      const state = fileWatchers.get(settingsPath);
      if (state) releaseWatcher(settingsPath, state);
      invalidateSettings(settingsPath);
    });
    // Belt and braces alongside persistent:false: never keep the event loop alive.
    watcher.unref?.();

    // Evict the oldest watcher if we somehow accumulate many distinct paths.
    while (fileWatchers.size >= MAX_FILE_WATCHERS) {
      const oldestPath = fileWatchers.keys().next().value;
      if (oldestPath === undefined) break;
      const oldest = fileWatchers.get(oldestPath);
      if (oldest) releaseWatcher(oldestPath, oldest);
    }
    fileWatchers.set(settingsPath, { watcher, statValidated: false });
  } catch {
    // Watching unavailable (missing file, permissions, platform): stat per read.
    fileWatchers.set(settingsPath, { watcher: null, statValidated: true });
  }
}

function isEntryFresh(settingsPath: string, entry: FileCacheEntry): boolean {
  const state = entry.watchState;
  if (state?.watcher) {
    entry.clockTick = (entry.clockTick + 1) & CLOCK_CHECK_MASK;
    if (
      entry.clockTick !== 0 ||
      Date.now() - entry.validatedAt < STAT_RECHECK_INTERVAL_MS
    ) {
      // Watch-based invalidation: cache hit without a stat syscall.
      return true;
    }
  }
  try {
    const stats = fs.statSync(settingsPath);
    if (entry.mtimeMs === stats.mtimeMs && entry.size === stats.size) {
      entry.validatedAt = Date.now();
      return true;
    }
    return false;
  } catch {
    return false;
  }
}

function peekSettingsEntry(settingsPath: string): FileCacheEntry | undefined {
  const entry =
    lastReadEntry !== undefined && lastReadPath === settingsPath
      ? lastReadEntry
      : agentSettingsCache.get(settingsPath);
  if (entry === undefined || !isEntryFresh(settingsPath, entry)) {
    return undefined;
  }
  if (entry !== lastReadEntry) {
    lastReadPath = settingsPath;
    lastReadEntry = entry;
  }
  return entry;
}

function loadSettingsEntry(settingsPath: string): FileCacheEntry | undefined {
  try {
    const stats = fs.statSync(settingsPath);
    const value = JSON.parse(
      fs.readFileSync(settingsPath, "utf-8"),
    ) as AgentSettings;
    const entry: FileCacheEntry = {
      mtimeMs: stats.mtimeMs,
      size: stats.size,
      validatedAt: Date.now(),
      clockTick: 0,
      watchState: fileWatchers.get(settingsPath),
      value,
    };
    agentSettingsCache.set(settingsPath, entry);
    ensureWatched(settingsPath);
    // Point the fresh entry at the (possibly newly created) watch state.
    const watchState = fileWatchers.get(settingsPath);
    if (watchState !== entry.watchState) entry.watchState = watchState;
    lastReadPath = settingsPath;
    lastReadEntry = entry;
    return entry;
  } catch {
    invalidateSettings(settingsPath);
    return undefined;
  }
}

function readAgentSettings(settingsPath: string): AgentSettings | undefined {
  const entry =
    peekSettingsEntry(settingsPath) ?? loadSettingsEntry(settingsPath);
  return entry?.value;
}

function asPositiveInteger(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0
    ? value
    : fallback;
}

function normalizeRtkMode(value: unknown): RtkMode {
  return value === "off" ? "off" : "always";
}

export function readDefaultModelSpec(
  settingsPath: string,
  fallback = UNKNOWN_MODEL_SPEC,
): string {
  const raw = readAgentSettings(settingsPath);
  if (raw) {
    const provider =
      typeof raw.defaultProvider === "string" ? raw.defaultProvider.trim() : "";
    const model =
      typeof raw.defaultModel === "string" ? raw.defaultModel.trim() : "";
    if (provider && model) return `${provider}/${model}`;
  }
  return fallback;
}

function deriveRtkConfig(raw: unknown): RtkConfig {
  if (!raw || typeof raw !== "object" || raw === null) {
    return { ...DEFAULT_RTK_CONFIG };
  }

  const config = raw as Record<string, unknown>;
  return Object.freeze({
    enabled:
      typeof config.enabled === "boolean"
        ? config.enabled
        : DEFAULT_RTK_CONFIG.enabled,
    mode: normalizeRtkMode(config.mode),
    timeoutMs: asPositiveInteger(
      config.timeoutMs,
      DEFAULT_RTK_CONFIG.timeoutMs,
    ),
    maxCacheEntries: asPositiveInteger(
      config.maxCacheEntries,
      DEFAULT_RTK_CONFIG.maxCacheEntries,
    ),
    maxCommandLength: asPositiveInteger(
      config.maxCommandLength,
      DEFAULT_RTK_CONFIG.maxCommandLength,
    ),
    dangerousCommandBypass:
      typeof config.dangerousCommandBypass === "boolean"
        ? config.dangerousCommandBypass
        : DEFAULT_RTK_CONFIG.dangerousCommandBypass,
  });
}

export function readRtkConfig(
  settingsPath = getAgentSettingsPath(),
): RtkConfig {
  const entry =
    peekSettingsEntry(settingsPath) ?? loadSettingsEntry(settingsPath);
  if (entry) {
    // Memoized on the entry: dropped automatically when the entry invalidates.
    return (
      entry.rtkConfig ?? (entry.rtkConfig = deriveRtkConfig(entry.value?.rtk))
    );
  }
  return { ...DEFAULT_RTK_CONFIG };
}
