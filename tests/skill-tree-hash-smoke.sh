#!/usr/bin/env bash
set -euo pipefail

# Pins the semantics of scripts/lib/skill-tree-hash.mjs, the single hasher
# shared by the skills-lock updater and the runtime skill canary:
# pollution equivalence (generated artifacts never change the digest) and
# the explicit in-tree symlink rejection.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# shellcheck disable=SC1090
node --input-type=module - "$ROOT_DIR" "$TMP_DIR" <<'EOF'
import { mkdirSync, writeFileSync, symlinkSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const { hashSkillTree } = await import(
  pathToFileURL(join(process.argv[2], "scripts/lib/skill-tree-hash.mjs")).href,
);

const tmp = process.argv[3];
const clean = join(tmp, "clean");
const polluted = join(tmp, "polluted");

for (const root of [clean, polluted]) {
  mkdirSync(join(root, "nested"), { recursive: true });
  writeFileSync(join(root, "SKILL.md"), "---\nname: fixture\n---\nbody\n");
  writeFileSync(join(root, "nested", "helper.md"), "helper\n");
}

// Generated artifacts that must not affect the digest.
mkdirSync(join(polluted, "node_modules", ".bin"), { recursive: true });
mkdirSync(join(polluted, "node_modules", "pkg"), { recursive: true });
writeFileSync(join(polluted, "node_modules", "pkg", "index.js"), "installed\n");
symlinkSync("../pkg", join(polluted, "node_modules", ".bin", "pkg"));
writeFileSync(join(polluted, ".DS_Store"), "finder noise");
writeFileSync(join(polluted, "compile.pyc"), "bytecode");
writeFileSync(join(polluted, ".poteto-mode-tools-install-key"), "install marker");
mkdirSync(join(polluted, "__pycache__"), { recursive: true });
writeFileSync(join(polluted, "__pycache__", "mod.pyc"), "cache");

const cleanDigest = hashSkillTree(clean);
const pollutedDigest = hashSkillTree(polluted);
if (cleanDigest !== pollutedDigest) {
  console.error(`pollution changed the digest: ${cleanDigest} != ${pollutedDigest}`);
  process.exit(1);
}
if (!/^[0-9a-f]{64}$/.test(cleanDigest)) {
  console.error(`digest is not sha256 hex: ${cleanDigest}`);
  process.exit(1);
}

// A symlink at an included location must be rejected explicitly.
const linked = join(tmp, "linked");
mkdirSync(join(linked, "nested"), { recursive: true });
writeFileSync(join(linked, "SKILL.md"), "body\n");
symlinkSync(join(linked, "SKILL.md"), join(linked, "nested", "alias.md"));
try {
  hashSkillTree(linked);
  console.error("in-tree symlink must throw");
  process.exit(1);
} catch (error) {
  if (!String(error?.message ?? "").includes("unsupported symlink")) {
    console.error(`wrong error for in-tree symlink: ${error?.message}`);
    process.exit(1);
  }
}
EOF

printf 'PASS: skill-tree-hash smoke\n'
