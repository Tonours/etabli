#!/usr/bin/env bash
# Manual end-to-end test for the /adr skill. NOT for CI.
# Requires: inherited OAuth session (no ANTHROPIC_API_KEY needed), `claude` and `jq` on PATH.
# Cost: ~1 USD per full run (3 claude -p invocations). Run on demand.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SKILL_SRC="$ROOT_DIR/claude/skills/adr"
SKILL_LINK="$HOME/.claude/skills/adr"
TMP_DIR="$(mktemp -d)"
LINK_CREATED=0

cleanup() {
  if [ "$LINK_CREATED" = "1" ]; then
    rm -f "$SKILL_LINK"
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

command -v claude >/dev/null || fail "claude not on PATH"
command -v jq >/dev/null || fail "jq not on PATH"

# Anti-stale guard: the /adr skill must be discoverable AND point at this repo.
# If a real deployment exists but resolves elsewhere, we would test the wrong skill.
ensure_skill_linked() {
  local want
  want="$(cd "$SKILL_SRC" && pwd -P)"
  if [ -e "$SKILL_LINK" ]; then
    local have
    have="$(cd "$SKILL_LINK" && pwd -P)"
    if [ "$have" = "$want" ]; then
      return 0
    fi
    fail "$SKILL_LINK exists but resolves to $have, not this repo ($want). Refusing to test a stale/foreign skill. Remove or repoint it, then re-run."
  fi
  mkdir -p "$HOME/.claude/skills"
  ln -sfn "$SKILL_SRC" "$SKILL_LINK"
  LINK_CREATED=1
}

new_repo() {
  local dir="$TMP_DIR/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.t
  git -C "$dir" config user.name t
  git -C "$dir" commit -q --allow-empty -m init
  printf '%s' "$dir"
}

# Run /adr headless in a given repo. Echoes the JSON result text on stdout.
run_adr() {
  local dir="$1" prompt="$2" budget="$3" extra="${4:-}"
  ( cd "$dir" && claude -p --output-format json --max-turns 8 --max-budget-usd "$budget" $extra "$prompt" )
}

assert_not_error() {
  local json="$1" label="$2"
  local is_error
  is_error="$(printf '%s' "$json" | jq -r '.is_error')"
  [ "$is_error" = "false" ] || fail "$label: claude -p returned is_error=$is_error (result: $(printf '%s' "$json" | jq -r '.result' | head -c 300))"
}

ensure_skill_linked

# --- Case B: a non-decision (rename) must be REFUSED, no file written ---
repo="$(new_repo refuse)"
out="$(run_adr "$repo" "/adr I just renamed a variable, nothing architectural" 0.50)"
assert_not_error "$out" "B/refuse"
if compgen -G "$repo/docs/adr/*.md" > /dev/null; then
  fail "B/refuse: an ADR file was written for a trivial rename"
fi
printf 'PASS: B — trivial rename refused, no ADR written\n'

# --- Case A: a real decision, pre-approved, must WRITE 0001 + CLAUDE.md index ---
repo="$(new_repo write)"
out="$(run_adr "$repo" "/adr We chose Postgres over Mongo for transactional consistency. Pre-approved, write directly." 1.00 "--permission-mode acceptEdits")"
assert_not_error "$out" "A/write"
compgen -G "$repo/docs/adr/0001-*.md" > /dev/null || fail "A/write: docs/adr/0001-*.md not created"
[ -f "$repo/CLAUDE.md" ] || fail "A/write: CLAUDE.md not created"
grep -q 'ADR:INDEX:START' "$repo/CLAUDE.md" || fail "A/write: CLAUDE.md missing ADR index marker"
printf 'PASS: A — decision recorded as 0001, CLAUDE.md index created\n'

# --- Case A2: a second decision -> 0002, index updated once (no duplicate block) ---
out="$(run_adr "$repo" "/adr We chose JWT over server-side sessions for stateless auth. Pre-approved, write directly." 1.00 "--permission-mode acceptEdits")"
assert_not_error "$out" "A/second"
compgen -G "$repo/docs/adr/0002-*.md" > /dev/null || fail "A/second: docs/adr/0002-*.md not created"
marker_count="$(grep -c 'ADR:INDEX:START' "$repo/CLAUDE.md")"
[ "$marker_count" = "1" ] || fail "A/second: CLAUDE.md index block duplicated ($marker_count START markers)"
printf 'PASS: A2 — second decision recorded as 0002, index updated in place\n'

printf 'adr skill e2e test: ok\n'
