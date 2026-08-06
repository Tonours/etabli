#!/usr/bin/env bash
# Manual end-to-end test for the /adr skill. NOT for CI.
# Requires: inherited OAuth session (no ANTHROPIC_API_KEY needed), `claude` and `jq` on PATH.
# Cost: several USD per full run (7 claude -p invocations). Run on demand.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SKILL_SRC="$ROOT_DIR/claude/scopes/shared/skills/adr"
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
command -v node >/dev/null || fail "node not on PATH"

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

install_validator() {
  local dir="$1"
  mkdir -p "$dir/scripts"
  cp "$ROOT_DIR/scripts/validate-adrs" "$dir/scripts/validate-adrs"
  chmod +x "$dir/scripts/validate-adrs"
}

assert_valid_adrs() {
  local dir="$1" label="$2"
  node "$dir/scripts/validate-adrs" "$dir" >/dev/null || fail "$label: ADR validator failed"
}

# Run /adr headless in a given repo. Echoes the JSON result text on stdout.
run_adr() {
  local label="$1" dir="$2" prompt="$3" budget="$4" extra="${5:-}"
  local safe_label out_file err_file code
  safe_label="$(printf '%s' "$label" | tr -c 'A-Za-z0-9_' '_')"
  out_file="$TMP_DIR/$safe_label.out"
  err_file="$TMP_DIR/$safe_label.err"

  set +e
  (
    cd "$dir" &&
      claude -p \
        --output-format json \
        --max-turns 12 \
        --max-budget-usd "$budget" \
        --add-dir "$SKILL_SRC" \
        --allowedTools=Read,Write,Edit,MultiEdit,Bash,Glob,Grep,LS \
        $extra \
        "$prompt"
  ) >"$out_file" 2>"$err_file"
  code=$?
  set -e

  if [ "$code" -ne 0 ]; then
    printf '%s\n' "FAIL: $label: claude -p exited with code $code" >&2
    printf '%s\n' "--- stdout ---" >&2
    sed -n '1,120p' "$out_file" >&2
    printf '%s\n' "--- stderr ---" >&2
    sed -n '1,120p' "$err_file" >&2
    exit 1
  fi

  cat "$out_file"
}

print_cost() {
  local json="$1" label="$2"
  local cost duration
  cost="$(printf '%s' "$json" | jq -r '.total_cost_usd // .cost_usd // "unknown"')"
  duration="$(printf '%s' "$json" | jq -r '.duration_ms // "unknown"')"
  printf '  %s cost=%s duration_ms=%s\n' "$label" "$cost" "$duration"
}

assert_not_error() {
  local json="$1" label="$2"
  local is_error
  is_error="$(printf '%s' "$json" | jq -r '.is_error')"
  [ "$is_error" = "false" ] || fail "$label: claude -p returned is_error=$is_error (result: $(printf '%s' "$json" | jq -r '.result' | head -c 300))"
}

ensure_skill_linked

printf 'ADR skill e2e coverage matrix:\n'
printf '  B  refusal gate for non-ADR changes\n'
printf '  A  first accepted ADR, AGENTS import, CLAUDE.md index creation, validator integration\n'
printf '  A2 second accepted ADR, numbering, CLAUDE.md index update in place\n'
printf '  C  numbering gap uses max(existing)+1\n'
printf '  D  explicit supersession updates bidirectional metadata\n'
printf '  E  existing ADR integrity failure blocks new writes\n'
printf '  F  existing CLAUDE.md without markers gets one appended index block\n'

# --- Case B: a non-decision (rename) must be REFUSED, no file written ---
repo="$(new_repo refuse)"
out="$(run_adr "B_refuse" "$repo" "/adr I just renamed a variable, nothing architectural" 0.75)"
assert_not_error "$out" "B/refuse"
print_cost "$out" "B"
if compgen -G "$repo/docs/adr/*.md" > /dev/null; then
  fail "B/refuse: an ADR file was written for a trivial rename"
fi
printf 'PASS: B — trivial rename refused, no ADR written\n'

# --- Case A: a real decision, pre-approved, must WRITE 0001 + CLAUDE.md index ---
repo="$(new_repo write)"
install_validator "$repo"
printf '@root instructions\n' > "$repo/AGENTS.md"
out="$(run_adr "A_write" "$repo" "/adr We chose Postgres over Mongo for transactional consistency. Pre-approved, write directly." 2.00 "--permission-mode acceptEdits")"
assert_not_error "$out" "A/write"
print_cost "$out" "A"
compgen -G "$repo/docs/adr/0001-*.md" > /dev/null || fail "A/write: docs/adr/0001-*.md not created"
[ -f "$repo/CLAUDE.md" ] || fail "A/write: CLAUDE.md not created"
grep -q '@AGENTS.md' "$repo/CLAUDE.md" || fail "A/write: CLAUDE.md should import AGENTS.md when created"
grep -q 'ADR:INDEX:START' "$repo/CLAUDE.md" || fail "A/write: CLAUDE.md missing ADR index marker"
assert_valid_adrs "$repo" "A/write"
printf 'PASS: A — decision recorded as 0001, CLAUDE.md index created\n'

# --- Case A2: a second decision -> 0002, index updated once (no duplicate block) ---
out="$(run_adr "A2_second" "$repo" "/adr We chose JWT over server-side sessions for stateless auth. Pre-approved, write directly." 1.50 "--permission-mode acceptEdits")"
assert_not_error "$out" "A/second"
print_cost "$out" "A2"
compgen -G "$repo/docs/adr/0002-*.md" > /dev/null || fail "A/second: docs/adr/0002-*.md not created"
marker_count="$(grep -c 'ADR:INDEX:START' "$repo/CLAUDE.md")"
[ "$marker_count" = "1" ] || fail "A/second: CLAUDE.md index block duplicated ($marker_count START markers)"
assert_valid_adrs "$repo" "A/second"
printf 'PASS: A2 — second decision recorded as 0002, index updated in place\n'

# --- Case C: a gap must advance from max(existing), never count(existing)+1 ---
repo="$(new_repo gap)"
install_validator "$repo"
mkdir -p "$repo/docs/adr"
cat > "$repo/docs/adr/0001-one.md" <<'ADR'
---
status: accepted
date: 2026-06-26
---

# One
ADR
cat > "$repo/docs/adr/0003-three.md" <<'ADR'
---
status: accepted
date: 2026-06-26
---

# Three
ADR
out="$(run_adr "C_gap" "$repo" "/adr We chose Redis streams over polling for durable worker handoff. Pre-approved, write directly." 1.50 "--permission-mode acceptEdits")"
assert_not_error "$out" "C/gap"
print_cost "$out" "C"
compgen -G "$repo/docs/adr/0004-*.md" > /dev/null || fail "C/gap: docs/adr/0004-*.md not created from 0001,0003 gap"
assert_valid_adrs "$repo" "C/gap"
printf 'PASS: C — gap rule used max(existing)+1 -> 0004\n'

# --- Case D: explicit supersession mutates only status/link metadata on old ADR ---
repo="$(new_repo supersede)"
install_validator "$repo"
mkdir -p "$repo/docs/adr"
cat > "$repo/docs/adr/0001-postgres.md" <<'ADR'
---
status: accepted
date: 2026-06-26
tags: [storage]
affected_components: [database]
---

# Use Postgres for the write model

We chose Postgres for relational consistency.
ADR
out="$(run_adr "D_supersede" "$repo" "/adr We are replacing ADR-0001: use DynamoDB instead of Postgres for the write model because global active-active writes now matter more than relational joins. Pre-approved, write directly." 1.75 "--permission-mode acceptEdits")"
assert_not_error "$out" "D/supersede"
print_cost "$out" "D"
compgen -G "$repo/docs/adr/0002-*.md" > /dev/null || fail "D/supersede: docs/adr/0002-*.md not created"
grep -q 'superseded by ADR-0002' "$repo/docs/adr/0001-postgres.md" || fail "D/supersede: old ADR status not superseded"
grep -q 'superseded_by: ADR-0002' "$repo/docs/adr/0001-postgres.md" || fail "D/supersede: old ADR missing superseded_by"
grep -R -q 'supersedes: ADR-0001' "$repo/docs/adr"/0002-*.md || fail "D/supersede: new ADR missing supersedes"
assert_valid_adrs "$repo" "D/supersede"
printf 'PASS: D — explicit supersession updates bidirectional metadata\n'

# --- Case E: existing ADR integrity failure must stop before writing ---
repo="$(new_repo invalid-existing)"
install_validator "$repo"
mkdir -p "$repo/docs/adr"
cat > "$repo/docs/adr/0001-a.md" <<'ADR'
---
status: accepted
date: 2026-06-26
---

# A
ADR
cat > "$repo/docs/adr/0001-b.md" <<'ADR'
---
status: accepted
date: 2026-06-26
---

# B
ADR
out="$(run_adr "E_invalid_existing" "$repo" "/adr We chose Kafka over SQS for ordered event replay. Pre-approved, write directly." 1.25 "--permission-mode acceptEdits")"
assert_not_error "$out" "E/invalid-existing"
print_cost "$out" "E"
if compgen -G "$repo/docs/adr/0002-*.md" > /dev/null; then
  fail "E/invalid-existing: wrote a new ADR even though existing ADR validation failed"
fi
printf 'PASS: E — existing ADR integrity failure blocked new writes\n'

# --- Case F: existing CLAUDE.md without markers must preserve content and append one index block ---
repo="$(new_repo existing-claude)"
install_validator "$repo"
cat > "$repo/CLAUDE.md" <<'EOF'
# Existing project instructions

Keep this content.
EOF
out="$(run_adr "F_existing_claude" "$repo" "/adr We chose signed webhooks instead of polling for external notifications. Pre-approved, write directly." 1.50 "--permission-mode acceptEdits")"
assert_not_error "$out" "F/existing-claude"
print_cost "$out" "F"
compgen -G "$repo/docs/adr/0001-*.md" > /dev/null || fail "F/existing-claude: docs/adr/0001-*.md not created"
grep -q 'Keep this content.' "$repo/CLAUDE.md" || fail "F/existing-claude: existing CLAUDE.md content was not preserved"
marker_count="$(grep -c 'ADR:INDEX:START' "$repo/CLAUDE.md")"
[ "$marker_count" = "1" ] || fail "F/existing-claude: CLAUDE.md index block count should be 1, got $marker_count"
assert_valid_adrs "$repo" "F/existing-claude"
printf 'PASS: F — existing CLAUDE.md preserved and indexed once\n'

printf 'adr skill e2e test: ok\n'
