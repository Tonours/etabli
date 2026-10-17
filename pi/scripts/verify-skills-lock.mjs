import { readFile, readdir, stat, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { hashSkillTree } from "../../scripts/lib/skill-tree-hash.mjs";

const piDir = dirname(dirname(fileURLToPath(import.meta.url)));
const repoDir = dirname(piDir);

const fail = (message) => {
  console.error(`skills-lock.json verification failed:\n${message}`);
  process.exit(1);
};

let lock;
try {
  lock = JSON.parse(await readFile(join(repoDir, "skills-lock.json"), "utf8"));
} catch (error) {
  fail(
    `invalid skills-lock.json: ${error instanceof Error ? error.message : String(error)}`,
  );
}

const write = process.argv.includes("--write");
const catalog = (
  await readFile(
    join(repoDir, "workflow", "runtime", "skill-surface.tsv"),
    "utf8",
  )
)
  .split("\n")
  .filter((line) => line && !line.startsWith("#"))
  .map((line) => {
    const [name, source, piCore, locked] = line.split("\t");
    return {
      name,
      source,
      piCore: piCore === "1",
      locked: locked === "1",
    };
  });

function sourceRootOf(source) {
  if (source === "etabli") return repoDir;
  if (source === "extras") return join(repoDir, "extras");
  return join(repoDir, "vendor", source);
}

async function hashSkill(name, source) {
  return hashSkillTree(join(sourceRootOf(source), "skills", name));
}

// First-party skill directories on disk (skills/<scope>/<name>), so a new
// skill cannot ship without a catalog row.
async function firstPartySkillNames() {
  const names = [];
  const root = join(repoDir, "skills");
  for (const scope of (await readdir(root)).sort()) {
    let entries = [];
    try {
      entries = await readdir(join(root, scope));
    } catch {
      continue;
    }
    for (const name of entries.sort()) {
      try {
        if ((await stat(join(root, scope, name, "SKILL.md"))).isFile())
          names.push(`${scope}/${name}`);
      } catch {
        // not a skill directory
      }
    }
  }
  return names;
}

const failures = [];

// Every catalog row must point at an existing skill directory. Locked rows
// are covered by hashing below; this also covers shelf rows (non-locked),
// which nothing else checks — a deleted skill dir with a surviving catalog
// row would otherwise drift silently.
for (const entry of catalog) {
  const skillDir = join(sourceRootOf(entry.source), "skills", entry.name);
  try {
    await stat(skillDir);
  } catch {
    failures.push(
      `${entry.name}: catalog row has no skill directory (${skillDir})`,
    );
  }
}
const catalogedFirstParty = new Set(
  catalog.filter((entry) => entry.source === "etabli").map((entry) => entry.name),
);
for (const name of await firstPartySkillNames()) {
  if (!catalogedFirstParty.has(name))
    failures.push(`${name}: skills/${name} has no etabli row in skill-surface.tsv`);
}

const lockedNames = new Set(
  catalog.filter((entry) => entry.locked).map((entry) => entry.name),
);
for (const name of Object.keys(lock.skills)) {
  if (lockedNames.has(name)) continue;
  if (write) delete lock.skills[name];
  else
    failures.push(
      `${name}: lock entry is not declared locked in skill-surface.tsv`,
    );
}

for (const skill of catalog.filter((entry) => entry.locked)) {
  const actual = await hashSkill(skill.name, skill.source);
  const entry = lock.skills[skill.name];
  if (write && !entry)
    lock.skills[skill.name] = {
      source: "local",
      sourceType: "repo",
      computedHash: actual,
    };
  else if (!entry)
    failures.push(
      `${skill.name}: locked catalog skill missing from skills-lock.json`,
    );
  else if (write) entry.computedHash = actual;
  else if (actual !== entry.computedHash)
    failures.push(
      `${skill.name}: expected ${entry.computedHash}, got ${actual}`,
    );
}

if (write && failures.length === 0) {
  await writeFile(
    join(repoDir, "skills-lock.json"),
    `${JSON.stringify(lock, null, 2)}\n`,
  );
  console.log(`Updated ${Object.keys(lock.skills).length} skill hashes.`);
  process.exit(0);
}

if (failures.length > 0) {
  console.error(
    "skills-lock.json verification failed:\n" + failures.join("\n"),
  );
  console.error(
    "Run `cd pi && bun run update:skills-lock`, review the diff, then verify again.",
  );
  process.exit(1);
}

console.log(`Verified ${Object.keys(lock.skills).length} skill hashes.`);
