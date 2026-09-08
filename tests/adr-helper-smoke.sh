#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HELPER="$ROOT_DIR/claude/scopes/shared/skills/adr/scripts/apply-adr.mjs"
VALIDATOR="$ROOT_DIR/scripts/validate-adrs"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1" needle="$2"
  grep -Fq "$needle" "$file" || fail "expected $file to contain '$needle'"
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

write_adr() {
  local repo="$1" file="$2" body="$3"
  mkdir -p "$repo/docs/adr"
  printf '%s\n' "$body" > "$repo/docs/adr/$file"
}

snapshot_tree() {
  local repo="$1"
  (
    cd "$repo"
    while IFS= read -r file; do
      cksum "$file"
    done < <(find . -path ./.git -prune -o -type f -print | sort)
  )
}

run_helper() {
  local repo="$1" input="$2"
  node "$HELPER" --root "$repo" --input "$input"
}

assert_preexisting_failure_matches_validator() {
  local label="$1" repo="$2" needle="$3" input
  input="$TMP_DIR/$label.json"
  cat > "$input" <<'JSON'
{
  "title": "Use S3 for uploaded assets",
  "body": "We chose S3 over local disk because durability matters more than local simplicity.",
  "date": "2026-06-26"
}
JSON

  if node "$VALIDATOR" "$repo" >"$TMP_DIR/$label-validator.out" 2>&1; then
    fail "$label: validator should fail"
  fi
  assert_contains "$TMP_DIR/$label-validator.out" "$needle"

  if run_helper "$repo" "$input" >"$TMP_DIR/$label-helper.out" 2>&1; then
    fail "$label: helper should fail on pre-existing validation error"
  fi
  assert_contains "$TMP_DIR/$label-helper.out" "Existing ADR integrity failure"
  assert_contains "$TMP_DIR/$label-helper.out" "$needle"
}

command -v node >/dev/null || fail "node not on PATH"

repo="$(new_repo first)"
printf '@root instructions\n' > "$repo/AGENTS.md"
cat > "$TMP_DIR/first.json" <<'JSON'
{
  "title": "Use Postgres for the write model",
  "body": "We chose Postgres over MongoDB because transactional consistency matters more than document flexibility.",
  "date": "2026-06-26",
  "tags": ["storage"],
  "affected_components": ["database"]
}
JSON
run_helper "$repo" "$TMP_DIR/first.json" >/dev/null
[ -f "$repo/docs/adr/0001-use-postgres-for-the-write-model.md" ] || fail "first ADR was not written"
grep -q '@AGENTS.md' "$repo/CLAUDE.md" || fail "CLAUDE.md should import AGENTS.md when created"
node "$VALIDATOR" "$repo" >/dev/null

repo="$(new_repo gap)"
write_adr "$repo" "0001-one.md" "---
status: accepted
date: 2026-06-26
---

# One"
write_adr "$repo" "0003-three.md" "---
status: accepted
date: 2026-06-26
---

# Three"
cat > "$TMP_DIR/gap.json" <<'JSON'
{
  "title": "Use Redis streams for worker handoff",
  "body": "We chose Redis streams over polling because durable handoff matters more than implementation simplicity.",
  "date": "2026-06-26"
}
JSON
run_helper "$repo" "$TMP_DIR/gap.json" >/dev/null
[ -f "$repo/docs/adr/0004-use-redis-streams-for-worker-handoff.md" ] || fail "gap should yield ADR-0004"
node "$VALIDATOR" "$repo" >/dev/null

repo="$(new_repo dry-run-create)"
printf '@root instructions\n' > "$repo/AGENTS.md"
write_adr "$repo" "0001-one.md" "---
status: accepted
date: 2026-06-26
---

# One"
cat > "$TMP_DIR/dry-run-create.json" <<'JSON'
{
  "title": "Use event log for audit history",
  "body": "We chose an append-only event log over mutable audit rows because traceability matters more than update convenience.",
  "date": "2026-06-26"
}
JSON
snapshot_tree "$repo" > "$TMP_DIR/dry-run-create.before"
node "$HELPER" --root "$repo" --input "$TMP_DIR/dry-run-create.json" --dry-run > "$TMP_DIR/dry-run-create.out"
snapshot_tree "$repo" > "$TMP_DIR/dry-run-create.after"
if ! diff -u "$TMP_DIR/dry-run-create.before" "$TMP_DIR/dry-run-create.after"; then
  fail "dry-run create mutated project files"
fi
[ ! -f "$repo/docs/adr/0002-use-event-log-for-audit-history.md" ] || fail "dry-run create wrote a new ADR"
[ ! -f "$repo/CLAUDE.md" ] || fail "dry-run create wrote CLAUDE.md"
assert_contains "$TMP_DIR/dry-run-create.out" '"dry_run": true'
assert_contains "$TMP_DIR/dry-run-create.out" '"would_write": "docs/adr/0002-use-event-log-for-audit-history.md"'
assert_contains "$TMP_DIR/dry-run-create.out" '"index": "created"'

repo="$(new_repo dry-run-supersede)"
write_adr "$repo" "0001-old.md" "---
status: accepted
date: 2026-06-26
---

# Old"
cat > "$TMP_DIR/dry-run-supersede.json" <<'JSON'
{
  "title": "Use webhook push for notifications",
  "body": "We chose webhook push over polling because delivery latency matters more than scheduler simplicity.",
  "date": "2026-06-26",
  "supersedes": "ADR-0001"
}
JSON
snapshot_tree "$repo" > "$TMP_DIR/dry-run-supersede.before"
node "$HELPER" --root "$repo" --input "$TMP_DIR/dry-run-supersede.json" --dry-run > "$TMP_DIR/dry-run-supersede.out"
snapshot_tree "$repo" > "$TMP_DIR/dry-run-supersede.after"
if ! diff -u "$TMP_DIR/dry-run-supersede.before" "$TMP_DIR/dry-run-supersede.after"; then
  fail "dry-run supersede mutated project files"
fi
[ ! -f "$repo/docs/adr/0002-use-webhook-push-for-notifications.md" ] || fail "dry-run supersede wrote a new ADR"
assert_contains "$TMP_DIR/dry-run-supersede.out" '"supersedes": "ADR-0001"'
assert_contains "$TMP_DIR/dry-run-supersede.out" '"would_update_superseded": "docs/adr/0001-old.md"'

repo="$(new_repo supersede)"
write_adr "$repo" "0001-rest-polling.md" "---
status: accepted
date: 2026-06-26
tags: [integration]
affected_components: [notifications]
---

# Use REST polling for notifications

We chose REST polling instead of GraphQL subscriptions because simple infrastructure mattered more than push latency."
cat > "$TMP_DIR/supersede.json" <<'JSON'
{
  "title": "Use GraphQL subscriptions for notifications",
  "body": "We chose GraphQL subscriptions instead of REST polling because customer-visible latency now matters more than infrastructure simplicity.",
  "date": "2026-06-26",
  "supersedes": "ADR-0001",
  "tags": ["integration"],
  "affected_components": ["notifications"]
}
JSON
run_helper "$repo" "$TMP_DIR/supersede.json" >/dev/null
grep -q 'We chose REST polling instead of GraphQL subscriptions' "$repo/docs/adr/0001-rest-polling.md" || fail "old ADR body was overwritten"
grep -q 'status: superseded by ADR-0002' "$repo/docs/adr/0001-rest-polling.md" || fail "old ADR status not superseded"
grep -q 'superseded_by: ADR-0002' "$repo/docs/adr/0001-rest-polling.md" || fail "old ADR missing superseded_by"
grep -q 'supersedes: ADR-0001' "$repo/docs/adr/0002-use-graphql-subscriptions-for-notifications.md" || fail "new ADR missing supersedes"
node "$VALIDATOR" "$repo" >/dev/null

repo="$(new_repo stale-index)"
write_adr "$repo" "0001-one.md" "---
status: accepted
date: 2026-06-26
---

# One"
write_adr "$repo" "0003-three.md" "---
status: accepted
date: 2026-06-26
---

# Three"
cat > "$repo/CLAUDE.md" <<'EOF'
<!-- ADR:INDEX:START -->
- [0001](docs/adr/0001-one.md) — One [accepted]
<!-- ADR:INDEX:END -->
EOF
assert_preexisting_failure_matches_validator "stale-index" "$repo" "missing 0003-three.md"

repo="$(new_repo broken-index)"
write_adr "$repo" "0001-existing.md" "---
status: accepted
date: 2026-06-26
---

# Existing"
cat > "$repo/CLAUDE.md" <<'EOF'
<!-- ADR:INDEX:START -->
<!-- ADR:INDEX:END -->
<!-- ADR:INDEX:START -->
<!-- ADR:INDEX:END -->
EOF
cat > "$TMP_DIR/broken-index.json" <<'JSON'
{
  "title": "Use S3 for uploaded assets",
  "body": "We chose S3 over local disk because durability matters more than local simplicity.",
  "date": "2026-06-26"
}
JSON
if run_helper "$repo" "$TMP_DIR/broken-index.json" >"$TMP_DIR/broken-index.out" 2>&1; then
  fail "helper should fail on pre-existing duplicate index"
fi
if compgen -G "$repo/docs/adr/0002-*.md" > /dev/null; then
  fail "helper wrote a new ADR despite pre-existing index failure"
fi
assert_contains "$TMP_DIR/broken-index.out" "Existing ADR integrity failure"

repo="$(new_repo duplicate-number)"
write_adr "$repo" "0001-a.md" "---
status: accepted
date: 2026-06-26
---

# A"
write_adr "$repo" "0001-b.md" "---
status: accepted
date: 2026-06-26
---

# B"
assert_preexisting_failure_matches_validator "duplicate-number" "$repo" "duplicate ADR number"

repo="$(new_repo missing-required)"
write_adr "$repo" "0001-missing.md" "# Missing metadata"
assert_preexisting_failure_matches_validator "missing-required" "$repo" "frontmatter status is required"

repo="$(new_repo self-reference)"
write_adr "$repo" "0001-self.md" "---
status: accepted
date: 2026-06-26
supersedes: ADR-0001
---

# Self"
assert_preexisting_failure_matches_validator "self-reference" "$repo" "must not reference itself"

repo="$(new_repo broken-supersession)"
write_adr "$repo" "0001-old.md" "---
status: accepted
date: 2026-06-26
---

# Old"
write_adr "$repo" "0002-new.md" "---
status: accepted
date: 2026-06-26
supersedes: ADR-0001
---

# New"
assert_preexisting_failure_matches_validator "broken-supersession" "$repo" "does not list superseded_by"

repo="$(new_repo missing-supersedes-target)"
cat > "$TMP_DIR/missing-supersedes-target.json" <<'JSON'
{
  "title": "Use webhooks for notifications",
  "body": "We chose webhooks over polling because delivery latency matters more than scheduler simplicity.",
  "date": "2026-06-26",
  "supersedes": "ADR-9999"
}
JSON
if run_helper "$repo" "$TMP_DIR/missing-supersedes-target.json" >"$TMP_DIR/missing-supersedes-target.out" 2>&1; then
  fail "helper should fail when supersedes target is missing"
fi
assert_contains "$TMP_DIR/missing-supersedes-target.out" "Cannot supersede ADR-9999"
assert_contains "$TMP_DIR/missing-supersedes-target.out" "choose an existing ADR"

repo="$TMP_DIR/no-git"
mkdir -p "$repo"
cat > "$TMP_DIR/no-git.json" <<'JSON'
{
  "title": "Use SQLite for local cache",
  "body": "We chose SQLite over JSON files because queryable migrations matter more than zero-dependency storage.",
  "date": "2026-06-26"
}
JSON
run_helper "$repo" "$TMP_DIR/no-git.json" >/dev/null
[ -f "$repo/docs/adr/0001-use-sqlite-for-local-cache.md" ] || fail "helper should write ADR outside git repo"
[ ! -f "$repo/CLAUDE.md" ] || fail "helper should skip CLAUDE.md outside git repo"
node "$VALIDATOR" "$repo" >/dev/null

repo="$(new_repo copied-validator)"
write_adr "$repo" "0001-one.md" "---
status: accepted
date: 2026-06-26
---

# One"
tmp_home="$TMP_DIR/home"
mkdir -p "$tmp_home/.claude/skills/adr/scripts" "$TMP_DIR/copied-scripts"
cp "$ROOT_DIR/claude/scopes/shared/skills/adr/scripts/adr-validation.mjs" "$tmp_home/.claude/skills/adr/scripts/adr-validation.mjs"
cp "$VALIDATOR" "$TMP_DIR/copied-scripts/validate-adrs"
# Capture the real Node binary before overriding HOME. asdf/shims break when HOME
# points at a disposable tree (exit 126), which is unrelated to validator portability.
NODE_BIN="$(node -e 'process.stdout.write(process.execPath)')"
HOME="$tmp_home" "$NODE_BIN" "$TMP_DIR/copied-scripts/validate-adrs" "$repo" >/dev/null

printf 'adr helper smoke test: ok\n'
