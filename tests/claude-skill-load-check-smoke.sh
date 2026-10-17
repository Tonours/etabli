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

live_state() {
  node -e 'const m=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).skillOverrides??{};console.log(m[process.argv[2]]??"absent")' "$FIX/home/.claude/settings.json" "$1"
}
set_live_state() {
  node - "$FIX/home/.claude/settings.json" "$1" "$2" <<'NODE'
const fs = require("node:fs");
const [file, name, state] = process.argv.slice(2);
const settings = JSON.parse(fs.readFileSync(file, "utf8"));
if (state === "absent") delete settings.skillOverrides[name];
else settings.skillOverrides[name] = state;
fs.writeFileSync(file, JSON.stringify(settings, null, 2));
NODE
}
CLAUDE_SKILL_LOAD_HOME="$FIX/home" CLAUDE_SKILL_LOAD_REPO="$FIX/repo" "$CHECK" --fix >"$FIX/fix.txt" 2>&1 ||
  fail "personal --fix: $(cat "$FIX/fix.txt")"
grep -qF "FIX: governed personal skill unmapped-newcomer as user-invocable-only" "$FIX/fix.txt" ||
  fail "personal --fix must govern the newcomer in live settings: $(cat "$FIX/fix.txt")"
[ "$(live_state unmapped-newcomer)" = "user-invocable-only" ] || fail "personal --fix must write the live settings"
grep -qF "unmapped-newcomer" "$FIX/repo/claude/settings.skill-overrides.json" && fail "personal --fix must not touch the tracked map"
expect_ok "personal skill governed in live settings" "$FIX/home" "$FIX/repo"
set_live_state unmapped-newcomer on
expect_fail "personal skill on in live settings" "$FIX/home" "$FIX/repo" 'personal skill unmapped-newcomer is "on"'
printf '%s\n' '["unmapped-newcomer"]' >"$FIX/repo/claude/machine-local-skills.json"
expect_ok "machine-local personal skill on in live settings" "$FIX/home" "$FIX/repo"
rm "$FIX/repo/claude/machine-local-skills.json"
set_live_state unmapped-newcomer user-invocable-only
rm -rf "$FIX/home/.claude/skills/unmapped-newcomer"
expect_fail "stale personal key" "$FIX/home" "$FIX/repo" "map key with no surface skill: unmapped-newcomer"
CLAUDE_SKILL_LOAD_HOME="$FIX/home" CLAUDE_SKILL_LOAD_REPO="$FIX/repo" "$CHECK" --fix >/dev/null 2>&1 || true
[ "$(live_state unmapped-newcomer)" = "absent" ] || fail "--fix must drop a stale personal key from live settings"
TRACKED_KEY="$(node -e 'console.log(Object.keys(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).skillOverrides).find(k=>true))' "$FIX/repo/claude/settings.skill-overrides.json")"
TRACKED_STATE="$(live_state "$TRACKED_KEY")"
set_live_state "$TRACKED_KEY" off
expect_fail "tracked key diverges in live settings" "$FIX/home" "$FIX/repo" "repo/live skillOverrides maps diverge"
set_live_state "$TRACKED_KEY" "$TRACKED_STATE"
expect_ok "fixture restored after personal-layer cases" "$FIX/home" "$FIX/repo"

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
node - "$FIX/home/.claude/skills/$KEEPER/SKILL.md" "$FIX/repo/claude/settings.skill-overrides.json" <<'NODE'
const fs = require("node:fs");
const [file, mapFile] = process.argv.slice(2);
const keepers = Object.entries(JSON.parse(fs.readFileSync(mapFile, "utf8")).skillOverrides)
  .filter(([, state]) => state === "on").map(([name]) => name);
const fixtureChars = keepers.reduce((sum, name) => sum + name.length + `stub ${name}`.length + 20, 0);
const text = fs.readFileSync(file, "utf8");
fs.writeFileSync(file, text.replace("description: stub", `description: ${"x".repeat(4912 - fixtureChars)}stub`));
NODE
expect_ok "exact 4912-character boundary" "$FIX/home" "$FIX/repo"
node - "$FIX/home/.claude/skills/$KEEPER/SKILL.md" <<'NODE'
const fs = require("node:fs");
const [file] = process.argv.slice(2);
fs.writeFileSync(file, fs.readFileSync(file, "utf8").replace("description: ", "description: x"));
NODE
expect_fail "4913 characters exceeds strengthened gate" "$FIX/home" "$FIX/repo" "exceeds gate 4912"

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
printf '%s\n' '["demo@marketplace"]' >"$FIX/repo/claude/machine-local-plugins.json"
expect_ok "machine-local plugin may ship skills" "$FIX/home" "$FIX/repo"
rm "$FIX/repo/claude/machine-local-plugins.json"

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

build_fixture "$FIX/home" "$FIX/repo"
mkdir -p "$FIX/repo/skills/shared/repo-newcomer"
printf -- '---\nname: repo-newcomer\ndescription: x\n---\nx\n' >"$FIX/repo/skills/shared/repo-newcomer/SKILL.md"
ln -s "$FIX/repo/skills/shared/repo-newcomer" "$FIX/home/.claude/skills/repo-newcomer"
set_live_state repo-newcomer user-invocable-only
expect_fail "repo skill cannot hide in the personal layer" "$FIX/home" "$FIX/repo" "ungoverned skill on the surface: repo-newcomer"
set_live_state repo-newcomer absent
rm "$FIX/home/.claude/skills/repo-newcomer"
rm -rf "$FIX/repo/skills"

mkdir -p "$FIX/plugin-demo/skills/whatever"
printf -- '---\nname: whatever\ndescription: x\n---\nx\n' >"$FIX/plugin-demo/skills/whatever/SKILL.md"
node - "$FIX/plugin-demo" "$FIX/home" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [pluginDir, home] = process.argv.slice(2);
const file = path.join(home, ".claude/settings.json");
const settings = JSON.parse(fs.readFileSync(file, "utf8"));
settings.enabledPlugins = { "demo@marketplace": true };
fs.writeFileSync(file, JSON.stringify(settings, null, 2));
fs.writeFileSync(
	path.join(home, ".claude/plugins/installed_plugins.json"),
	JSON.stringify({ plugins: { "demo@marketplace": [{ scope: "user", installPath: pluginDir }] } }),
);
NODE
expect_fail "enabled plugin ships skills" "$FIX/home" "$FIX/repo" "enabled plugin demo@marketplace ships skills"

# Scope policy: a repo backed by the real catalog. Work-scope skills are absent
# on shared/personal machines by design; the shared adr is shadowed on work.
SREPO="$FIX/scope-repo"
mkdir -p "$SREPO"
for shared_root in workflow vendor skills; do ln -s "$ROOT_DIR/$shared_root" "$SREPO/$shared_root"; done
WORK_ONLY="bug-check employer-backend-suite employer-docs-writing linear-project-setup linear-ticket-create linear-work pr-council-review"
build_scope_fixture() {
  build_fixture "$FIX/home" "$SREPO"
  rm -f "$FIX/home/.etabli-scope"
  [ -z "$1" ] || printf '%s\n' "$1" >"$FIX/home/.etabli-scope"
  case "$1" in
  work) rm -rf "$FIX/home/.claude/skills/adr" "$FIX/home/.claude/skills/synced/adr" ;;
  *) for name in $WORK_ONLY; do rm -rf "$FIX/home/.claude/skills/$name" "$FIX/home/.claude/skills/synced/$name"; done ;;
  esac
}
for scope in "" personal work; do
  build_scope_fixture "$scope"
  expect_ok "scope '${scope:-shared}' surface" "$FIX/home" "$SREPO"
done
build_scope_fixture ""
rm -rf "$FIX/home/.claude/skills/plan-loop"
expect_fail "missing expected keeper on shared" "$FIX/home" "$SREPO" "repo skill plan-loop expected for this scope is missing"
build_scope_fixture work
rm -rf "$FIX/home/.claude/skills/linear-work" "$FIX/home/.claude/skills/synced/linear-work"
expect_fail "missing work skill on work" "$FIX/home" "$SREPO" "repo skill linear-work expected for this scope is missing"
build_scope_fixture ""
node - "$SREPO/claude/settings.skill-overrides.json" <<'NODE'
const fs = require("node:fs");
const [file] = process.argv.slice(2);
const doc = JSON.parse(fs.readFileSync(file, "utf8"));
doc.skillOverrides["retired-unknown"] = "user-invocable-only";
fs.writeFileSync(file, JSON.stringify(doc, null, 2));
NODE
expect_fail "unknown stale key on shared" "$FIX/home" "$SREPO" "map key with no surface skill: retired-unknown"
CLAUDE_SKILL_LOAD_HOME="$FIX/home" CLAUDE_SKILL_LOAD_REPO="$SREPO" "$CHECK" --fix >/dev/null 2>&1 || fail "shared --fix failed"
jq -e '.skillOverrides | has("retired-unknown") | not' "$SREPO/claude/settings.skill-overrides.json" >/dev/null ||
  fail "--fix must drop a key with neither a surface nor a catalog skill"
jq -e '.skillOverrides["linear-work"] == "user-invocable-only" and .skillOverrides["employer-backend-suite"] == "on"' \
  "$SREPO/claude/settings.skill-overrides.json" >/dev/null || fail "--fix on shared must keep work-scope keys"
rm -f "$FIX/home/.etabli-scope"

SYNC="$ROOT_DIR/scripts/lib/claude-settings-sync.mjs"
mkdir -p "$FIX/sync"
printf '%s\n' '{"skillOverrides":{"repo-skill":"on"}}' >"$FIX/sync/tracked.json"
printf '%s\n' '{"theme":"dark","skillOverrides":{"repo-skill":"off","personal-hidden":"user-invocable-only","personal-on":"on"}}' >"$FIX/sync/settings.json"
node "$SYNC" "$FIX/sync/settings.json" "$FIX/sync/tracked.json" 0 t1 deploy >/dev/null || fail "settings sync first pass failed"
node -e '
const s = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const want = JSON.stringify({ "personal-hidden": "user-invocable-only", "repo-skill": "on" });
if (JSON.stringify(s.skillOverrides) !== want || s.theme !== "dark") { console.error(JSON.stringify(s)); process.exit(1); }
' "$FIX/sync/settings.json" || fail "settings sync must apply tracked keys, keep non-on personal keys, drop personal on keys"
second="$(node "$SYNC" "$FIX/sync/settings.json" "$FIX/sync/tracked.json" 0 t2 deploy)" || fail "settings sync second pass failed"
printf '%s\n' "$second" | grep -q "^OK  *Claude tracked settings" || fail "settings sync second pass must be a no-op, got: $second"
[ ! -e "$FIX/sync/settings.json.bak.t2" ] || fail "settings sync no-op pass must not write a backup"
printf '%s\n' '["machine-on"]' >"$FIX/sync/machine-local-skills.json"
printf '%s\n' '{"skillOverrides":{"machine-on":"on","personal-on":"on"}}' >"$FIX/sync/machine.json"
node "$SYNC" "$FIX/sync/machine.json" "$FIX/sync/tracked.json" 0 t3 deploy >/dev/null || fail "settings sync machine-local pass failed"
[ "$(jq -c .skillOverrides "$FIX/sync/machine.json")" = '{"machine-on":"on","repo-skill":"on"}' ] ||
  fail "settings sync must keep listed machine-local on keys and drop other personal on keys: $(jq -c .skillOverrides "$FIX/sync/machine.json")"
printf '%s\n' '{"skillOverrides":{"repo-skill":"on"},"autoMemoryEnabled":false}' >"$FIX/sync/tracked-memory.json"
node "$SYNC" "$FIX/sync/settings.json" "$FIX/sync/tracked-memory.json" 0 t3 deploy >/dev/null || fail "settings sync must accept a tracked autoMemoryEnabled key"
node -e '
const s = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
if (s.autoMemoryEnabled !== false || s.theme !== "dark") { console.error(JSON.stringify(s)); process.exit(1); }
' "$FIX/sync/settings.json" || fail "settings sync must write autoMemoryEnabled false and keep other keys"
mkdir -p "$FIX/sync/skills/personal-hidden" "$FIX/sync/skills/group/nested-dir"
printf -- '---\nname: personal-hidden\n---\n' >"$FIX/sync/skills/personal-hidden/SKILL.md"
printf -- '---\nname: nested-declared\n---\n' >"$FIX/sync/skills/group/nested-dir/SKILL.md"
ln -s "$FIX/sync/gone" "$FIX/sync/skills/removed-skill"
printf '%s\n' '{"skillOverrides":{"repo-skill":"on","personal-hidden":"off","nested-declared":"off","removed-skill":"off"}}' >"$FIX/sync/settings.json"
node "$SYNC" "$FIX/sync/settings.json" "$FIX/sync/tracked.json" 0 t4 deploy >/dev/null || fail "settings sync with a skill surface failed"
jq -e '.skillOverrides == {"nested-declared":"off","personal-hidden":"off","repo-skill":"on"}' "$FIX/sync/settings.json" >/dev/null ||
  fail "settings sync must drop personal keys whose skill left the surface: $(jq -c .skillOverrides "$FIX/sync/settings.json")"
jq -e '.autoMemoryEnabled == false' "$ROOT_DIR/claude/settings.skill-overrides.json" >/dev/null ||
  fail "claude/settings.skill-overrides.json must track autoMemoryEnabled false (the vault owns durable memory)"

printf '%s\n' "PASS: claude-skill-load-check fixture assertions"
