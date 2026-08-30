#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CHECK="$ROOT_DIR/scripts/claude-skill-load-check"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

FIX="$(mktemp -d "${TMPDIR:-/tmp}/claude-skill-load.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

build_fixture() {
  local home="$1" repo="$2"
  rm -rf "$home/.claude" "$repo/claude"
  mkdir -p "$home/.claude/skills" "$repo/claude" "$home/.claude/plugins"
  node - "$ROOT_DIR/claude/settings.skill-overrides.json" "$home" "$repo" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [mapFile, home, repo] = process.argv.slice(2);
const map = JSON.parse(fs.readFileSync(mapFile, "utf8")).skillOverrides;
const keepers = Object.entries(map).filter(([, v]) => v === "on");
const hidden = Object.entries(map).filter(([, v]) => v !== "on");
fs.mkdirSync(path.join(home, ".claude/skills"), { recursive: true });
let nestedDone = false;
for (const [name, state] of [...keepers, ...hidden]) {
  let dir = path.join(home, ".claude/skills", name);
  if (!nestedDone && state === "user-invocable-only") {
    dir = path.join(home, ".claude/skills/synced", name);
    nestedDone = true;
  }
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(
    path.join(dir, "SKILL.md"),
    `---\nname: ${name}\ndescription: stub ${name}\n---\nstub\n`,
  );
}
fs.writeFileSync(path.join(home, ".claude/settings.json"), JSON.stringify({ enabledPlugins: {}, skillOverrides: map }, null, 2));
fs.copyFileSync(mapFile, path.join(repo, "claude/settings.skill-overrides.json"));
fs.writeFileSync(path.join(home, ".claude/plugins/installed_plugins.json"), JSON.stringify({ plugins: {} }));
NODE
  touch "$home/.claude/skills/.DS_Store"
}

expect_ok() {
  local label="$1" home="$2" repo="$3" out
  out="$(CLAUDE_SKILL_LOAD_HOME="$home" CLAUDE_SKILL_LOAD_REPO="$repo" "$CHECK" 2>&1)" ||
    fail "$label: expected ok, got: $out"
  printf '%s\n' "$out" | grep -q "claude-skill-load-check: ok" ||
    fail "$label: ok line missing"
}

expect_fail() {
  local label="$1" home="$2" repo="$3" pattern="$4"
  CLAUDE_SKILL_LOAD_HOME="$home" CLAUDE_SKILL_LOAD_REPO="$repo" "$CHECK" >/dev/null 2>"$FIX/err.txt" &&
    fail "$label: expected failure, got success"
  grep -qF "$pattern" "$FIX/err.txt" ||
    fail "$label: expected '$pattern' in: $(cat "$FIX/err.txt")"
}

build_fixture "$FIX/home" "$FIX/repo"

expect_ok "clean fixture (nested synced/ + .DS_Store tolerated)" "$FIX/home" "$FIX/repo"

mkdir -p "$FIX/home/.claude/skills/unmapped-newcomer"
printf -- '---\nname: unmapped-newcomer\ndescription: x\n---\nx\n' >"$FIX/home/.claude/skills/unmapped-newcomer/SKILL.md"
expect_fail "ungoverned newcomer" "$FIX/home" "$FIX/repo" "ungoverned skill on the surface: unmapped-newcomer"
rm -rf "$FIX/home/.claude/skills/unmapped-newcomer"

KEEPER="$(node -e 'const m=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).skillOverrides;console.log(Object.keys(m).find(k=>m[k]==="on"))' "$FIX/repo/claude/settings.skill-overrides.json")"
printf -- '---\nname: %s\ndescription: stub %s\ndisable-model-invocation: true\n---\nstub\n' "$KEEPER" "$KEEPER" >"$FIX/home/.claude/skills/$KEEPER/SKILL.md"
expect_fail "pinned keeper silenced by dmi" "$FIX/home" "$FIX/repo" "pinned keeper not effectively listed: $KEEPER"
printf -- '---\nname: %s\ndescription: stub %s\n---\nstub\n' "$KEEPER" "$KEEPER" >"$FIX/home/.claude/skills/$KEEPER/SKILL.md"

ln -s "$FIX/nowhere" "$FIX/home/.claude/skills/dangling-probe"
expect_fail "dangling link" "$FIX/home" "$FIX/repo" "dangling link"
rm "$FIX/home/.claude/skills/dangling-probe"

mkdir -p "$FIX/skills.disabled/ui-pruned/retired-probe"
printf -- '---\nname: retired-probe\ndescription: x\n---\nx\n' >"$FIX/skills.disabled/ui-pruned/retired-probe/SKILL.md"
ln -s "$FIX/skills.disabled/ui-pruned/retired-probe" "$FIX/home/.claude/skills/retired-probe"
expect_fail "skills.disabled target" "$FIX/home" "$FIX/repo" "link into skills.disabled"
rm "$FIX/home/.claude/skills/retired-probe"

node - "$FIX/home/.claude/skills/$KEEPER/SKILL.md" <<'NODE'
const fs = require("node:fs");
const [file] = process.argv.slice(2);
const text = fs.readFileSync(file, "utf8");
fs.writeFileSync(file, text.replace("description: stub", `description: ${"x".repeat(6000)}`));
NODE
expect_fail "budget exceeded" "$FIX/home" "$FIX/repo" "exceeds gate"

build_fixture "$FIX/home" "$FIX/repo"
node - "$FIX/repo/claude/settings.skill-overrides.json" "$FIX/home" "$FIX/repo" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [mapFile, home, repo] = process.argv.slice(2);
const file = path.join(repo, "claude/settings.skill-overrides.json");
const map = JSON.parse(fs.readFileSync(file, "utf8")).skillOverrides;
const promoted = Object.keys(map).find((k) => map[k] === "user-invocable-only");
map[promoted] = "on";
fs.mkdirSync(path.join(home, ".claude/skills", promoted), { recursive: true });
fs.writeFileSync(path.join(home, ".claude/skills", promoted, "SKILL.md"), `---\nname: ${promoted}\ndescription: stub ${promoted}\n---\nstub\n`);
fs.writeFileSync(file, JSON.stringify({ skillOverrides: map }, null, 2));
const settings = JSON.parse(fs.readFileSync(path.join(home, ".claude/settings.json"), "utf8"));
settings.skillOverrides = map;
fs.writeFileSync(path.join(home, ".claude/settings.json"), JSON.stringify(settings, null, 2));
NODE
expect_fail "listed beyond pinned keep-set" "$FIX/home" "$FIX/repo" "beyond the pinned keep-set"

build_fixture "$FIX/home" "$FIX/repo"
mkdir -p "$FIX/plugin/skills/whatever"
printf -- '---\nname: whatever\ndescription: x\n---\nx\n' >"$FIX/plugin/skills/whatever/SKILL.md"
node - "$FIX/home" "$FIX/plugin" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [home, pluginDir] = process.argv.slice(2);
const settings = JSON.parse(fs.readFileSync(path.join(home, ".claude/settings.json"), "utf8"));
settings.enabledPlugins = { "demo@marketplace": true };
fs.writeFileSync(path.join(home, ".claude/settings.json"), JSON.stringify(settings, null, 2));
fs.writeFileSync(
  path.join(home, ".claude/plugins/installed_plugins.json"),
  JSON.stringify({ plugins: { "demo@marketplace": [{ scope: "user", installPath: pluginDir }] } }),
);
NODE
expect_fail "enabled plugin ships skills" "$FIX/home" "$FIX/repo" "enabled plugin demo@marketplace ships skills"

build_fixture "$FIX/home" "$FIX/repo"
node - "$FIX/home" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [home] = process.argv.slice(2);
const file = path.join(home, ".claude/settings.json");
const settings = JSON.parse(fs.readFileSync(file, "utf8"));
delete settings.skillOverrides;
fs.writeFileSync(file, JSON.stringify(settings, null, 2));
NODE
expect_fail "deploy not applied (repo/live divergence)" "$FIX/home" "$FIX/repo" "skillOverrides"

printf '%s\n' "PASS: claude-skill-load-check fixture assertions"
