#!/usr/bin/env node
import fs from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { backupFile, machineLocalNames, writeJsonAtomic } from "./surfaces.mjs";

const [localPath, trackedPath, dryRunRaw, timestamp, mode, homeDir] =
  process.argv.slice(2);
const dryRun = dryRunRaw === "1";
if (!localPath || !trackedPath || !["deploy", "install", "check"].includes(mode)) {
  console.error(
    "usage: claude-settings-sync.mjs <local> <tracked> <dryRun> <timestamp> <deploy|install|check> [home]",
  );
  process.exit(2);
}

const STATES = new Set(["on", "name-only", "user-invocable-only", "off"]);
const SCALAR_KEYS = new Set([
  "skipDangerousModePermissionPrompt",
  "skipAutoPermissionPrompt",
  "autoMemoryEnabled",
  "promptSuggestionEnabled",
  "awaySummaryEnabled",
]);
const PERMISSION_KEYS = new Set(["defaultMode"]);
const ATTRIBUTION_KEYS = new Set(["commit", "pr"]);
const ENV_KEYS = new Set([
  "CLAUDE_CODE_SUBAGENT_MODEL",
  "CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS",
]);
const NUMERIC_KEYS = new Map([
  ["autoCompactWindow", { min: 100000, max: undefined }],
  ["bashOutputMaxChars", { min: 4000, max: 128000 }],
  ["skillListingMaxDescChars", { min: 1, max: undefined }],
]);
const EFFORTS = new Set(["low", "medium", "high", "xhigh"]);
const MODEL_ID = /^claude-[a-z0-9-]+$/;
const ALLOWED_TOP_LEVEL = new Set([
  "skillOverrides",
  "permissions",
  "attribution",
  "env",
  "modelSettings",
  ...NUMERIC_KEYS.keys(),
  ...SCALAR_KEYS,
]);
const GATES = new Map([
  ["env.CLAUDE_CODE_SUBAGENT_MODEL", [2, 1, 251]],
  ["env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS", [2, 1, 299]],
  ["modelSettings", [2, 1, 251]],
  ["autoCompactWindow", [2, 1, 288]],
  ["bashOutputMaxChars", [2, 1, 261]],
]);

function fail(message) {
  console.error(`claude-settings-sync: ${message}`);
  process.exit(1);
}

function readJson(path, label) {
  try {
    return JSON.parse(fs.readFileSync(path, "utf8"));
  } catch (error) {
    fail(`cannot read ${label} at ${path}: ${error.code ?? "invalid JSON"}`);
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
if (tracked.attribution !== undefined) {
  if (
    typeof tracked.attribution !== "object" ||
    tracked.attribution === null ||
    Array.isArray(tracked.attribution)
  ) {
    fail("attribution must be an object");
  }
  for (const [name, value] of Object.entries(tracked.attribution)) {
    if (!ATTRIBUTION_KEYS.has(name)) {
      fail(
        `attribution[${name}] is not allowed; permitted keys: ${[...ATTRIBUTION_KEYS].join(", ")}`,
      );
    }
    if (typeof value !== "string") {
      fail(`attribution[${name}] must be a string`);
    }
  }
}
if (tracked.env !== undefined) {
  if (
    typeof tracked.env !== "object" ||
    tracked.env === null ||
    Array.isArray(tracked.env)
  ) {
    fail("env must be an object");
  }
  for (const [name, value] of Object.entries(tracked.env)) {
    if (!ENV_KEYS.has(name)) fail(`env[${name}] is not allowed`);
    if (typeof value !== "string" || value.length === 0) {
      fail(`env[${name}] must be a non-empty string`);
    }
    if (
      name === "CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS" &&
      (!/^[1-9]\d*$/.test(value) ||
        !Number.isSafeInteger(Number(value)) ||
        Number(value) < 100000)
    ) {
      fail(`env[${name}] must be a decimal string of at least 100000`);
    }
  }
}
for (const [key, { min, max }] of NUMERIC_KEYS) {
  const value = tracked[key];
  if (value === undefined) continue;
  if (
    !Number.isInteger(value) ||
    value < min ||
    (max !== undefined && value > max)
  ) {
    fail(
      `${key} must be an integer ${max === undefined ? `of at least ${min}` : `between ${min} and ${max}`}`,
    );
  }
}
if (tracked.modelSettings !== undefined) {
  if (
    typeof tracked.modelSettings !== "object" ||
    tracked.modelSettings === null ||
    Array.isArray(tracked.modelSettings)
  ) {
    fail("modelSettings must be an object");
  }
  for (const [id, entry] of Object.entries(tracked.modelSettings)) {
    if (!MODEL_ID.test(id)) fail(`modelSettings key ${JSON.stringify(id)} is not a model id`);
    if (typeof entry !== "object" || entry === null || Array.isArray(entry)) {
      fail(`modelSettings[${id}] must be an object`);
    }
    for (const field of Object.keys(entry)) {
      if (field !== "effortLevel") {
        fail(`modelSettings[${id}].${field} is not allowed; permitted fields: effortLevel`);
      }
    }
    if (!EFFORTS.has(entry.effortLevel)) {
      fail(`modelSettings[${id}].effortLevel must be one of ${[...EFFORTS].join(", ")}`);
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
    fail(`cannot read local settings at ${localPath}: ${error.code ?? "invalid JSON"}`);
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

if (
  localSettings.env !== undefined &&
  (typeof localSettings.env !== "object" ||
    localSettings.env === null ||
    Array.isArray(localSettings.env))
) {
  fail("local settings env must be an object; refusing to merge");
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

const gatedWanted = [
  ...Object.keys(tracked.env ?? {}).map((name) => `env.${name}`),
  ...(tracked.modelSettings !== undefined ? ["modelSettings"] : []),
  ...[...NUMERIC_KEYS.keys()].filter((key) => tracked[key] !== undefined && GATES.has(key)),
];
let probed = null;
if (gatedWanted.length > 0) {
  const version = spawnSync("claude", ["--version"], { encoding: "utf8", timeout: 5000, maxBuffer: 4096 });
  const match = /^(\d+)\.(\d+)\.(\d+)(?:\s|$)/.exec(version.stdout ?? "");
  if (!version.error && version.status === 0 && match) probed = match.slice(1).map(Number);
}
function gatedOut(label) {
  const gate = GATES.get(label);
  if (!gate) return false;
  const ok =
    probed !== null &&
    (probed[0] > gate[0] ||
      (probed[0] === gate[0] &&
        (probed[1] > gate[1] || (probed[1] === gate[1] && probed[2] >= gate[2]))));
  if (!ok) {
    console.error(
      `WARN           ${label} skipped: requires Claude Code >=${gate.join(".")} on PATH; install/upgrade it and rerun deploy`,
    );
  }
  return !ok;
}

let managedEnv = tracked.env;
if (managedEnv !== undefined) {
  managedEnv = Object.fromEntries(
    Object.entries(managedEnv).filter(([name]) => !gatedOut(`env.${name}`)),
  );
  if (Object.keys(managedEnv).length === 0) managedEnv = undefined;
}
let managedModelSettings = tracked.modelSettings;
if (managedModelSettings !== undefined && gatedOut("modelSettings")) {
  managedModelSettings = undefined;
}
if (managedModelSettings !== undefined && localSettings.modelSettings !== undefined) {
  if (!isPlainObject(localSettings.modelSettings)) {
    fail("local settings modelSettings must be an object; refusing to merge");
  }
  for (const id of Object.keys(managedModelSettings)) {
    const entry = localSettings.modelSettings[id];
    if (entry !== undefined && !isPlainObject(entry)) {
      fail(`local settings modelSettings[${id}] must be an object; refusing to merge`);
    }
  }
}
const managedNumerics = {};
for (const key of NUMERIC_KEYS.keys()) {
  if (tracked[key] !== undefined && !gatedOut(key)) managedNumerics[key] = tracked[key];
}

if (managedNumerics.autoCompactWindow !== undefined && isPlainObject(localSettings.modelSettings)) {
  for (const [id, entry] of Object.entries(localSettings.modelSettings)) {
    if (
      isPlainObject(entry) &&
      Object.hasOwn(entry, "autoCompactWindow") &&
      entry.autoCompactWindow !== managedNumerics.autoCompactWindow
    ) {
      console.error(
        `WARN           local modelSettings.${MODEL_ID.test(id) ? id : "<model>"}.autoCompactWindow overrides the tracked autoCompactWindow for that model`,
      );
    }
  }
}

const liveMap =
  localSettings.skillOverrides !== null &&
  typeof localSettings.skillOverrides === "object" &&
  !Array.isArray(localSettings.skillOverrides)
    ? localSettings.skillOverrides
    : {};
function surfaceSkillNames(skillsDir) {
  if (!fs.existsSync(skillsDir)) return null;
  const names = new Set();
  const addSkill = (dir) => {
    const skillFile = path.join(dir, "SKILL.md");
    if (!fs.existsSync(skillFile)) return false;
    names.add(path.basename(dir));
    const declared = fs
      .readFileSync(skillFile, "utf8")
      .match(/^---\n[\s\S]*?^name:\s*["']?([^"'\n]+?)["']?\s*$/m);
    if (declared) names.add(declared[1]);
    return true;
  };
  for (const entry of fs.readdirSync(skillsDir)) {
    const dir = path.join(skillsDir, entry);
    if (addSkill(dir) || !fs.statSync(dir, { throwIfNoEntry: false })?.isDirectory()) continue;
    for (const child of fs.readdirSync(dir)) addSkill(path.join(dir, child));
  }
  return names;
}

const surfaceNames = surfaceSkillNames(path.join(path.dirname(localPath), "skills"));
let machineLocalOn;
try {
  machineLocalOn = machineLocalNames(path.join(path.dirname(trackedPath), "machine-local-skills.json"), homeDir, "skills");
} catch (error) {
  fail(error.message);
}
const mergedMap = Object.fromEntries(
  [
    ...Object.entries(liveMap).filter(
      ([name, state]) =>
        !Object.hasOwn(trackedMap, name) &&
        STATES.has(state) &&
        (state !== "on" || machineLocalOn.has(name)) &&
        (surfaceNames === null || surfaceNames.has(name)),
    ),
    ...Object.entries(trackedMap),
  ].sort(([a], [b]) => a.localeCompare(b)),
);

function trackedMatchesLocal() {
  if (
    JSON.stringify(localSettings.skillOverrides ?? null) !==
    JSON.stringify(mergedMap)
  ) {
    return false;
  }
  const livePermissions = localSettings.permissions ?? {};
  for (const [name, value] of Object.entries(tracked.permissions ?? {})) {
    if (livePermissions[name] !== value) return false;
  }
  const liveAttribution = localSettings.attribution ?? {};
  for (const [name, value] of Object.entries(tracked.attribution ?? {})) {
    if (liveAttribution[name] !== value) return false;
  }
  for (const [name, value] of Object.entries(managedEnv ?? {})) {
    if (localSettings.env?.[name] !== value) return false;
  }
  for (const key of SCALAR_KEYS) {
    if (tracked[key] !== undefined && localSettings[key] !== tracked[key]) {
      return false;
    }
  }
  for (const [key, value] of Object.entries(managedNumerics)) {
    if (localSettings[key] !== value) return false;
  }
  for (const [id, entry] of Object.entries(managedModelSettings ?? {})) {
    if (localSettings.modelSettings?.[id]?.effortLevel !== entry.effortLevel) return false;
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

if (mode === "check") {
  console.log(
    "DRIFT          Claude tracked settings differ from the tracked fragment; run scripts/deploy-agent-workflow --apply",
  );
  process.exit(1);
}

const keyCount = Object.keys(trackedMap).length;
const settingsKeyCount =
  Object.keys(tracked.permissions ?? {}).length +
  Object.keys(tracked.attribution ?? {}).length +
  Object.keys(managedEnv ?? {}).length +
  Object.keys(managedModelSettings ?? {}).length +
  Object.keys(managedNumerics).length +
  [...SCALAR_KEYS].filter((key) => tracked[key] !== undefined).length;
if (dryRun) {
  if (mode === "deploy") {
    console.log(
      `WOULD_SYNC     Claude tracked settings (${keyCount} skills, ${settingsKeyCount} settings keys${localMissing ? ", new file" : ""})`,
    );
  }
  process.exit(0);
}

function hasUnsafeNumber(value, seen = new Set()) {
  if (typeof value === "number") {
    return !Number.isFinite(value) || (Number.isInteger(value) && !Number.isSafeInteger(value));
  }
  if (typeof value !== "object" || value === null || seen.has(value)) return false;
  seen.add(value);
  return Object.values(value).some((child) => hasUnsafeNumber(child, seen));
}
if (!localMissing && hasUnsafeNumber(localSettings)) {
  fail("local settings hold a number that cannot round-trip through JSON; refusing to rewrite");
}

const backup = localMissing ? null : backupFile(localPath, { stamp: timestamp });

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
  for (const [name, value] of Object.entries(tracked.attribution ?? {}).sort(
    ([a], [b]) => a.localeCompare(b),
  )) {
    console.log(`SET            attribution.${name} -> ${JSON.stringify(value)}`);
  }
  for (const [name, value] of Object.entries(managedEnv ?? {})) {
    console.log(`SET            env.${name} -> ${value}`);
  }
  for (const key of [...SCALAR_KEYS].sort()) {
    if (tracked[key] !== undefined) {
      console.log(`SET            ${key} -> ${tracked[key]}`);
    }
  }
  for (const [id, entry] of Object.entries(managedModelSettings ?? {}).sort(
    ([a], [b]) => a.localeCompare(b),
  )) {
    console.log(`SET            modelSettings.${id}.effortLevel -> ${entry.effortLevel}`);
  }
  for (const [key, value] of Object.entries(managedNumerics).sort(([a], [b]) =>
    a.localeCompare(b),
  )) {
    console.log(`SET            ${key} -> ${value}`);
  }
}

localSettings.skillOverrides = mergedMap;
if (tracked.permissions !== undefined) {
  localSettings.permissions = {
    ...(localSettings.permissions ?? {}),
    ...tracked.permissions,
  };
}
if (tracked.attribution !== undefined) {
  localSettings.attribution = {
    ...(localSettings.attribution ?? {}),
    ...tracked.attribution,
  };
}
if (managedEnv !== undefined) {
  localSettings.env = { ...(localSettings.env ?? {}), ...managedEnv };
}
for (const key of SCALAR_KEYS) {
  if (tracked[key] !== undefined) {
    localSettings[key] = tracked[key];
  }
}
if (
  managedModelSettings !== undefined &&
  (Object.keys(managedModelSettings).length > 0 || localSettings.modelSettings !== undefined)
) {
  const merged = { ...(localSettings.modelSettings ?? {}) };
  for (const [id, entry] of Object.entries(managedModelSettings)) {
    merged[id] = { ...(merged[id] ?? {}), effortLevel: entry.effortLevel };
  }
  localSettings.modelSettings = merged;
}
for (const [key, value] of Object.entries(managedNumerics)) {
  localSettings[key] = value;
}
writeJsonAtomic(localPath, localSettings);

if (mode === "deploy") {
  if (backup) console.log(`BACKUP         ${backup}`);
  console.log(
    `SYNC           Claude tracked settings (${keyCount} skills, ${settingsKeyCount} settings keys)`,
  );
}
