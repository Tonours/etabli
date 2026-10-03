import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  symlinkSync,
} from "node:fs";
import { dirname, isAbsolute, join, relative, sep } from "node:path";
import {
  confinedFile,
  inventoryCommand,
  sha256,
  sourceInventory,
  verifySourceManifest,
  workflowSourceExclusions,
} from "./project-verification-source.mjs";

export function createOwnedDirectory(root, target) {
  const path = relative(root, target);
  assert.ok(
    !isAbsolute(path) && !path.split(sep).includes(".."),
    "Owned directory must stay inside its root",
  );
  let directory = root;
  for (const part of path.split(sep).filter(Boolean)) {
    directory = join(directory, part);
    if (!existsSync(directory)) mkdirSync(directory, { mode: 0o700 });
    assert.ok(
      lstatSync(directory).isDirectory() &&
        realpathSync(directory) === directory,
      "Owned directory ancestor must be a regular directory without symlinks",
    );
  }
}

export function createVerificationSnapshot(root, runRoot, runtime = {}) {
  root = realpathSync(root);
  assert.ok(
    runRoot.startsWith(join(root, ".workflow") + sep),
    "Run must be project-local under .workflow",
  );
  createOwnedDirectory(root, dirname(runRoot));
  mkdirSync(runRoot, { mode: 0o700 });
  const snapshotRoot = join(runRoot, "subject");
  mkdirSync(snapshotRoot, { mode: 0o700 });
  const files = sourceInventory(root).map((path) => {
    const origin = confinedFile(root, path);
    const target = join(snapshotRoot, path);
    mkdirSync(dirname(target), { recursive: true });
    copyFileSync(origin, target);
    const mode = lstatSync(origin).mode & 0o777;
    chmodSync(target, mode);
    return { path, mode, sha256: sha256(readFileSync(target)) };
  });
  const manifest = {
    schema_version: 1,
    root,
    git_head: execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: root,
      encoding: "utf8",
    }).trim(),
    inventory_command: inventoryCommand,
    exclusions: workflowSourceExclusions,
    files,
  };
  const dependencies = (runtime.dependencies ?? []).map((dependency) => {
    const path = join(snapshotRoot, dependency.path);
    mkdirSync(dirname(path), { recursive: true });
    symlinkSync(dependency.target, path, "dir");
    return { ...dependency, cold_install: false };
  });
  const modules = (runtime.modules ?? []).map((module) => {
    const identity = JSON.parse(readFileSync(module.package_json, "utf8"));
    return {
      ...module,
      name: identity.name,
      version: identity.version,
      package_sha256: sha256(readFileSync(module.package_json)),
      cold_install: false,
    };
  });
  const lockfiles = files.filter((file) =>
    /(?:^|\/)(?:pnpm-lock.yaml|package-lock.json|yarn.lock|bun.lock|bun.lockb)$/.test(
      file.path,
    ),
  );
  verifyVerificationSnapshot(manifest, snapshotRoot);
  return {
    manifest,
    snapshotRoot,
    runtime: { dependencies, modules, lockfiles },
  };
}

export function verifyVerificationSnapshot(manifest, snapshotRoot) {
  verifySourceManifest(manifest, manifest.root);
  for (const file of manifest.files) {
    const copied = confinedFile(snapshotRoot, file.path);
    assert.equal(
      sha256(readFileSync(copied)),
      file.sha256,
      `Copied source changed: ${file.path}`,
    );
    assert.equal(
      lstatSync(copied).mode & 0o777,
      file.mode,
      `Copied source mode changed: ${file.path}`,
    );
  }
  return true;
}
