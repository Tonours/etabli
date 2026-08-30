#!/usr/bin/env node
import fs from "node:fs";

const [localPath, trackedPath, dryRunRaw, timestamp, mode] =
  process.argv.slice(2);
const dryRun = dryRunRaw === "1";
if (!localPath || !trackedPath || !["deploy", "install"].includes(mode)) {
  console.error(
    "usage: claude-settings-sync.mjs <local> <tracked> <dryRun> <timestamp> <deploy|install>",
  );
  process.exit(2);
}

const STATES = new Set(["on", "name-only", "user-invocable-only", "off"]);

function fail(message) {
  console.error(`claude-settings-sync: ${message}`);
  process.exit(1);
}

function readJson(path, label) {
  try {
    return JSON.parse(fs.readFileSync(path, "utf8"));
  } catch (error) {
    fail(`cannot read ${label} at ${path}: ${error.message}`);
  }
}

const tracked = readJson(trackedPath, "tracked fragment");
const trackedKeys = Object.keys(tracked ?? {});
if (trackedKeys.length !== 1 || trackedKeys[0] !== "skillOverrides") {
  fail(`tracked fragment must contain exactly one skillOverrides key`);
}
const trackedMap = tracked.skillOverrides;
if (
  typeof trackedMap !== "object" ||
  trackedMap === null ||
  Array.isArray(trackedMap)
) {
  fail("skillOverrides must be an object");
}
for (const [name, state] of Object.entries(trackedMap)) {
  if (typeof state !== "string" || !STATES.has(state)) {
    fail(`skillOverrides[${name}] has invalid state ${JSON.stringify(state)}`);
  }
}

let localSettings;
let localMissing = false;
try {
  localSettings = JSON.parse(fs.readFileSync(localPath, "utf8"));
} catch (error) {
  if (error.code === "ENOENT") {
    localMissing = true;
    localSettings = {};
  } else {
    fail(`cannot read local settings at ${localPath}: ${error.message}`);
  }
}
if (
  localSettings === null ||
  typeof localSettings !== "object" ||
  Array.isArray(localSettings)
) {
  fail(
    `local settings at ${localPath} is not a JSON object; refusing to merge`,
  );
}

const unchanged =
  !localMissing &&
  JSON.stringify(localSettings.skillOverrides ?? null) ===
    JSON.stringify(trackedMap);

if (unchanged) {
  if (mode === "deploy") {
    console.log("OK             Claude skill overrides");
  }
  process.exit(0);
}

const keyCount = Object.keys(trackedMap).length;
if (dryRun) {
  if (mode === "deploy") {
    console.log(
      `WOULD_SYNC     Claude skill overrides (${keyCount} keys${localMissing ? ", new file" : ""})`,
    );
  }
  process.exit(0);
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

let backup = null;
if (!localMissing) {
  backup = backupPath(localPath);
  fs.copyFileSync(localPath, backup);
}

if (!localMissing && mode === "deploy") {
  for (const [name, state] of Object.entries(trackedMap).sort(([a], [b]) =>
    a.localeCompare(b),
  )) {
    console.log(`MAP            ${name} -> ${state}`);
  }
}

localSettings.skillOverrides = trackedMap;
const tmpPath = `${localPath}.tmp.${timestamp}`;
fs.writeFileSync(tmpPath, `${JSON.stringify(localSettings, null, 2)}\n`);
if (!localMissing) {
  fs.chmodSync(tmpPath, fs.statSync(localPath).mode);
}
fs.renameSync(tmpPath, localPath);

if (mode === "deploy") {
  if (backup) console.log(`BACKUP         ${backup}`);
  console.log(`SYNC           Claude skill overrides (${keyCount} keys)`);
}
