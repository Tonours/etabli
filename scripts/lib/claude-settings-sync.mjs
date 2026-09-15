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
const SCALAR_KEYS = new Set([
  "skipDangerousModePermissionPrompt",
  "skipAutoPermissionPrompt",
]);
const PERMISSION_KEYS = new Set(["defaultMode"]);
const ALLOWED_TOP_LEVEL = new Set([
  "skillOverrides",
  "permissions",
  ...SCALAR_KEYS,
]);

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
if (typeof tracked !== "object" || tracked === null || Array.isArray(tracked)) {
  fail("tracked fragment must be a JSON object");
}
const topKeys = Object.keys(tracked);
for (const key of topKeys) {
  if (!ALLOWED_TOP_LEVEL.has(key)) {
    fail(
      `tracked fragment key ${JSON.stringify(key)} is not allowed; permitted keys: ${[...ALLOWED_TOP_LEVEL].join(", ")}`,
    );
  }
}
if (!topKeys.includes("skillOverrides")) {
  fail(`tracked fragment must contain a skillOverrides key`);
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
if (tracked.permissions !== undefined) {
  if (
    typeof tracked.permissions !== "object" ||
    tracked.permissions === null ||
    Array.isArray(tracked.permissions)
  ) {
    fail("permissions must be an object");
  }
  for (const [name, value] of Object.entries(tracked.permissions)) {
    if (!PERMISSION_KEYS.has(name)) {
      fail(
        `permissions[${name}] is not allowed; permitted keys: ${[...PERMISSION_KEYS].join(", ")}`,
      );
    }
    if (typeof value !== "string" || value.length === 0) {
      fail(`permissions[${name}] must be a non-empty string`);
    }
  }
}
for (const key of SCALAR_KEYS) {
  if (tracked[key] !== undefined && typeof tracked[key] !== "boolean") {
    fail(`${key} must be a boolean`);
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

function trackedMatchesLocal() {
  if (
    JSON.stringify(localSettings.skillOverrides ?? null) !==
    JSON.stringify(trackedMap)
  ) {
    return false;
  }
  const livePermissions = localSettings.permissions ?? {};
  for (const [name, value] of Object.entries(tracked.permissions ?? {})) {
    if (livePermissions[name] !== value) return false;
  }
  for (const key of SCALAR_KEYS) {
    if (tracked[key] !== undefined && localSettings[key] !== tracked[key]) {
      return false;
    }
  }
  return true;
}

const unchanged = !localMissing && trackedMatchesLocal();

if (unchanged) {
  if (mode === "deploy") {
    console.log("OK             Claude tracked settings");
  }
  process.exit(0);
}

const keyCount = Object.keys(trackedMap).length;
const settingsKeyCount =
  Object.keys(tracked.permissions ?? {}).length +
  [...SCALAR_KEYS].filter((key) => tracked[key] !== undefined).length;
if (dryRun) {
  if (mode === "deploy") {
    console.log(
      `WOULD_SYNC     Claude tracked settings (${keyCount} skills, ${settingsKeyCount} settings keys${localMissing ? ", new file" : ""})`,
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
  for (const [name, value] of Object.entries(tracked.permissions ?? {}).sort(
    ([a], [b]) => a.localeCompare(b),
  )) {
    console.log(`SET            permissions.${name} -> ${value}`);
  }
  for (const key of [...SCALAR_KEYS].sort()) {
    if (tracked[key] !== undefined) {
      console.log(`SET            ${key} -> ${tracked[key]}`);
    }
  }
}

localSettings.skillOverrides = trackedMap;
if (tracked.permissions !== undefined) {
  localSettings.permissions = {
    ...(localSettings.permissions ?? {}),
    ...tracked.permissions,
  };
}
for (const key of SCALAR_KEYS) {
  if (tracked[key] !== undefined) {
    localSettings[key] = tracked[key];
  }
}
const tmpPath = `${localPath}.tmp.${timestamp}`;
fs.writeFileSync(tmpPath, `${JSON.stringify(localSettings, null, 2)}\n`);
if (!localMissing) {
  fs.chmodSync(tmpPath, fs.statSync(localPath).mode);
}
fs.renameSync(tmpPath, localPath);

if (mode === "deploy") {
  if (backup) console.log(`BACKUP         ${backup}`);
  console.log(
    `SYNC           Claude tracked settings (${keyCount} skills, ${settingsKeyCount} settings keys)`,
  );
}
