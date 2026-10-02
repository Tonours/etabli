import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { lstatSync, readFileSync, realpathSync } from "node:fs";
import { isAbsolute, join, relative, resolve, sep } from "node:path";

export const inventoryCommand = ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"];
export const workflowSourceExclusions = ["PLAN.md", ".workflow/", "docs/plan/"];
export const sha256 = bytes => createHash("sha256").update(bytes).digest("hex");

export function confinedFile(root, path) {
  assert.ok(typeof path === "string" && path.length && !isAbsolute(path) && !path.split(/[\\/]/).some(part => part === ".." || part === "."), `Unsafe evidence path: ${path}`);
  const base = realpathSync(root);
  const full = resolve(base, path);
  assert.ok(realpathSync(full).startsWith(base + sep), `Evidence escapes its root: ${path}`);
  assert.ok(lstatSync(full).isFile() && !lstatSync(full).isSymbolicLink(), `Evidence must be a regular file: ${path}`);
  return full;
}

export function sourceInventory(root) {
  const paths = [...new Set(execFileSync(inventoryCommand[0], inventoryCommand.slice(1), { cwd: root, encoding: "utf8" }).split("\0").filter(Boolean))].sort();
  return paths.filter(path => {
    if (workflowSourceExclusions.some(excluded => excluded.endsWith("/") ? path.startsWith(excluded) : path === excluded)) return false;
    assert.ok(!/(?:^|\/)\.env(?:\.|$)/.test(path) || /\.env\.(test|(?:production\.)?example)$/.test(path), `Private source configuration is not a public fixture: ${path}`);
    try { lstatSync(join(root, path)); return true; }
    catch (error) { if (error.code === "ENOENT") return false; throw error; }
  });
}

export function verifySourceManifest(manifest, expectedRoot, { allowRefChange = false } = {}) {
  const root = realpathSync(expectedRoot);
  assert.equal(manifest.schema_version, 1, "Unsupported source manifest");
  assert.equal(realpathSync(manifest.root), root, "Source manifest root differs from the declared project");
  assert.deepEqual(manifest.inventory_command, inventoryCommand, "Source inventory command must be the fixed Git inventory");
  assert.deepEqual(manifest.exclusions, workflowSourceExclusions, "Only fixed workflow artifacts may be excluded from source identity");
  assert.ok(Array.isArray(manifest.files) && manifest.files.length, "Source inventory is empty");
  assert.deepEqual(manifest.files.map(file => file.path), sourceInventory(root), "Source paths changed since launch (added/deleted/ignored files)");
  for (const file of manifest.files) {
    const full = confinedFile(root, file.path);
    assert.equal(sha256(readFileSync(full)), file.sha256, `Source content changed: ${file.path}`);
    assert.equal(lstatSync(full).mode & 0o777, file.mode, `Source mode changed: ${file.path}`);
  }
  const head = execFileSync("git", ["rev-parse", "HEAD"], { cwd: root, encoding: "utf8" }).trim();
  if (!allowRefChange) assert.equal(manifest.git_head, head, "Source Git ref changed since launch");
  return { root, ref: manifest.git_head, paths: manifest.files.map(file => relative(root, join(root, file.path))) };
}
