/// <reference path="./node-runtime.d.ts" />
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

export const FALLBACK_MODEL = "openai-codex/gpt-5.4";

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

type AgentSettings = {
  defaultProvider?: unknown;
  defaultModel?: unknown;
};

export function getAgentDir(): string {
  return process.env.PI_CODING_AGENT_DIR?.trim() || join(homedir(), ".pi", "agent");
}

export function getAgentSettingsPath(): string {
  return join(getAgentDir(), "settings.json");
}

export function findPackageFile(packageName: string, relativePath: string): string | undefined {
  const candidates = [join(homedir(), ".pi", "npm", "node_modules", packageName, relativePath)];

  try {
    const globalRoot = execFileSync("npm", ["root", "-g"], {
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (globalRoot) {
      candidates.push(join(globalRoot, packageName, relativePath));
    }
  } catch {
    // ignore
  }

  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  return undefined;
}

export function readDefaultModelSpec(settingsPath: string, fallback = FALLBACK_MODEL): string {
  try {
    const raw = JSON.parse(readFileSync(settingsPath, "utf-8")) as AgentSettings;
    const provider = typeof raw.defaultProvider === "string" ? raw.defaultProvider.trim() : "";
    const model = typeof raw.defaultModel === "string" ? raw.defaultModel.trim() : "";
    if (provider && model) return `${provider}/${model}`;
  } catch {
    // ignore
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
  currentModel?: string;
  settingsPath?: string;
  fallback?: string;
}): string {
  return (
    options.override ??
    options.currentModel ??
    readDefaultModelSpec(options.settingsPath ?? getAgentSettingsPath(), options.fallback ?? FALLBACK_MODEL)
  );
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
  const rtkPath = (() => {
    try {
      return execFileSync("bash", ["-lc", "command -v rtk"], {
        encoding: "utf-8",
        stdio: ["ignore", "pipe", "ignore"],
      }).trim();
    } catch {
      return "";
    }
  })();
  const rtkVersion = (() => {
    if (!rtkPath) return "missing";
    try {
      return execFileSync("rtk", ["--version"], {
        encoding: "utf-8",
        stdio: ["ignore", "pipe", "ignore"],
      }).trim();
    } catch {
      return "present, version unknown";
    }
  })();

  return [
    {
      label: "agent settings symlink",
      ok: safeRealpath(settingsPath) === safeRealpath(expectedSettings),
      detail: safeRealpath(settingsPath) ?? "missing",
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
