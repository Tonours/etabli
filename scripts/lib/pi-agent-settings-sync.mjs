#!/usr/bin/env node
import fs from "node:fs";

const [localPath, trackedPath, dryRunRaw, timestamp, mode] =
  process.argv.slice(2);
const dryRun = dryRunRaw === "1";
if (!localPath || !trackedPath || !["deploy", "install"].includes(mode)) {
  console.error(
    "usage: pi-agent-settings-sync.mjs <local> <tracked> <dryRun> <timestamp> <deploy|install>",
  );
  process.exit(2);
}

function readSettings(path, label) {
  try {
    return JSON.parse(fs.readFileSync(path, "utf8"));
  } catch (error) {
    console.error(
      `pi-agent-settings-sync: cannot read ${label} settings at ${path}: ${error.message}`,
    );
    process.exit(1);
  }
}

const localSettings = readSettings(localPath, "local");
const trackedSettings = readSettings(trackedPath, "tracked");

const legacySources = new Set([
  "npm:pi-interview",
  "npm:@tintinweb/pi-subagents",
  "npm:@tintinweb/pi-tasks",
  "npm:pi-hooks",
  "npm:glimpseui",
]);

const deployLegacyModels = new Set(["openai-codex/gpt-5.6"]);
const installLegacyModels = new Set([
  "openai-codex/gpt-5.6",
  "opencode-go/kimi-k2.6",
  "kimi-coding/kimi-for-coding",
  "kimi-coding/kimi-for-coding-highspeed",
  "github-copilot/claude-opus-4.7",
  "opencode-go/minimax-m2.7",
  "opencode-go/qwen3.6-plus",
]);
const legacyModels =
  mode === "deploy"
    ? { has: (model) => deployLegacyModels.has(model) }
    : {
        has: (model) =>
          installLegacyModels.has(model) ||
          (typeof model === "string" && model.startsWith("local-mlx/")),
      };

function sourceOf(entry) {
  if (typeof entry === "string") return entry;
  if (entry && typeof entry === "object" && typeof entry.source === "string")
    return entry.source;
  return null;
}

function isLegacySource(source) {
  return (
    legacySources.has(source) ||
    source.startsWith("npm:@tintinweb/pi-subagents@") ||
    (source.startsWith("npm:@tintinweb/pi-tasks@") &&
      source !== "npm:@tintinweb/pi-tasks@0.7.1") ||
    source === "npm:@agwab/pi-workflow" ||
    source.startsWith("npm:@agwab/pi-workflow@")
  );
}

function backupPath(path) {
  let candidate = `${path}.bak.${timestamp}`;
  let index = 1;
  while (fs.existsSync(candidate)) {
    candidate = `${path}.bak.${timestamp}.${index}`;
    index += 1;
  }
  return candidate;
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

localPackages = localPackages.filter((entry) => {
  const source = sourceOf(entry);
  if (source && isLegacySource(source)) {
    changes.push(`remove ${source}`);
    return false;
  }
  return true;
});

for (const trackedEntry of trackedPackages) {
  const source = sourceOf(trackedEntry);
  if (!source) continue;
  const localIndex = localPackages.findIndex(
    (entry) => sourceOf(entry) === source,
  );
  if (localIndex === -1) {
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
}

localModels = localModels.filter((model) => {
  if (!legacyModels.has(model)) return true;
  changes.push(`remove ${model}`);
  return false;
});
for (const model of trackedSettings.enabledModels ?? []) {
  if (localModels.includes(model)) continue;
  localModels.push(model);
  changes.push(`add ${model}`);
}
if (mode === "install") {
  const provider = localSettings.defaultProvider;
  const modelId = localSettings.defaultModel;
  if (
    typeof provider === "string" &&
    typeof modelId === "string" &&
    provider &&
    modelId
  ) {
    const defaultId = `${provider}/${modelId}`;
    if (!localModels.includes(defaultId) && !legacyModels.has(defaultId)) {
      localModels.push(defaultId);
      changes.push(`keep ${defaultId}`);
    }
  }
}

if (
  JSON.stringify(localSettings.skills ?? null) !==
  JSON.stringify(trackedSettings.skills ?? null)
) {
  changes.push("skills-key");
}

if (changes.length === 0) {
  if (mode === "deploy")
    console.log("OK             Pi agent settings resources");
  process.exit(0);
}

if (dryRun) {
  if (mode === "deploy") {
    console.log(
      `WOULD_SYNC     Pi agent settings resources (${changes.join(", ")})`,
    );
  }
  process.exit(0);
}

const backup = backupPath(localPath);
fs.copyFileSync(localPath, backup);
localSettings.packages = localPackages;
localSettings.enabledModels = localModels;
localSettings.skills = trackedSettings.skills;
fs.writeFileSync(localPath, `${JSON.stringify(localSettings, null, 2)}\n`);
if (mode === "deploy") {
  console.log(`BACKUP         ${backup}`);
  console.log(
    `SYNC           Pi agent settings resources (${changes.join(", ")})`,
  );
}
