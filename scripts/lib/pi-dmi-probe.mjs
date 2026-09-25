/**
 * Probe: DMI skills load with the flag, stay out of the model prompt, and
 * keep resolvable expansion data — using Pi's NATIVE loader + formatter.
 * Usage: pi-dmi-probe --dir <skills-dir> --expect-dmi <csv-names>
 * Exit 0 when every expected skill loads flagged, is absent from the
 * formatted prompt as a <name> entry, and points at an existing SKILL.md.
 */
import { existsSync } from "node:fs";
import { basename } from "node:path";
import { loadPiSkillsModule } from "./pi-loader.mjs";

const args = process.argv.slice(2);
function flag(name) {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : null;
}
const dir = flag("--dir");
const csv = flag("--expect-dmi");
if (!dir || !csv) {
  console.error("usage: pi-dmi-probe --dir <skills-dir> --expect-dmi <csv-names>");
  process.exit(2);
}
const expected = csv.split(",").map((s) => s.trim()).filter(Boolean);
if (!expected.length) {
  console.error("pi-dmi-probe: empty --expect-dmi set");
  process.exit(2);
}

let loader;
try {
  loader = await loadPiSkillsModule();
} catch (error) {
  console.error(`pi-dmi-probe: ${error.message}`);
  process.exit(2);
}

const { skills } = loader.loadSkillsFromDir({ dir });
const prompt = loader.formatSkillsForPrompt(skills);
let failed = 0;
for (const name of expected) {
  const skill = skills.find((s) => s.name === name);
  if (!skill) {
    console.error(`FAIL ${name}: not loaded from ${dir} (probe the loader, not the flag)`);
    failed = 1;
    continue;
  }
  if (skill.disableModelInvocation !== true) {
    console.error(`FAIL ${name}: loaded without disableModelInvocation=true (add the frontmatter flag)`);
    failed = 1;
  }
  if (prompt.includes(`<name>${name}</name>`)) {
    console.error(`FAIL ${name}: present in the model prompt as <name> entry (DMI not honored?)`);
    failed = 1;
  }
  // Expansion reads the SKILL.md itself: prove the exact file, not the dir.
  const fp = skill.filePath || skill.sourceInfo?.path;
  if (!fp || basename(fp) !== "SKILL.md" || !existsSync(fp)) {
    console.error(`FAIL ${name}: no resolvable SKILL.md expansion path (got ${fp || "none"})`);
    failed = 1;
  }
}
if (failed) process.exit(1);
console.log(`pi-dmi-probe: ok (${expected.length} skills hidden but expandable)`);
