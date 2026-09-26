#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
STAMP="$ROOT_DIR/scripts/pi-dmi-stamp"
MERGE="$ROOT_DIR/scripts/claude-hooks-merge"
HCHECK="$ROOT_DIR/scripts/claude-hooks-check"
PILOAD="$ROOT_DIR/scripts/pi-skill-load-check"
FRAGMENT="$ROOT_DIR/claude/settings.workflow-hooks.json"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pi_marker() { [ -L "$1/.pi/agent/extensions" ] || [ -e "$1/.pi/agent/extensions" ]; }
fragment_hook_files() {
  node --input-type=module -e '
import { readFileSync } from "node:fs";
const { hookScriptNames } = await import(process.argv[2]);
const names = hookScriptNames(JSON.parse(readFileSync(process.argv[1], "utf8")));
if (!names.length) { console.error("no hook files derived from fragment"); process.exit(1); }
console.log(names.join("\n"));' "$FRAGMENT" "file://$ROOT_DIR/scripts/lib/claude-hooks-fragment.mjs"
}
claude_marker() {
  local home="$1" hook hook_files
  hook_files="$(fragment_hook_files)" || fail "cannot derive fragment hook files"
  while IFS= read -r hook; do
    [ -L "$home/.claude/hooks/$hook" ] && return 0
    [ -e "$home/.claude/hooks/$hook" ] && return 0
  done <<< "$hook_files"
  return 1
}

run_live() {
  local live_home="$1"
  if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf 'SKIP live branches: CI environment\n'
    return 0
  fi
  if pi_marker "$live_home"; then
    "$PILOAD" --home "$live_home" || fail "live pi-skill-load-check failed"
    "$STAMP" --check --home "$live_home" || fail "live stamp --check failed"
  else
    printf 'SKIP pi live branch: no etabli Pi deploy marker\n'
  fi
  if claude_marker "$live_home"; then
    "$HCHECK" --home "$live_home" || fail "live claude-hooks-check failed"
  else
    printf 'SKIP claude live branch: no etabli Claude hooks marker\n'
  fi
}

if [ "${1:-}" = "--live-only" ]; then
  run_live "${LIVE_HOME:-$HOME}"
  printf '%s\n' "PASS: guards-active live branch"
  exit 0
fi

[ -x "$STAMP" ] || fail "missing executable scripts/pi-dmi-stamp"
[ -x "$MERGE" ] || fail "missing executable scripts/claude-hooks-merge"
[ -x "$HCHECK" ] || fail "missing executable scripts/claude-hooks-check"

REPO_DMI="grill-me coolify design componentize add-dark-mode canonicalize-tailwind make-responsive dark-mode-image brand-kit markup-from-image ideas"
pin_repo_dmi() {
  node --input-type=module -e "
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createRequire } from 'node:module';
const { parse } = createRequire(join('$ROOT_DIR', 'pi/package.json'))('yaml');
const missing = [];
for (const name of process.argv.slice(2)) {
  const file = join(process.argv[1], 'extras/skills', name, 'SKILL.md');
  if (!existsSync(file)) { missing.push(name + ' (absent)'); continue; }
  const text = readFileSync(file, 'utf8');
  const head = parse(text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|\$)/)[1]);
  if (head['disable-model-invocation'] !== true) missing.push(name);
}
if (missing.length) { console.error('repo DMI flags missing: ' + missing.join(', ')); process.exit(1); }
" "$@"
}
pin_repo_dmi "$ROOT_DIR" $REPO_DMI || fail "repo DMI pin failed"
FIXPIN="$TMP_DIR/fixpin"
mkdir -p "$FIXPIN/extras/skills"
for name in $REPO_DMI; do
  [ "$name" = "ideas" ] && continue
  mkdir -p "$FIXPIN/extras/skills/$name"
  cp "$ROOT_DIR/extras/skills/$name/SKILL.md" "$FIXPIN/extras/skills/$name/"
done
if pin_repo_dmi "$FIXPIN" $REPO_DMI 2>"$TMP_DIR/fixpin-err.txt"; then
  fail "DMI pin must fail when a repo skill file is absent"
fi
grep -q "absent" "$TMP_DIR/fixpin-err.txt" || fail "absent pin failure unexplained"

STAMP_HOME="$TMP_DIR/stamp-home"
mkdir -p "$STAMP_HOME/.agents/skills/hyperframes" "$STAMP_HOME/.agents/skills/ghost-lab" \
  "$STAMP_HOME/.pi/agent/npm/node_modules/mitsupi/skills/github"
for dir in "$STAMP_HOME/.agents/skills/hyperframes" "$STAMP_HOME/.agents/skills/ghost-lab"; do
  name="$(basename "$dir")"
  printf -- '---\nname: %s\ndescription: fixture\n---\nbody\n' "$name" >"$dir/SKILL.md"
done
printf -- '---\nname: github\ndescription: fixture\n---\nbody\n' \
  >"$STAMP_HOME/.pi/agent/npm/node_modules/mitsupi/skills/github/SKILL.md"
ln -s "$ROOT_DIR/extras/skills/grill-me" "$STAMP_HOME/.agents/skills/grill-me"
cp "$ROOT_DIR/extras/skills/grill-me/SKILL.md" "$TMP_DIR/grill-orig.md"

"$STAMP" --list --home "$STAMP_HOME" >"$TMP_DIR/stamp-list.txt" || fail "stamp --list failed"
grep -q "hyperframes" "$TMP_DIR/stamp-list.txt" || fail "stamp list hides hyperframes"
grep -q "radius-api" "$TMP_DIR/stamp-list.txt" || fail "stamp list hides radius-api"

"$STAMP" --dry-run --home "$STAMP_HOME" >/dev/null || fail "stamp dry-run failed"
if grep -q "disable-model-invocation" "$STAMP_HOME/.agents/skills/hyperframes/SKILL.md"; then
  fail "dry-run must not write"
fi

"$STAMP" --home "$STAMP_HOME" >"$TMP_DIR/stamp-out.txt" || fail "stamp run failed"
for file in "$STAMP_HOME/.agents/skills/hyperframes/SKILL.md" \
  "$STAMP_HOME/.agents/skills/ghost-lab/SKILL.md" \
  "$STAMP_HOME/.pi/agent/npm/node_modules/mitsupi/skills/github/SKILL.md"; do
  grep -q "^disable-model-invocation: true$" "$file" || fail "flag missing in $file"
done
cmp -s "$ROOT_DIR/extras/skills/grill-me/SKILL.md" "$TMP_DIR/grill-orig.md" \
  || fail "stamp touched a repo realpath"
grep -q -i -e "absent" -e "skip" "$TMP_DIR/stamp-out.txt" || fail "stamp must report absent names"

cp "$STAMP_HOME/.agents/skills/hyperframes/SKILL.md" "$TMP_DIR/hyper-orig.md"
"$STAMP" --home "$STAMP_HOME" >/dev/null || fail "stamp rerun failed"
cmp -s "$STAMP_HOME/.agents/skills/hyperframes/SKILL.md" "$TMP_DIR/hyper-orig.md" \
  || fail "stamp is not idempotent"

"$STAMP" --check --home "$STAMP_HOME" >/dev/null || fail "stamp --check failed after stamping"
grep -v "^disable-model-invocation: true$" "$STAMP_HOME/.agents/skills/ghost-lab/SKILL.md" >"$TMP_DIR/ghost-stripped.md"
mv "$TMP_DIR/ghost-stripped.md" "$STAMP_HOME/.agents/skills/ghost-lab/SKILL.md"
if "$STAMP" --check --home "$STAMP_HOME" >/dev/null 2>&1; then
  fail "stamp --check must fail when a flag is removed"
fi
"$STAMP" --home "$STAMP_HOME" >/dev/null || fail "re-stamp after flag removal failed"
"$STAMP" --check --home "$STAMP_HOME" >/dev/null || fail "stamp --check failed after re-stamp"

BROKEN_HOME="$TMP_DIR/broken-home"
mkdir -p "$BROKEN_HOME/.agents/skills/hyperframes" "$BROKEN_HOME/.agents/skills/ghost-lab" \
  "$BROKEN_HOME/.agents/skills/media-use"
printf 'no frontmatter here\n' >"$BROKEN_HOME/.agents/skills/hyperframes/SKILL.md"
printf -- '---\nname: ghost-lab\ndescription: fixture\n---\nbody\n' >"$BROKEN_HOME/.agents/skills/ghost-lab/SKILL.md"
printf -- '---\n# comment only\n---\nbody\n' >"$BROKEN_HOME/.agents/skills/media-use/SKILL.md"
if "$STAMP" --home "$BROKEN_HOME" >"$TMP_DIR/broken-out.txt" 2>&1; then
  fail "stamp must fail on frontmatterless files"
fi
grep -q "pi-dmi-stamp: stamped=" "$TMP_DIR/broken-out.txt" || fail "failed stamp printed no summary"
grep -qi "empty frontmatter" "$TMP_DIR/broken-out.txt" || fail "null frontmatter head unexplained"
grep -q "^disable-model-invocation: true$" "$BROKEN_HOME/.agents/skills/ghost-lab/SKILL.md" \
  || fail "stamp aborted before completing the loop"
if "$STAMP" --check --home "$BROKEN_HOME" >"$TMP_DIR/broken-check-out.txt" 2>&1; then
  fail "stamp --check must fail on frontmatterless files"
fi
grep -q "pi-dmi-stamp: stamped=" "$TMP_DIR/broken-check-out.txt" || fail "failed check printed no summary"

EDGE_HOME="$TMP_DIR/edge-home"
mkdir -p "$EDGE_HOME/.agents/skills/hyperframes" "$EDGE_HOME/.agents/skills/ghost-lab" \
  "$EDGE_HOME/.agents/skills/media-use" "$EDGE_HOME/.agents/skills/motion-graphics"
printf -- '---\nname: hyperframes\n"disable-model-invocation": false\ndescription: fixture\n---\nbody\n' \
  >"$EDGE_HOME/.agents/skills/hyperframes/SKILL.md"
printf -- '---\nname: ghost-lab\ndescription: fixture\nnested:\n  disable-model-invocation: keep-me\n---\nbody\n' \
  >"$EDGE_HOME/.agents/skills/ghost-lab/SKILL.md"
printf -- '---\nname: media-use\ndescription: >\n  folded line one\n  folded line two\n---\nbody\n' \
  >"$EDGE_HOME/.agents/skills/media-use/SKILL.md"
printf -- '---\n- just\n- a\n- list\n---\nbody\n' \
  >"$EDGE_HOME/.agents/skills/motion-graphics/SKILL.md"
if "$STAMP" --home "$EDGE_HOME" >"$TMP_DIR/edge-out.txt" 2>&1; then
  fail "stamp must fail on a sequence frontmatter head"
fi
grep -q "pi-dmi-stamp: stamped=" "$TMP_DIR/edge-out.txt" || fail "edge stamp printed no summary"
[ "$(grep -c "disable-model-invocation" "$EDGE_HOME/.agents/skills/hyperframes/SKILL.md")" = "1" ] \
  || fail "quoted key duplicated instead of updated"
grep -q '"disable-model-invocation": true' "$EDGE_HOME/.agents/skills/hyperframes/SKILL.md" \
  || fail "quoted key not flipped to true"
grep -q "^disable-model-invocation: true$" "$EDGE_HOME/.agents/skills/ghost-lab/SKILL.md" \
  || fail "top-level flag missing with nested homonym"
grep -q "  disable-model-invocation: keep-me" "$EDGE_HOME/.agents/skills/ghost-lab/SKILL.md" \
  || fail "nested homonym altered"
node --input-type=module -e "
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createRequire } from 'node:module';
const { parse } = createRequire(join(process.argv[2], 'pi/package.json'))('yaml');
const head = parse(readFileSync(process.argv[1], 'utf8').match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)[1]);
if (head.description !== 'folded line one folded line two\n') { console.error('folded description changed'); process.exit(1); }
if (head['disable-model-invocation'] !== true) { console.error('flag missing'); process.exit(1); }
if (JSON.stringify(Object.keys(head).sort()) !== JSON.stringify(['description', 'disable-model-invocation', 'name'])) { console.error('keys changed'); process.exit(1); }
" "$EDGE_HOME/.agents/skills/media-use/SKILL.md" "$ROOT_DIR" || fail "folded fixture altered beyond the flag"
if "$STAMP" --check --home "$EDGE_HOME" >/dev/null 2>&1; then
  fail "stamp --check must fail on the unflaggable edge fixture"
fi

REAL_REPO="$TMP_DIR/realrepo"
mkdir -p "$REAL_REPO/skills/motion-graphics"
printf -- '---\nname: motion-lesson\ndescription: fixture\n---\nbody\n' >"$REAL_REPO/skills/motion-graphics/SKILL.md"
ln -s "$REAL_REPO" "$TMP_DIR/repo-alias"
ALIAS_HOME="$TMP_DIR/alias-home"
mkdir -p "$ALIAS_HOME/.agents/skills"
ln -s "$REAL_REPO/skills/motion-graphics" "$ALIAS_HOME/.agents/skills/motion-graphics"
"$STAMP" --home "$ALIAS_HOME" --repo "$TMP_DIR/repo-alias" >"$TMP_DIR/alias-out.txt" \
  || fail "stamp failed with aliased repo"
grep -q "skip repo-managed" "$TMP_DIR/alias-out.txt" || fail "aliased repo path not skipped"
if grep -q "disable-model-invocation" "$REAL_REPO/skills/motion-graphics/SKILL.md"; then
  fail "stamp wrote through an aliased repo link"
fi
if "$STAMP" --home "$ALIAS_HOME" --repo "$TMP_DIR/nope" >/dev/null 2>&1; then
  fail "stamp must fail on unresolvable --repo"
fi

LINKFILE_HOME="$TMP_DIR/linkfile-home"
mkdir -p "$LINKFILE_HOME/.agents/skills/logo-generator" "$TMP_DIR/linkfile-real"
printf -- '---\nname: logo-generator\ndescription: fixture\n---\nbody\n' >"$TMP_DIR/linkfile-real/SKILL.md"
ln -s "$TMP_DIR/linkfile-real/SKILL.md" "$LINKFILE_HOME/.agents/skills/logo-generator/SKILL.md"
"$STAMP" --home "$LINKFILE_HOME" >/dev/null || fail "stamp failed on symlinked SKILL.md"
[ -L "$LINKFILE_HOME/.agents/skills/logo-generator/SKILL.md" ] || fail "stamp replaced a symlinked SKILL.md"
grep -q "^disable-model-invocation: true$" "$TMP_DIR/linkfile-real/SKILL.md" || fail "stamp missed the link target"
if find "$STAMP_HOME" "$EDGE_HOME" "$ALIAS_HOME" "$LINKFILE_HOME" "$BROKEN_HOME" -name '*.tmp.*' 2>/dev/null | grep -q .; then
  fail "stamp left tmp files behind"
fi

MODE_HOME="$TMP_DIR/mode-home"
mkdir -p "$MODE_HOME/.agents/skills/ideas"
printf -- '---\nname: ideas\ndescription: fixture\n---\nbody\n' >"$MODE_HOME/.agents/skills/ideas/SKILL.md"
chmod 600 "$MODE_HOME/.agents/skills/ideas/SKILL.md"
"$STAMP" --home "$MODE_HOME" >/dev/null || fail "stamp failed on restrictive-mode skill"
grep -q "^disable-model-invocation: true$" "$MODE_HOME/.agents/skills/ideas/SKILL.md" || fail "restrictive-mode skill not flagged"
node -e 'const m = require("fs").statSync(process.argv[1]).mode & 0o777; if (m !== 0o600) { console.error("mode loosened to " + m.toString(8)); process.exit(1); }' "$MODE_HOME/.agents/skills/ideas/SKILL.md" || fail "stamp loosened file mode"

MG_HOME="$TMP_DIR/merge-home"
mkdir -p "$MG_HOME/.claude"
"$MERGE" --dry-run --home "$MG_HOME" >/dev/null || fail "merge dry-run failed on absent settings"
if [ -e "$MG_HOME/.claude/settings.json" ]; then fail "dry-run must not create settings"; fi
"$MERGE" --home "$MG_HOME" >/dev/null || fail "merge failed on absent settings"
node -e '
const s = require(process.argv[1]);
const cmds = [];
for (const groups of Object.values(s.hooks)) for (const g of groups) for (const h of g.hooks || []) cmds.push(h.command);
for (const want of ["plan-ready-guard.mjs", "no-comments-guard.mjs", "ledger-auto-emit.mjs", "detect-adr-signal.mjs", "outcome-metric-emit.mjs"]) {
  if (!cmds.some((c) => c.includes(want))) { console.error("missing " + want); process.exit(1); }
}' "$MG_HOME/.claude/settings.json" || fail "merged settings lack fragment hooks"
node -e '
if (Object.keys(require(process.argv[1])).join(",") !== "hooks") process.exit(1);
' "$MG_HOME/.claude/settings.json" || fail "merge of absent settings must create hooks-only file"

cp "$MG_HOME/.claude/settings.json" "$TMP_DIR/merge-orig.json"
"$MERGE" --home "$MG_HOME" >/dev/null || fail "merge rerun failed"
cmp -s "$MG_HOME/.claude/settings.json" "$TMP_DIR/merge-orig.json" || fail "merge is not byte-idempotent"
ready_count="$(grep -c "plan-ready-guard.mjs" "$MG_HOME/.claude/settings.json")"
[ "$ready_count" = "1" ] || fail "merge duplicated plan-ready-guard ($ready_count)"

USER_HOME="$TMP_DIR/user-home"
mkdir -p "$USER_HOME/.claude"
printf '%s' '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"my-local-hook","timeout":5}]}]},"permissions":{"defaultMode":"bypassPermissions"}}' \
  >"$USER_HOME/.claude/settings.json"
cp "$USER_HOME/.claude/settings.json" "$TMP_DIR/user-pre.json"
"$MERGE" --home "$USER_HOME" >/dev/null || fail "merge failed with user hooks"
grep -q "my-local-hook" "$USER_HOME/.claude/settings.json" || fail "merge dropped a user hook"
grep -q "bypassPermissions" "$USER_HOME/.claude/settings.json" || fail "merge touched permissions"
backup=( "$USER_HOME"/.claude/settings.json.bak.* )
[ "${#backup[@]}" = "1" ] || fail "merge wrote without exactly one backup"
cmp -s "${backup[0]}" "$TMP_DIR/user-pre.json" || fail "backup differs from pre-merge settings"
node -e '
const s = require(process.argv[1]);
if (JSON.stringify(s.permissions) !== JSON.stringify({ defaultMode: "bypassPermissions" })) process.exit(1);
' "$USER_HOME/.claude/settings.json" || fail "merge altered user permissions"

BAD_HOME="$TMP_DIR/bad-home"
mkdir -p "$BAD_HOME/.claude"
printf '%s' '{"hooks": {"oops"' >"$BAD_HOME/.claude/settings.json"
cp "$BAD_HOME/.claude/settings.json" "$TMP_DIR/bad-orig.json"
if "$MERGE" --home "$BAD_HOME" >/dev/null 2>&1; then
  fail "merge must refuse invalid JSON"
fi
cmp -s "$BAD_HOME/.claude/settings.json" "$TMP_DIR/bad-orig.json" || fail "refused merge modified the file"

CONF_HOME="$TMP_DIR/conf-home"
mkdir -p "$CONF_HOME/.claude"
node -e '
const fs = require("fs");
const fragment = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const live = { hooks: JSON.parse(JSON.stringify(fragment.hooks)) };
live.hooks.PreToolUse[0].hooks[0].timeout = 99;
fs.writeFileSync(process.argv[2] + "/.claude/settings.json", JSON.stringify(live));' \
  "$FRAGMENT" "$CONF_HOME"
cp "$CONF_HOME/.claude/settings.json" "$TMP_DIR/conf-orig.json"
if "$MERGE" --home "$CONF_HOME" >"$TMP_DIR/conf-out.txt" 2>&1; then
  fail "merge must refuse on parameter mismatch"
fi
grep -qi -e "conflict" -e "mismatch" -e "refus" "$TMP_DIR/conf-out.txt" || fail "conflict refusal unexplained"
cmp -s "$CONF_HOME/.claude/settings.json" "$TMP_DIR/conf-orig.json" || fail "refused merge modified the file"

node --input-type=module -e "
import { parseFragment } from 'file://$ROOT_DIR/scripts/lib/claude-hooks-fragment.mjs';
import { readFileSync } from 'node:fs';
parseFragment(readFileSync('$FRAGMENT', 'utf8'));
const bad = ['{oops', 'null', '[]', '{}', '{\"hooks\":{}}', '{\"hooks\":null}', '{\"hooks\":{\"PreToolUse\":null}}', '{\"hooks\":{\"PreToolUse\":[null]}}', '{\"hooks\":{\"PreToolUse\":[{\"hooks\":[{\"type\":\"command\"}]}]}}'];
for (const text of bad) {
  let threw = false;
  try { parseFragment(text); } catch { threw = true; }
  if (!threw) { console.error('parseFragment accepted: ' + text); process.exit(1); }
}" || fail "fragment validator gaps"

GUARD_CMD="$(node -e 'console.log(require(process.argv[1]).hooks.PreToolUse[0].hooks[0].command)' "$FRAGMENT")"
CROSS_HOME="$TMP_DIR/cross-home"
mkdir -p "$CROSS_HOME/.claude"
node -e '
const live = { hooks: { Stop: [{ hooks: [{ type: "command", command: process.argv[2], timeout: 5 }] }] } };
require("fs").writeFileSync(process.argv[1] + "/.claude/settings.json", JSON.stringify(live));' \
  "$CROSS_HOME" "$GUARD_CMD"
"$MERGE" --home "$CROSS_HOME" >/dev/null || fail "merge must allow same command on different events"
[ "$(grep -c "plan-ready-guard.mjs" "$CROSS_HOME/.claude/settings.json")" = "2" ] \
  || fail "cross-event wiring lost an entry"
OVERLAP_HOME="$TMP_DIR/overlap-home"
mkdir -p "$OVERLAP_HOME/.claude"
node -e '
const live = { hooks: { PreToolUse: [{ matcher: "Bash", hooks: [{ type: "command", command: process.argv[2], timeout: 5 }] }] } };
require("fs").writeFileSync(process.argv[1] + "/.claude/settings.json", JSON.stringify(live));' \
  "$OVERLAP_HOME" "$GUARD_CMD"
cp "$OVERLAP_HOME/.claude/settings.json" "$TMP_DIR/overlap-orig.json"
if "$MERGE" --home "$OVERLAP_HOME" >"$TMP_DIR/overlap-out.txt" 2>&1; then
  fail "merge must refuse same-event overlapping wiring"
fi
grep -qi "conflict" "$TMP_DIR/overlap-out.txt" || fail "overlap refusal unexplained"
cmp -s "$OVERLAP_HOME/.claude/settings.json" "$TMP_DIR/overlap-orig.json" || fail "refused merge modified the file"

ASYNC_HOME="$TMP_DIR/async-home"
mkdir -p "$ASYNC_HOME/.claude"
node -e '
const fs = require("fs");
const fragment = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const live = { hooks: JSON.parse(JSON.stringify(fragment.hooks)) };
live.hooks.PreToolUse[0].hooks[0].async = true;
fs.writeFileSync(process.argv[2] + "/.claude/settings.json", JSON.stringify(live));' \
  "$FRAGMENT" "$ASYNC_HOME"
cp "$ASYNC_HOME/.claude/settings.json" "$TMP_DIR/async-orig.json"
if "$MERGE" --home "$ASYNC_HOME" >"$TMP_DIR/async-out.txt" 2>&1; then
  fail "merge must refuse an async variant of a fragment hook"
fi
grep -qi "conflict" "$TMP_DIR/async-out.txt" || fail "async refusal unexplained"
cmp -s "$ASYNC_HOME/.claude/settings.json" "$TMP_DIR/async-orig.json" || fail "refused merge modified the file"
if "$HCHECK" --home "$ASYNC_HOME" >"$TMP_DIR/async-check-out.txt" 2>&1; then
  fail "check must fail on an async variant of a fragment hook"
fi
grep -q "plan-ready-guard" "$TMP_DIR/async-check-out.txt" || fail "async check names no entry"
grep -q "claude-hooks-merge" "$TMP_DIR/async-check-out.txt" || fail "async check names no remediation"

DA_HOME="$TMP_DIR/da-home"
mkdir -p "$DA_HOME/.claude"
node -e '
const fs = require("fs");
const fragment = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const live = { hooks: JSON.parse(JSON.stringify(fragment.hooks)), disableAllHooks: true };
fs.writeFileSync(process.argv[2] + "/.claude/settings.json", JSON.stringify(live));' \
  "$FRAGMENT" "$DA_HOME"
if "$MERGE" --home "$DA_HOME" >"$TMP_DIR/da-out.txt" 2>&1; then
  fail "merge must refuse when disableAllHooks is true"
fi
grep -q "disableAllHooks" "$TMP_DIR/da-out.txt" || fail "disableAllHooks refusal unexplained"
if "$HCHECK" --home "$DA_HOME" >"$TMP_DIR/da-check-out.txt" 2>&1; then
  fail "check must fail when disableAllHooks is true"
fi
grep -q "disableAllHooks" "$TMP_DIR/da-check-out.txt" || fail "disableAllHooks check unexplained"

DUP_HOME="$TMP_DIR/dup-home"
mkdir -p "$DUP_HOME/.claude"
node -e '
const fs = require("fs");
const fragment = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const live = { hooks: JSON.parse(JSON.stringify(fragment.hooks)) };
live.hooks.PreToolUse.push({ matcher: "Bash", hooks: [{ type: "command", command: process.argv[3], timeout: 99 }] });
fs.writeFileSync(process.argv[2] + "/.claude/settings.json", JSON.stringify(live));' \
  "$FRAGMENT" "$DUP_HOME" "$GUARD_CMD"
if "$MERGE" --home "$DUP_HOME" >"$TMP_DIR/dup-out.txt" 2>&1; then
  fail "merge must refuse a same-event duplicate beside an exact entry"
fi
grep -qi "conflict" "$TMP_DIR/dup-out.txt" || fail "duplicate refusal unexplained"

ARR_HOME="$TMP_DIR/arr-home"
mkdir -p "$ARR_HOME/.claude"
printf '%s' '{"hooks":{"Stop":[[]]}}' >"$ARR_HOME/.claude/settings.json"
cp "$ARR_HOME/.claude/settings.json" "$TMP_DIR/arr-orig.json"
if "$MERGE" --home "$ARR_HOME" >"$TMP_DIR/arr-out.txt" 2>&1; then
  fail "merge must refuse an array group"
fi
cmp -s "$ARR_HOME/.claude/settings.json" "$TMP_DIR/arr-orig.json" || fail "refused merge modified the file"
if "$HCHECK" --home "$ARR_HOME" >"$TMP_DIR/arr-check-out.txt" 2>&1; then
  fail "check must fail on an array group"
fi
grep -q "claude-hooks-merge" "$TMP_DIR/arr-check-out.txt" || fail "array check names no remediation"

if "$HCHECK" --home "$MG_HOME" >"$TMP_DIR/mg-noscripts-out.txt" 2>&1; then
  fail "hooks check must fail when hook scripts are missing"
fi
grep -q "hook script missing" "$TMP_DIR/mg-noscripts-out.txt" || fail "missing-script failure unexplained"
grep -q "deploy-agent-workflow" "$TMP_DIR/mg-noscripts-out.txt" || fail "missing-script failure names no remedy"
mkdir -p "$MG_HOME/.claude/hooks"
fragment_hook_files | while IFS= read -r hook; do touch "$MG_HOME/.claude/hooks/$hook"; done
"$HCHECK" --home "$MG_HOME" >/dev/null || fail "hooks check failed on merged settings with scripts"
one_script="$(fragment_hook_files | head -n 1)"
rm "$MG_HOME/.claude/hooks/$one_script"
if "$HCHECK" --home "$MG_HOME" >"$TMP_DIR/mg-partial-out.txt" 2>&1; then
  fail "hooks check must fail on a partially deployed hooks dir"
fi
grep -q "$one_script" "$TMP_DIR/mg-partial-out.txt" || fail "partial scripts failure names no script"
touch "$MG_HOME/.claude/hooks/$one_script"
"$HCHECK" --home "$MG_HOME" >/dev/null || fail "hooks check failed after script restore"
rm "$MG_HOME/.claude/hooks/$one_script" && mkdir "$MG_HOME/.claude/hooks/$one_script"
if "$HCHECK" --home "$MG_HOME" >"$TMP_DIR/mg-dir-out.txt" 2>&1; then
  fail "hooks check must fail when a hook script path is a directory"
fi
grep -q "$one_script" "$TMP_DIR/mg-dir-out.txt" || fail "directory script failure names no script"
rmdir "$MG_HOME/.claude/hooks/$one_script" && touch "$MG_HOME/.claude/hooks/$one_script"
"$HCHECK" --home "$MG_HOME" >/dev/null || fail "hooks check failed after directory restore"
if "$HCHECK" --home "$TMP_DIR/nonexistent-home-xyz" >"$TMP_DIR/check-out.txt" 2>&1; then
  fail "hooks check must fail when settings are absent"
fi
grep -q "claude-hooks-merge" "$TMP_DIR/check-out.txt" || fail "check failure names no remediation"

SHAPE_HOME="$TMP_DIR/shape-home"
mkdir -p "$SHAPE_HOME/.claude"
printf '%s' '{"hooks":{"PreToolUse":[null]}}' >"$SHAPE_HOME/.claude/settings.json"
cp "$SHAPE_HOME/.claude/settings.json" "$TMP_DIR/shape-orig.json"
if "$MERGE" --home "$SHAPE_HOME" >"$TMP_DIR/shape-out.txt" 2>&1; then
  fail "merge must refuse malformed group shapes"
fi
grep -qi "refuse" "$TMP_DIR/shape-out.txt" || fail "malformed refusal unexplained"
cmp -s "$SHAPE_HOME/.claude/settings.json" "$TMP_DIR/shape-orig.json" || fail "refused merge modified the file"
if "$HCHECK" --home "$SHAPE_HOME" >"$TMP_DIR/shape-check-out.txt" 2>&1; then
  fail "check must fail on malformed group shapes"
fi
grep -q "claude-hooks-merge" "$TMP_DIR/shape-check-out.txt" || fail "malformed check names no remediation"
NULL_HOME="$TMP_DIR/null-home"
mkdir -p "$NULL_HOME/.claude"
printf 'null' >"$NULL_HOME/.claude/settings.json"
if "$HCHECK" --home "$NULL_HOME" >"$TMP_DIR/null-check-out.txt" 2>&1; then
  fail "check must fail on null settings"
fi
grep -q "claude-hooks-merge" "$TMP_DIR/null-check-out.txt" || fail "null check names no remediation"

EMPTY_HOME="$TMP_DIR/empty-home"
mkdir -p "$EMPTY_HOME"
if pi_marker "$EMPTY_HOME"; then fail "empty home must not trip the Pi marker"; fi
if claude_marker "$EMPTY_HOME"; then fail "empty home must not trip the Claude marker"; fi
MARKER_HOME="$TMP_DIR/marker-home"
mkdir -p "$MARKER_HOME/.pi/agent" "$MARKER_HOME/.claude/hooks"
touch "$MARKER_HOME/.pi/agent/extensions"
ln -s /nonexistent-xyz "$MARKER_HOME/.claude/hooks/plan-ready-guard.mjs"
pi_marker "$MARKER_HOME" || fail "extensions file must trip the Pi marker"
claude_marker "$MARKER_HOME" || fail "dangling hook link must trip the Claude marker"

LIVE_HOME="$EMPTY_HOME" bash "$0" --live-only >"$TMP_DIR/live-skip.txt" 2>&1 || fail "live-only must SKIP on empty home"
grep -q "SKIP" "$TMP_DIR/live-skip.txt" || fail "live-only printed no SKIP"

CI_CLAUDE_HOME="$TMP_DIR/ci-claude-home"
mkdir -p "$CI_CLAUDE_HOME/.claude/hooks"
ln -s /nonexistent-xyz "$CI_CLAUDE_HOME/.claude/hooks/plan-ready-guard.mjs"
if env -u CI -u GITHUB_ACTIONS LIVE_HOME="$CI_CLAUDE_HOME" bash "$0" --live-only >"$TMP_DIR/ci-control.txt" 2>&1; then
  fail "live-only without CI must attempt live on a marker home"
fi
grep -q "live claude-hooks-check failed" "$TMP_DIR/ci-control.txt" || fail "CI control did not reach the live check"
CI=true LIVE_HOME="$CI_CLAUDE_HOME" bash "$0" --live-only >"$TMP_DIR/ci-skip.txt" 2>&1 \
  || fail "live-only must SKIP in CI even with markers"
grep -q "SKIP live branches: CI" "$TMP_DIR/ci-skip.txt" || fail "CI skip unexplained"

if (FRAGMENT="$TMP_DIR/nope.json" claude_marker "$TMP_DIR" 2>"$TMP_DIR/deriv-err.txt"); then
  fail "marker derivation failure must fail closed"
fi
grep -q "cannot derive" "$TMP_DIR/deriv-err.txt" || fail "derivation failure unexplained"

run_live "${LIVE_HOME:-$HOME}"

printf '%s\n' "PASS: guards-active fixture + live assertions"
