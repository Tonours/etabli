import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const piDir = dirname(dirname(fileURLToPath(import.meta.url)));
const repoDir = dirname(piDir);
const lock = JSON.parse(await readFile(join(repoDir, "skills-lock.json"), "utf8"));

async function files(dir, base = dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const nested = await Promise.all(entries.map(async (entry) => {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) return files(full, base);
    return [{ path: relative(base, full).split("\\").join("/"), content: await readFile(full) }];
  }));
  return nested.flat().sort((a, b) => a.path.localeCompare(b.path));
}

async function hashSkill(name) {
  const hash = createHash("sha256");
  for (const file of await files(join(piDir, "skills", name))) {
    hash.update(file.path);
    hash.update(file.content);
  }
  return hash.digest("hex");
}

const failures = [];
for (const [name, entry] of Object.entries(lock.skills)) {
  const actual = await hashSkill(name);
  if (actual !== entry.computedHash) failures.push(`${name}: expected ${entry.computedHash}, got ${actual}`);
}

if (failures.length > 0) {
  console.error("skills-lock.json verification failed:\n" + failures.join("\n"));
  process.exit(1);
}

console.log(`Verified ${Object.keys(lock.skills).length} skill hashes.`);
