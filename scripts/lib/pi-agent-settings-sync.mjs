#!/usr/bin/env node
import fs from "node:fs";
import { dirname } from "node:path";
import { backupFile, replaceFile, writeJsonAtomic } from "./surfaces.mjs";

const modelRouting = JSON.parse(fs.readFileSync(new URL("../../workflow/runtime/model-routing.json", import.meta.url), "utf8"));

const [localPath, trackedPath, dryRunRaw, timestamp, modeArg] = process.argv.slice(2);
const dryRun = dryRunRaw === "1";
const mode = modeArg ?? "deploy";
if (!localPath || !trackedPath || !["deploy", "check", "managed"].includes(mode)) {
  console.error("usage: pi-agent-settings-sync.mjs <local> <tracked> <dryRun> <timestamp> [deploy|check|managed]");
  process.exit(2);
}

const ADDITIVE_TOOL_TOKEN = /^\+[a-z0-9_-]+$/i;
const RETIRED_EXTENSIONS = new Set(["-builtin:mcp"]);

function fail(message) {
  console.error(`pi-agent-settings-sync: ${message}`);
  process.exit(1);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function readSettings(path, label, { allowMissing = false } = {}) {
  let raw;
  let fileMode;
  let fd;
  try {
    fd = fs.openSync(path, fs.constants.O_RDONLY | fs.constants.O_NONBLOCK);
    const stat = fs.fstatSync(fd);
    if (!stat.isFile()) {
      fs.closeSync(fd);
      fd = undefined;
      fail(`cannot read ${label} settings at ${path}: not a regular file`);
    }
    fileMode = stat.mode & 0o7777;
    raw = fs.readFileSync(fd, "utf8");
  } catch (error) {
    if (allowMissing && error.code === "ENOENT") return null;
    fail(`cannot read ${label} settings at ${path}: ${error.code ?? "invalid JSON"}`);
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
  }
  try {
    return { data: JSON.parse(raw), raw, mode: fileMode };
  } catch {
    fail(`cannot read ${label} settings at ${path}: invalid JSON`);
  }
}

function assertStringArray(value, label, { nonEmpty = false } = {}) {
  if (value === undefined) return;
  if (
    !Array.isArray(value) ||
    value.some((entry) => typeof entry !== "string" || (nonEmpty && entry.trim().length === 0))
  ) {
    fail(`${label} must be an array of ${nonEmpty ? "non-empty " : ""}strings`);
  }
}

function assertArray(value, label) {
  if (value !== undefined && !Array.isArray(value)) {
    fail(`${label} must be an array`);
  }
}

const trackedFile = readSettings(trackedPath, "tracked");
const trackedSettings = trackedFile.data;
if (!isPlainObject(trackedSettings)) {
  fail(`tracked settings at ${trackedPath} must be a JSON object`);
}
assertArray(trackedSettings.packages, "tracked settings packages");
assertStringArray(trackedSettings.enabledModels, "tracked settings enabledModels", { nonEmpty: true });
assertStringArray(trackedSettings.skills, "tracked settings skills", { nonEmpty: true });
if (trackedSettings.defaultTools !== undefined) {
  if (
    !Array.isArray(trackedSettings.defaultTools) ||
    trackedSettings.defaultTools.some((entry) => typeof entry !== "string" || !ADDITIVE_TOOL_TOKEN.test(entry))
  ) {
    fail("tracked settings defaultTools must be an array of +<tool> entries");
  }
}
assertStringArray(trackedSettings.extensions, "tracked settings extensions");

let localStat = null;
try {
  localStat = fs.lstatSync(localPath);
} catch (error) {
  if (error.code !== "ENOENT") {
    fail(`cannot read local settings at ${localPath}: ${error.code ?? "invalid JSON"}`);
  }
}

if (mode === "check") {
  if (localStat === null) {
    console.log(`DRIFT          Pi agent settings missing at ${localPath}; run scripts/deploy-agent-workflow --apply`);
    process.exit(1);
  }
  if (localStat.isSymbolicLink()) {
    console.log(`DRIFT          Pi agent settings at ${localPath} is a symlink; run scripts/deploy-agent-workflow --apply`);
    process.exit(1);
  }
  if (!localStat.isFile()) {
    fail(`cannot read local settings at ${localPath}: not a regular file`);
  }
}

let managedAction = null;
let localFile = null;
if (mode === "managed") {
  if (localStat === null) {
    managedAction = "bootstrap";
    localFile = {
      data: structuredClone(trackedSettings),
      raw: trackedFile.raw,
      mode: trackedFile.mode,
    };
  } else if (localStat.isSymbolicLink()) {
    localFile = readSettings(localPath, "local", { allowMissing: true });
    if (localFile === null) {
      managedAction = "bootstrap-dangling";
      localFile = {
        data: structuredClone(trackedSettings),
        raw: trackedFile.raw,
        mode: 0o600,
      };
    } else {
      managedAction = "migrate-symlink";
    }
  } else if (!localStat.isFile()) {
    fail(`cannot read local settings at ${localPath}: not a regular file`);
  }
}

const localSettings = (localFile ?? readSettings(localPath, "local")).data;
if (!isPlainObject(localSettings)) {
  fail(`local settings at ${localPath} must be a JSON object`);
}
assertArray(localSettings.packages, "local settings packages");
assertStringArray(localSettings.enabledModels, "local settings enabledModels", { nonEmpty: true });
assertStringArray(localSettings.skills, "local settings skills", { nonEmpty: true });
assertStringArray(localSettings.defaultTools, "local settings defaultTools", { nonEmpty: true });
assertStringArray(localSettings.extensions, "local settings extensions");

const legacySources = new Set([
  "npm:pi-interview",
  "npm:@tintinweb/pi-subagents",
  "npm:pi-hooks",
  "npm:glimpseui",
  "npm:@zenspc/pi-pstack",
  // etabli-only keeper list Pi never resolved; the catalog now owns it.
  "local:etabli-workflow",
]);

const retiredModels = new Set(modelRouting.retired_pi_models);

function sourceOf(entry) {
  if (typeof entry === "string") return entry;
  if (entry && typeof entry === "object" && typeof entry.source === "string")
    return entry.source;
  return null;
}

// A pinned source (`npm:name@1.2.3`, `git:host/repo@<ref>`) and its unpinned
// form are one package. Git sources reduce to host/path as Pi's
// getPackageIdentity does, so ssh, https and `.git` spellings match too.
function packageIdentity(source) {
  const npm = /^npm:((?:@[^/]+\/)?[^@]+)/.exec(source);
  if (npm) return `npm:${npm[1]}`;
  const url = source.replace(/^git:/, "");
  const [, host, path] =
    /^git@([^:]+):(.+)$/.exec(url) ??
    /^(?:https?|ssh|git):\/\/(?:[^@/]+@)?([^/]+)\/(.+)$/.exec(url) ??
    /^([^/.][^/]*\.[^/]+)\/(.+)$/.exec(url) ??
    [];
  if (!host) return source;
  return `git:${host}/${path.split("@")[0].replace(/\.git$/, "")}`;
}

// Retired in every version, pinned or not.
const retiredIdentities = new Set([
  "npm:@tintinweb/pi-tasks",
  "npm:pi-lens",
  "npm:pi-cursor-sdk",
  "npm:pi-autoresearch",
  "npm:@narumitw/pi-goal",
  "npm:pi-simplify",
  "npm:pi-subagents",
  "npm:pi-mcp-adapter",
  "git:github.com/badlogic/pi-skills",
]);

function isLegacySource(source) {
  return (
    legacySources.has(source) ||
    retiredIdentities.has(packageIdentity(source)) ||
    source.startsWith("npm:@tintinweb/pi-subagents@") ||
    source === "npm:@agwab/pi-workflow" ||
    source.startsWith("npm:@agwab/pi-workflow@")
  );
}

const changes = [];
const trackedPackages = Array.isArray(trackedSettings.packages)
  ? trackedSettings.packages
  : [];
let localPackages = Array.isArray(localSettings.packages)
  ? localSettings.packages
  : [];
let localModels = Array.isArray(localSettings.enabledModels)
  ? localSettings.enabledModels
  : [];

let removedMcpAdapter = false;
localPackages = localPackages.filter((entry) => {
  const source = sourceOf(entry);
  if (source && isLegacySource(source)) {
    if (packageIdentity(source) === "npm:pi-mcp-adapter") removedMcpAdapter = true;
    changes.push(`remove ${source}`);
    return false;
  }
  return true;
});

for (const trackedEntry of trackedPackages) {
  const source = sourceOf(trackedEntry);
  if (!source) continue;
  const identity = packageIdentity(source);
  const [localIndex, ...duplicates] = localPackages.flatMap((entry, index) =>
    packageIdentity(sourceOf(entry) ?? "") === identity ? [index] : [],
  );
  if (localIndex === undefined) {
    localPackages.push(trackedEntry);
    changes.push(`add ${source}`);
    continue;
  }
  if (
    JSON.stringify(localPackages[localIndex]) !== JSON.stringify(trackedEntry)
  ) {
    localPackages[localIndex] = trackedEntry;
    changes.push(`sync ${source}`);
  }
  if (duplicates.length > 0) {
    localPackages = localPackages.filter((_, index) => !duplicates.includes(index));
    changes.push(`remove duplicate ${identity}`);
  }
}

let extensionsChanged = false;
let nextExtensions = localSettings.extensions;
if (removedMcpAdapter && Array.isArray(localSettings.extensions)) {
  const removed = [];
  nextExtensions = localSettings.extensions.filter((entry) => {
    if (RETIRED_EXTENSIONS.has(entry)) {
      removed.push(entry);
      return false;
    }
    return true;
  });
  if (removed.length > 0) {
    extensionsChanged = true;
    for (const entry of new Set(removed)) {
      changes.push(`remove extension ${entry}`);
    }
  }
}

const trackedDefaultTools = trackedSettings.defaultTools ?? [];
let defaultToolsChanged = false;
let nextDefaultTools = localSettings.defaultTools;
if (trackedDefaultTools.length > 0 && (localSettings.defaultTools === undefined || localSettings.defaultTools.length > 0)) {
  nextDefaultTools = [...(localSettings.defaultTools ?? [])];
  for (const token of trackedDefaultTools) {
    const toolName = token.slice(1);
    if (
      nextDefaultTools.includes(token) ||
      nextDefaultTools.includes(toolName) ||
      nextDefaultTools.includes(`-${toolName}`)
    ) {
      continue;
    }
    nextDefaultTools.push(token);
    defaultToolsChanged = true;
    changes.push(`add defaultTool ${token}`);
  }
}

localModels = localModels.filter((model) => {
  if (!retiredModels.has(model)) return true;
  changes.push(`remove ${model}`);
  return false;
});
for (const model of trackedSettings.enabledModels ?? []) {
  if (localModels.includes(model)) continue;
  localModels.push(model);
  changes.push(`add ${model}`);
}
const localDefault = `${localSettings.defaultProvider}/${localSettings.defaultModel}`;
if (retiredModels.has(localDefault)) {
  localSettings.defaultProvider = trackedSettings.defaultProvider;
  localSettings.defaultModel = trackedSettings.defaultModel;
  changes.push(`reset retired default ${localDefault} to ${trackedSettings.defaultProvider}/${trackedSettings.defaultModel}`);
}

const { defaultProvider, defaultModel } = localSettings;
if (typeof defaultProvider === "string" && typeof defaultModel === "string" && defaultProvider && defaultModel) {
  const defaultId = `${defaultProvider}/${defaultModel}`;
  if (!localModels.includes(defaultId) && !retiredModels.has(defaultId)) {
    localModels.push(defaultId);
    changes.push(`keep ${defaultId}`);
  }
}

if (
  JSON.stringify(localSettings.skills ?? null) !==
  JSON.stringify(trackedSettings.skills ?? null)
) {
  changes.push("skills-key");
}

function applyChanges(target) {
  target.packages = localPackages;
  target.enabledModels = localModels;
  target.skills = trackedSettings.skills;
  if (extensionsChanged) {
    if (nextExtensions.length === 0) delete target.extensions;
    else target.extensions = nextExtensions;
  }
  if (defaultToolsChanged) {
    target.defaultTools = nextDefaultTools;
  }
}

if (managedAction) {
  if (dryRun) {
    console.log(
      managedAction === "bootstrap"
        ? "WOULD_COPY     Pi agent settings bootstrap"
        : "WOULD_MIGRATE  Pi agent settings symlink to local file",
    );
    if (changes.length > 0) {
      console.log(`WOULD_SYNC     Pi agent settings resources (${changes.join(", ")})`);
    }
    process.exit(0);
  }
  if (changes.length > 0) {
    applyChanges(localSettings);
  }
  if (managedAction === "bootstrap") {
    fs.mkdirSync(dirname(localPath), { recursive: true });
  }
  replaceFile(
    localPath,
    changes.length > 0 ? `${JSON.stringify(localSettings, null, 2)}\n` : localFile.raw,
    managedAction === "bootstrap" ? trackedFile.mode : 0o600,
  );
  if (managedAction === "bootstrap") {
    console.log("COPY           Pi agent settings bootstrap");
  } else if (managedAction === "bootstrap-dangling") {
    console.log("COPY           Pi agent settings bootstrap after dangling symlink");
  } else {
    console.log("MIGRATE        Pi agent settings symlink to local file");
  }
  if (changes.length > 0) {
    console.log(`SYNC           Pi agent settings resources (${changes.join(", ")})`);
  } else {
    console.log("OK             Pi agent settings resources");
  }
  process.exit(0);
}

if (changes.length === 0) {
  if (mode !== "check") {
    console.log("OK             Pi agent settings resources");
  }
  process.exit(0);
}

if (mode === "check") {
  console.log(
    `DRIFT          Pi agent settings differ from tracked settings (${changes.join(", ")}); run scripts/deploy-agent-workflow --apply`,
  );
  process.exit(1);
}

if (dryRun) {
  console.log(`WOULD_SYNC     Pi agent settings resources (${changes.join(", ")})`);
  process.exit(0);
}

const backup = backupFile(localPath, { stamp: timestamp });
applyChanges(localSettings);
writeJsonAtomic(localPath, localSettings);
console.log(`BACKUP         ${backup}`);
console.log(`SYNC           Pi agent settings resources (${changes.join(", ")})`);
