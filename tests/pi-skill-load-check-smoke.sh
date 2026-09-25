#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CHECK="$ROOT_DIR/scripts/pi-skill-load-check"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

HOME_FIX="$TMP_DIR/home"
mkdir -p "$HOME_FIX/.pi/agent/skills" "$HOME_FIX/.agents/skills"

write_skill() {
  local dir="$1" name="$2" dmi="$3"
  mkdir -p "$dir"
  {
    printf -- '---\nname: %s\ndescription: fixture\n' "$name"
    [ "$dmi" = "1" ] && printf 'disable-model-invocation: true\n'
    printf -- '---\nbody\n'
  } >"$dir/SKILL.md"
}

write_skill "$HOME_FIX/.pi/agent/skills/plan-loop" plan-loop 0
write_skill "$HOME_FIX/.pi/agent/skills/project-hunt" project-hunt 1
write_skill "$HOME_FIX/.pi/agent/skills/deslop" deslop 0
write_skill "$HOME_FIX/.agents/skills/runtime-skill-canary" runtime-skill-canary 1
write_skill "$HOME_FIX/.agents/skills/find-skills" find-skills 0
write_skill "$HOME_FIX/.pi/agent/npm/node_modules/mitsupi/skills/github" github 0

write_settings() {
  printf '%s\n' "{ \"skills\": [$1], \"packages\": [ { \"source\": \"npm:mitsupi\", \"skills\": [\"github\"] } ] }" >"$HOME_FIX/.pi/agent/settings.json"
}

cat >"$TMP_DIR/dump.txt" <<DUMP
You are a coding assistant.

The following skills provide specialized instructions for specific tasks.
<available_skills>
  <skill>
    <name>plan-loop</name>
    <location>PLACEHOLDER/.pi/agent/skills/plan-loop/SKILL.md</location>
    <description>fixture</description>
  </skill>
  <skill>
    <name>github</name>
    <location>PLACEHOLDER/.pi/agent/npm/node_modules/mitsupi/skills/github/SKILL.md</location>
    <description>fixture</description>
  </skill>
</available_skills>
DUMP

sed "s#PLACEHOLDER#$HOME_FIX#g" "$TMP_DIR/dump.txt" >"$TMP_DIR/dump-final.txt"

write_settings '"!deslop", "!find-skills"'
out="$(PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" 2>&1)" || {
  printf 'checker failed on the happy fixture:\n%s\n' "$out" >&2
  exit 1
}
echo "$out" | grep -q "entries=2 universe=5 deny=2 dmi=2" || fail "counts wrong: $out"
echo "$out" | grep -q "pi-skill-load-check: ok" || fail "ok line missing"

write_settings '"!deslop"'
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "missing deny entry (find-skills) must trip B2(ii)"
fi

write_settings '"!deslop", "!plan-loop"'
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "denying a rendered keeper must trip B2"
fi

write_settings '"!deslop", "!project-hunt"'
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "denying a dmi skill must trip the deny/dmi guard"
fi

write_settings '"!deslop", "!find-skills"'
python3 - "$HOME_FIX/.pi/agent/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as file:
    settings = json.load(file)
settings['packages'].append({'source': 'npm:pi-mcp-adapter', 'skills': ['mcp-scripting']})
with open(path, 'w') as file:
    json.dump(settings, file)
PY
MCP_SKILL="$HOME_FIX/.pi/agent/npm/node_modules/pi-mcp-adapter/skills/mcp-scripting"
write_skill "$MCP_SKILL" mcp-scripting 1
if ! PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >"$TMP_DIR/package.out" 2>&1; then
  cat "$TMP_DIR/package.out" >&2
  fail "package DMI skill must stay installed without rendering"
fi

write_skill "$MCP_SKILL" mcp-scripting 0
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "non-DMI package keeper missing from the block must fail"
fi

write_skill "$HOME_FIX/.pi/agent/skills/mcp-scripting" mcp-scripting 1
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "root DMI cannot exempt a different package identity from validation"
fi
rm "$HOME_FIX/.pi/agent/skills/mcp-scripting/SKILL.md"

printf '\ndisable-model-invocation: true\n' >>"$MCP_SKILL/SKILL.md"
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "DMI text in the body cannot hide a package keeper"
fi

write_skill "$MCP_SKILL" mcp-scripting 1
python3 - "$TMP_DIR/dump-final.txt" "$TMP_DIR/dmi-rendered.txt" "$MCP_SKILL/SKILL.md" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
entry = '  <skill>\n    <name>mcp-scripting</name>\n    <location>' + sys.argv[3] + '</location>\n    <description>fixture</description>\n  </skill>\n'
Path(sys.argv[2]).write_text(text.replace('</available_skills>', entry + '</available_skills>'))
PY
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dmi-rendered.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "DMI package keeper rendered in the block must fail"
fi

printf '%s\n' '---' 'disable-model-invocation: true' >"$MCP_SKILL/SKILL.md"
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "malformed package frontmatter cannot hide a missing skill"
fi
write_skill "$MCP_SKILL" wrong-name 1
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "package keeper must declare its expected name"
fi
for header in 'name: "mcp-scripting' 'description: [unterminated' 'description: # no description'; do
  write_skill "$MCP_SKILL" mcp-scripting 1
  python3 - "$MCP_SKILL/SKILL.md" "$header" <<'PY'
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
header = sys.argv[2]
key = header.split(':', 1)[0]
path.write_text(re.sub('^' + key + ':.*$', header, path.read_text(), flags=re.M))
PY
  if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
    fail "invalid YAML or empty description cannot exempt a DMI package"
  fi
done
cat >"$MCP_SKILL/SKILL.md" <<'YAML'
---
name: "mcp-scripting"
description: >-
  Explicit MCP scripting access.
disable-model-invocation: true # native YAML boolean
---
Body.
YAML
python3 - "$MCP_SKILL/SKILL.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_bytes(path.read_bytes().replace(b'\n', b'\r\n'))
PY
if ! PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "valid quoted names, folded descriptions and CRLF must follow native YAML semantics"
fi
rm "$MCP_SKILL/SKILL.md"
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "missing package SKILL.md cannot silently pass"
fi

write_settings '"!deslop", "!find-skills", "!ghost-absent-xyz"'
if ! PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >/dev/null 2>&1; then
  fail "deny entry for an absent skill must be inert, not B2(ii)-extra"
fi

SUB_HOME="$TMP_DIR/subhome"
mkdir -p "$SUB_HOME/.pi/agent/skills"
write_skill "$SUB_HOME/.pi/agent/skills/plan-loop" plan-loop 0
write_skill "$SUB_HOME/.pi/agent/skills/deslop" deslop 0
printf '%s\n' '{ "skills": ["!deslop", "!find-skills", "!ghost-absent-xyz"], "packages": [] }' >"$SUB_HOME/.pi/agent/settings.json"
cat >"$TMP_DIR/sub-dump.txt" <<DUMP
You are a coding assistant.

The following skills provide specialized instructions for specific tasks.
<available_skills>
  <skill>
    <name>plan-loop</name>
    <location>$SUB_HOME/.pi/agent/skills/plan-loop/SKILL.md</location>
    <description>fixture</description>
  </skill>
</available_skills>
DUMP
if ! PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/sub-dump.txt" --home "$SUB_HOME" >/dev/null 2>&1; then
  fail "subset universe with union deny-list must pass (absent denies inert)"
fi

mkdir -p "$HOME_FIX/.agents/skills/deslop.bak.20240101-000000"
printf -- '---\nname: deslop\ndescription: stale backup\n---\nbody\n' \
  >"$HOME_FIX/.agents/skills/deslop.bak.20240101-000000/SKILL.md"
write_settings '"!deslop", "!find-skills"'
if PI_SKILL_LOAD_NO_REPO=1 "$CHECK" --dump "$TMP_DIR/dump-final.txt" --home "$HOME_FIX" >"$TMP_DIR/bak-out.txt" 2>&1; then
  fail "deploy backup dirs (*.bak.*) inside skill roots must fail closed (Pi loads them)"
fi
grep -q "stale skill backup" "$TMP_DIR/bak-out.txt" || fail "bak failure unexplained"
grep -q "quarantine" "$TMP_DIR/bak-out.txt" || fail "bak failure names no quarantine remedy"

NEST_HOME="$TMP_DIR/nest-home"
mkdir -p "$NEST_HOME/.pi/agent/skills/wrapper/shadow.bak.5"
printf -- '---\nname: shadowtest\ndescription: nested stale backup\n---\nbody\n' \
  >"$NEST_HOME/.pi/agent/skills/wrapper/shadow.bak.5/SKILL.md"
if "$CHECK" --home "$NEST_HOME" >"$TMP_DIR/nest-out.txt" 2>&1; then
  fail "nested backup dirs (*.bak.* at depth) must fail closed (Pi loads them)"
fi
grep -q "stale skill backup" "$TMP_DIR/nest-out.txt" || fail "nested bak failure unexplained"
grep -q "shadow.bak.5" "$TMP_DIR/nest-out.txt" || fail "nested bak path not shown"

if [ "$(id -u)" != "0" ]; then
  SCAN_HOME="$TMP_DIR/scan-home"
  mkdir -p "$SCAN_HOME/.agents/skills/locked/inner"
  chmod 000 "$SCAN_HOME/.agents/skills/locked"
  if "$CHECK" --home "$SCAN_HOME" >"$TMP_DIR/scan-out.txt" 2>&1; then
    chmod 755 "$SCAN_HOME/.agents/skills/locked"
    fail "unscannable skill root must fail closed"
  fi
  chmod 755 "$SCAN_HOME/.agents/skills/locked"
  grep -q "cannot scan" "$TMP_DIR/scan-out.txt" || fail "scan failure names no cause"
else
  printf 'SKIP scan-failure fixture: running as root\n'
fi

DANGL_HOME="$TMP_DIR/dangl-home"
mkdir -p "$DANGL_HOME/.agents"
ln -s /nonexistent-xyz "$DANGL_HOME/.agents/skills"
if "$CHECK" --home "$DANGL_HOME" >"$TMP_DIR/dangl-out.txt" 2>&1; then
  fail "dangling skill root must fail fast"
fi
grep -q "not a directory" "$TMP_DIR/dangl-out.txt" || fail "dangling root failure unexplained"

ROOTLINK_HOME="$TMP_DIR/rootlink-home"
mkdir -p "$ROOTLINK_HOME/real/deep.bak.3"
printf -- '---\nname: x\ndescription: x\n---\nbody\n' >"$ROOTLINK_HOME/real/deep.bak.3/SKILL.md"
mkdir -p "$ROOTLINK_HOME/.agents"
ln -s "$ROOTLINK_HOME/real" "$ROOTLINK_HOME/.agents/skills"
if "$CHECK" --home "$ROOTLINK_HOME" >"$TMP_DIR/rootlink-out.txt" 2>&1; then
  fail "linked skill root must still be scanned"
fi
grep -q "deep.bak.3" "$TMP_DIR/rootlink-out.txt" || fail "linked root scan missed the nested backup"

PINNED_DENY='["!adonisjs-architecture","!adonisjs-backend","!adonisjs-best-practices","!adonisjs-review","!adonisjs-testing","!adonisjs-tuyau","!brave-search","!bug-bounty","!check-compiler-errors","!code-review","!code-simplifier","!control-cli","!control-ui","!deslop","!electron-audit","!find-skills","!fix-ci","!fix-merge-conflicts","!full-output-enforcement","!get-pr-comments","!html-design-prototypes","!html-prototype","!impeccable","!loop-on-ci","!make-pr-easy-to-review","!markdown-converter","!new-branch-and-pr","!review-and-ship","!run-smoke-tests","!tanstack-start-best-practices","!ui","!verify-this","!web-audit","!weekly-review","!what-did-i-get-done","!workflow-from-chats"]'
tracked_deny="$(jq -c '[.skills[] | select(startswith("!"))] | sort' "$ROOT_DIR/pi/agent/settings.json")"
[ "$tracked_deny" = "$PINNED_DENY" ] || fail "tracked deny-list drifted: $tracked_deny"

printf '%s\n' "PASS: pi-skill-load-check fixture assertions"
