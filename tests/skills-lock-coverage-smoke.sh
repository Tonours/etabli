#!/usr/bin/env bash
# Every first-party skills/<scope>/<name> tree needs a catalog row, and
# skills-lock.json must pin every locked one. Expected trees are derived from
# the filesystem (not from the lock generator) and hashed with the shared
# skill-tree hasher, so a missed tree fails here.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
LOCK="$ROOT_DIR/skills-lock.json"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -f "$LOCK" ] || fail "missing lock: $LOCK"

ROOT_DIR="$ROOT_DIR" node --input-type=module >"$TMP_DIR/expected" <<'NODE'
import { readdir, readFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = process.env.ROOT_DIR;
const { hashSkillTree } = await import(
  pathToFileURL(join(root, "scripts/lib/skill-tree-hash.mjs")).href
);

const roots = [];
const catalogRows = new Map(
  (await readFile(join(root, "workflow/runtime/skill-surface.tsv"), "utf8"))
    .split("\n")
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => line.split("\t"))
    .filter(([, source]) => source === "etabli")
    .map(([name, , , locked]) => [name, locked === "1"]),
);
const treeRoot = join(root, "skills");
for (const scope of (await readdir(treeRoot)).sort()) {
  let entries = [];
  try {
    entries = await readdir(join(treeRoot, scope));
  } catch {
    continue;
  }
  for (const name of entries.sort()) {
    const dir = join(treeRoot, scope, name);
    let isDir = false;
    try {
      isDir = (await stat(dir)).isDirectory();
    } catch {
      isDir = false;
    }
    if (!isDir) continue;
    const key = `${scope}/${name}`;
    if (!catalogRows.has(key)) {
      process.stderr.write(`FAIL: skills/${key} has no etabli catalog row\n`);
      process.exit(1);
    }
    if (catalogRows.get(key)) roots.push({ key, root: dir });
  }
}
for (const entry of roots) {
  process.stdout.write(`${entry.key}\t${hashSkillTree(entry.root)}\n`);
}
NODE

count=0
while IFS=$'\t' read -r key hash; do
  [ -n "$key" ] || continue
  actual="$(jq -r --arg k "$key" '.skills[$k].computedHash // empty' "$LOCK")"
  [ -n "$actual" ] || fail "lock missing pinned tree: $key"
  if [ "$actual" != "$hash" ]; then
    fail "lock hash drift for $key: lock=$actual computed=$hash"
  fi
  count=$((count + 1))
done <"$TMP_DIR/expected"

[ "$count" -ge 1 ] || fail "coverage smoke found only $count pinned trees; derivation is broken"

printf 'skills lock coverage smoke test: ok (%s pinned trees)\n' "$count"
