#!/usr/bin/env node
import fs from "node:fs";
import { backupFile, writeJsonAtomic } from "./surfaces.mjs";

const modelRouting = JSON.parse(fs.readFileSync(new URL("../../workflow/runtime/model-routing.json", import.meta.url), "utf8"));

const [localPath, trackedPath, dryRunRaw, timestamp] = process.argv.slice(2);
const dryRun = dryRunRaw === "1";
if (!localPath || !trackedPath) {
  console.error("usage: pi-agent-settings-sync.mjs <local> <tracked> <dryRun> <timestamp>");
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

function isLegacySource(source) {
  return (
    legacySources.has(source) ||
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

if (changes.length === 0) {
  console.log("OK             Pi agent settings resources");
  process.exit(0);
}

if (dryRun) {
  console.log(`WOULD_SYNC     Pi agent settings resources (${changes.join(", ")})`);
  process.exit(0);
}

const backup = backupFile(localPath, { stamp: timestamp });
localSettings.packages = localPackages;
localSettings.enabledModels = localModels;
localSettings.skills = trackedSettings.skills;
writeJsonAtomic(localPath, localSettings);
console.log(`BACKUP         ${backup}`);
console.log(`SYNC           Pi agent settings resources (${changes.join(", ")})`);
