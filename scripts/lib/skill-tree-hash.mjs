import { createHash } from "node:crypto";
import { lstatSync, readdirSync, readFileSync } from "node:fs";
import { join, relative, sep } from "node:path";

// Single source of truth for skill-tree hashing, shared by the skills-lock
// updater (pi/scripts/verify-skills-lock.mjs) and the runtime skill canary
// (scripts/lib/runtime-skill-canary.mjs). Both surfaces must produce the
// same digest for the same tree; keep every rule change HERE only.
//
// Excluded entries are generated at use time, never skill content: OS noise
// and dependency caches. Vendored skills that self-install helper scripts
// (poteto-mode bootstrap writes node_modules/ and an install key) must not
// drift the pinned skills-lock hash on first use.
const EXCLUDED_DIRS = new Set([
  "__pycache__",
  "node_modules",
  ".pytest_cache",
  ".ruff_cache",
]);
const EXCLUDED_FILES = new Set([".DS_Store", ".poteto-mode-tools-install-key"]);

function isExcludedFile(name) {
  return EXCLUDED_FILES.has(name) || name.endsWith(".pyc");
}

/**
 * sha256 of a skill directory tree. Relative paths are forward-slash
 * normalized; files are hashed in localeCompare order (path then content).
 * `root` itself may be a symlink to a directory (readdir follows it);
 * any symlink inside the tree throws — hash inputs must be real files.
 */
export function hashSkillTree(root) {
  const hash = createHash("sha256");
  const files = [];
  const stack = [root];
  while (stack.length > 0) {
    const current = stack.pop();
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      if (EXCLUDED_DIRS.has(entry.name) || isExcludedFile(entry.name)) continue;
      const path = join(current, entry.name);
      // lstat, not stat: a followed stat can never report the symlink this
      // check exists to reject.
      const stat = lstatSync(path);
      if (stat.isSymbolicLink()) {
        throw new Error("skill source contains an unsupported symlink");
      }
      if (stat.isDirectory()) stack.push(path);
      else if (stat.isFile()) files.push(path);
    }
  }
  const toKey = (path) => relative(root, path).split(sep).join("/");
  for (const path of files.sort((a, b) => toKey(a).localeCompare(toKey(b)))) {
    hash.update(toKey(path));
    hash.update(readFileSync(path));
  }
  return hash.digest("hex");
}
