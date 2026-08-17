import { createHash } from "node:crypto";
import { readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const piDir = dirname(dirname(fileURLToPath(import.meta.url)));
const repoDir = dirname(piDir);
const lock = JSON.parse(await readFile(join(repoDir, "skills-lock.json"), "utf8"));
const settings = JSON.parse(await readFile(join(piDir, "agent", "settings.json"), "utf8"));
const write = process.argv.includes("--write");
const catalog = (await readFile(join(repoDir, "workflow", "runtime", "skill-surface.tsv"), "utf8"))
  .split("\n")
  .filter((line) => line && !line.startsWith("#"))
  .map((line) => {
    const [name, source, piCore, agentsVisible, locked] = line.split("\t");
    return { name, source, piCore: piCore === "1", agentsVisible: agentsVisible === "1", locked: locked === "1" };
  });

function configuredLocalSkills() {
  const result = new Set();
  for (const pkg of settings.packages ?? []) {
    if (typeof pkg !== "object" || pkg === null) continue;
    if (pkg.source !== "local:etabli-workflow") continue;
    for (const skill of pkg.skills ?? []) {
      result.add(skill);
    }
  }
  return [...result].sort();
}

const UNHASHED_ENTRIES = new Set(["__pycache__", ".DS_Store", "node_modules", ".pytest_cache", ".ruff_cache"]);

function isHashable(entry) {
  return !UNHASHED_ENTRIES.has(entry.name) && !entry.name.endsWith(".pyc");
}

async function files(dir, base = dir) {
  const entries = (await readdir(dir, { withFileTypes: true })).filter(isHashable);
  const nested = await Promise.all(entries.map(async (entry) => {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) return files(full, base);
    return [{ path: relative(base, full).split("\\").join("/"), content: await readFile(full) }];
  }));
  return nested.flat().sort((a, b) => a.path.localeCompare(b.path));
}

async function hashSkill(name, source = "pi") {
  const hash = createHash("sha256");
  const sourceRoot = source === "pi" ? join(repoDir, "pi") : join(repoDir, "vendor", source);
  for (const file of await files(join(sourceRoot, "skills", name))) {
    hash.update(file.path);
    hash.update(file.content);
  }
  return hash.digest("hex");
}

const failures = [];
const configured = configuredLocalSkills();
const catalogPiCore = catalog.filter((entry) => entry.source === "pi" && entry.piCore).map((entry) => entry.name).sort();
if (JSON.stringify(configured) !== JSON.stringify(catalogPiCore)) {
  failures.push("skill-surface.tsv pi_core entries differ from pi/agent/settings.json");
}

const lockedNames = new Set(catalog.filter((entry) => entry.locked).map((entry) => entry.name));
for (const name of Object.keys(lock.skills)) {
  if (!lockedNames.has(name)) failures.push(`${name}: lock entry is not declared locked in skill-surface.tsv`);
}

for (const skill of catalog.filter((entry) => entry.locked)) {
  const actual = await hashSkill(skill.name, skill.source);
  const entry = lock.skills[skill.name];
  if (write && !entry) lock.skills[skill.name] = { source: "local", sourceType: "repo", computedHash: actual };
  else if (!entry) failures.push(`${skill.name}: locked catalog skill missing from skills-lock.json`);
  else if (write) entry.computedHash = actual;
  else if (actual !== entry.computedHash) failures.push(`${skill.name}: expected ${entry.computedHash}, got ${actual}`);
}

if (write && failures.length === 0) {
  await writeFile(join(repoDir, "skills-lock.json"), `${JSON.stringify(lock, null, 2)}\n`);
  console.log(`Updated ${Object.keys(lock.skills).length} skill hashes.`);
  process.exit(0);
}

if (failures.length > 0) {
  console.error("skills-lock.json verification failed:\n" + failures.join("\n"));
  console.error("Run `cd pi && bun run update:skills-lock`, review the diff, then verify again.");
  process.exit(1);
}

console.log(`Verified ${Object.keys(lock.skills).length} skill hashes.`);
