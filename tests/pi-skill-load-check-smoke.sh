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
    <location>PLACEHOLDER/npm/node_modules/mitsupi/skills/github/SKILL.md</location>
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

printf '%s\n' "PASS: pi-skill-load-check fixture assertions"
