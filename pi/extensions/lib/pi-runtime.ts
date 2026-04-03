/// <reference path="./node-runtime.d.ts" />
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

export const FALLBACK_MODEL = "openai-codex/gpt-5.4";
export const FALLBACK_THINKING = "off";

export const SAFE_SUBAGENT_EXTENSION_FILES = [
  "damage-control.ts",
  "filter-output.ts",
  "rtk.ts",
  "block-google-providers.ts",
] as const;

export type PackageFileResolver = (packageName: string, relativePath: string) => string | undefined;

export type SetupCheck = {
  label: string;
  ok: boolean;
  detail: string;
};

export type SubagentRole = "scout" | "worker" | "reviewer";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh";

type SubagentRoleSettings = {
  model?: unknown;
  thinking?: unknown;
};

type AgentSettings = {
  defaultProvider?: unknown;
  defaultModel?: unknown;
  subagents?: unknown;
};

type ParsedSubagentRoleSettings = {
  model?: string;
  thinking?: ThinkingLevel;
};

type FileCacheEntry<T> = {
  mtimeMs: number;
  size: number;
  value: T;
};

type RtkVersionCacheEntry = {
  path: string;
  value: string;
};

const agentSettingsCache = new Map<string, FileCacheEntry<AgentSettings>>();
const packageFileCache = new Map<string, string>();
let npmGlobalRootCache: string | undefined;
let rtkCommandCache: string | undefined;
let rtkVersionCache: RtkVersionCacheEntry | undefined;

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

function getGlobalNpmRoot(): string | undefined {
  if (npmGlobalRootCache) return npmGlobalRootCache;

  try {
    const root = execFileSync("npm", ["root", "-g"], {
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (root) npmGlobalRootCache = root;
  } catch {
    return undefined;
  }

  return npmGlobalRootCache;
}

function normalizeThinkingLevel(value: unknown): ThinkingLevel | undefined {
  if (
    value !== "off" &&
    value !== "minimal" &&
    value !== "low" &&
    value !== "medium" &&
    value !== "high" &&
    value !== "xhigh"
  ) {
    return undefined;
  }
  return value;
}

function readSubagentRoleSettings(settingsPath: string, role: SubagentRole | undefined): ParsedSubagentRoleSettings {
  if (!role) return {};

  const settings = readAgentSettings(settingsPath);
  if (!settings || typeof settings.subagents !== "object" || settings.subagents === null) {
    return {};
  }

  const roleSettings = (settings.subagents as Record<string, SubagentRoleSettings>)[role];
  if (!roleSettings || typeof roleSettings !== "object") {
    return {};
  }

  const model = typeof roleSettings.model === "string" && roleSettings.model.trim().length > 0
    ? roleSettings.model.trim()
    : undefined;

  return {
    model,
    thinking: normalizeThinkingLevel(roleSettings.thinking),
  };
}

export function findPackageFile(packageName: string, relativePath: string): string | undefined {
  const cacheKey = `${packageName}:${relativePath}`;
  const cachedPath = packageFileCache.get(cacheKey);
  if (cachedPath && existsSync(cachedPath)) {
    return cachedPath;
  }
  packageFileCache.delete(cacheKey);

  const candidates = [join(homedir(), ".pi", "npm", "node_modules", packageName, relativePath)];
  const globalRoot = getGlobalNpmRoot();
  if (globalRoot) candidates.push(join(globalRoot, packageName, relativePath));

  for (const candidate of candidates) {
    if (existsSync(candidate)) {
      packageFileCache.set(cacheKey, candidate);
      return candidate;
    }
  }

  return undefined;
}

function getRtkPath(): string {
  if (rtkCommandCache && existsSync(rtkCommandCache)) {
    return rtkCommandCache;
  }

  rtkCommandCache = undefined;

  try {
    const path = execFileSync("bash", ["-lc", "command -v rtk"], {
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (path) {
      rtkCommandCache = path;
      return path;
    }
  } catch {
    return "";
  }

  return "";
}

function getRtkVersion(rtkPath: string): string {
  if (!rtkPath) return "missing";
  if (rtkVersionCache && rtkVersionCache.path === rtkPath) {
    return rtkVersionCache.value;
  }

  try {
    const value = execFileSync("rtk", ["--version"], {
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    rtkVersionCache = { path: rtkPath, value };
    return value;
  } catch {
    return "present, version unknown";
  }
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

export function getSafeSubagentExtensionPaths(extensionDir: string): string[] {
  return SAFE_SUBAGENT_EXTENSION_FILES.map((file) => join(extensionDir, file)).filter((path) => existsSync(path));
}

export function getWorkerPackageExtensionPaths(resolvePackageFile: PackageFileResolver): string[] {
  return [
    resolvePackageFile("mitsupi", "pi-extensions/todos.ts"),
    resolvePackageFile("pi-hooks", "lsp/lsp.ts"),
    resolvePackageFile("pi-hooks", "lsp/lsp-tool.ts"),
  ].filter((value): value is string => Boolean(value));
}

export function uniquePaths(paths: string[]): string[] {
  return [...new Set(paths)];
}

export function mergeSubagentExtensionPaths(rolePaths: string[], safePaths: string[]): string[] {
  return uniquePaths([...rolePaths, ...safePaths]);
}

export function resolveSubagentModel(options: {
  override?: string;
  role?: SubagentRole;
  currentModel?: string;
  settingsPath?: string;
  fallback?: string;
}): string {
  const settingsPath = options.settingsPath ?? getAgentSettingsPath();
  const roleSettings = readSubagentRoleSettings(settingsPath, options.role);

  return (
    options.override ??
    roleSettings.model ??
    options.currentModel ??
    readDefaultModelSpec(settingsPath, options.fallback ?? FALLBACK_MODEL)
  );
}

export function resolveSubagentThinking(options: {
  role?: SubagentRole;
  settingsPath?: string;
  fallback?: ThinkingLevel;
}): ThinkingLevel {
  const settingsPath = options.settingsPath ?? getAgentSettingsPath();
  const roleSettings = readSubagentRoleSettings(settingsPath, options.role);
  return roleSettings.thinking ?? (options.fallback ?? FALLBACK_THINKING);
}

export function formatSetupChecks(checks: SetupCheck[]): string {
  const lines = checks.map((check) => `${check.ok ? "PASS" : "FAIL"} ${check.label}: ${check.detail}`);
  const passCount = checks.filter((check) => check.ok).length;
  const header = `${passCount}/${checks.length} checks passed`;
  return [header, ...lines].join("\n");
}

export function getRepoRootFromExtensionDir(extensionDir: string): string {
  return resolve(extensionDir, "..");
}

export function safeRealpath(path: string): string | undefined {
  try {
    return realpathSync(path);
  } catch {
    return undefined;
  }
}

export function buildSetupChecks(options: {
  extensionDir: string;
  settingsPath?: string;
  packageResolver?: PackageFileResolver;
}): SetupCheck[] {
  const extensionDir = options.extensionDir;
  const repoRoot = getRepoRootFromExtensionDir(extensionDir);
  const settingsPath = options.settingsPath ?? getAgentSettingsPath();
  const packageResolver = options.packageResolver ?? findPackageFile;
  const expectedSettings = join(repoRoot, "agent", "settings.json");
  const expectedExtensions = extensionDir;
  const repoNodeModules = join(extensionDir, "node_modules");
  const expectedNodeModules = join(homedir(), ".pi", "npm", "node_modules");
  const workerPaths = getWorkerPackageExtensionPaths(packageResolver);
  const safePaths = getSafeSubagentExtensionPaths(extensionDir);
  const modelSpec = readDefaultModelSpec(settingsPath);
  const rtkPath = getRtkPath();
  const rtkVersion = getRtkVersion(rtkPath);

  const actualSettings = safeRealpath(settingsPath);
  const expectedSettingsReal = safeRealpath(expectedSettings);

  return [
    {
      label: "agent settings local file",
      ok: Boolean(actualSettings) && actualSettings !== expectedSettingsReal,
      detail: actualSettings
        ? actualSettings === expectedSettingsReal
          ? "repo-linked (model changes will dirty the repo)"
          : actualSettings
        : "missing",
    },
    {
      label: "agent extensions symlink",
      ok: safeRealpath(join(getAgentDir(), "extensions")) === safeRealpath(expectedExtensions),
      detail: safeRealpath(join(getAgentDir(), "extensions")) ?? "missing",
    },
    {
      label: "extensions node_modules link",
      ok: safeRealpath(repoNodeModules) === safeRealpath(expectedNodeModules),
      detail: safeRealpath(repoNodeModules) ?? "missing",
    },
    {
      label: "default model",
      ok: modelSpec.length > 0,
      detail: modelSpec,
    },
    {
      label: "rtk",
      ok: rtkPath.length > 0,
      detail: rtkPath ? `${rtkPath} (${rtkVersion})` : "missing",
    },
    {
      label: "subagent safe extensions",
      ok: safePaths.length === SAFE_SUBAGENT_EXTENSION_FILES.length,
      detail: `${safePaths.length}/${SAFE_SUBAGENT_EXTENSION_FILES.length} present`,
    },
    {
      label: "worker todo/lsp extensions",
      ok: workerPaths.length === 3,
      detail: `${workerPaths.length}/3 present`,
    },
  ];
}

export function getExtensionDirFromModule(moduleUrl: string): string {
  return dirname(fileURLToPath(moduleUrl));
}

export function resetRuntimeCaches(): void {
  agentSettingsCache.clear();
  packageFileCache.clear();
  npmGlobalRootCache = undefined;
  rtkCommandCache = undefined;
  rtkVersionCache = undefined;
}
