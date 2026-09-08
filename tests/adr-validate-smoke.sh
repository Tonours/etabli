#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
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
  local text="$1" needle="$2"
  case "$text" in
    *"$needle"*) ;;
    *) fail "expected output to contain '$needle', got: $text" ;;
  esac
}

write_adr() {
  local repo="$1" file="$2" body="$3"
  mkdir -p "$repo/docs/adr"
  printf '%s\n' "$body" > "$repo/docs/adr/$file"
}

repo="$TMP_DIR/no-adrs"
mkdir -p "$repo"
out="$(node "$VALIDATOR" "$repo")"
assert_contains "$out" "no docs/adr directory"

repo="$TMP_DIR/gap"
mkdir -p "$repo"
write_adr "$repo" "0001-one.md" "---
status: accepted
date: 2026-06-26
---

# One"
write_adr "$repo" "0003-three.md" "---
status: accepted
date: 2026-06-26
tags: [storage]
affected_components:
  - database
---

# Three"
out="$(node "$VALIDATOR" "$repo")"
assert_contains "$out" "next ADR-0004"

repo="$TMP_DIR/duplicate"
mkdir -p "$repo"
write_adr "$repo" "0002-a.md" "---
status: accepted
date: 2026-06-26
---

# A"
write_adr "$repo" "0002-b.md" "---
status: accepted
date: 2026-06-26
---

# B"
if node "$VALIDATOR" "$repo" >"$TMP_DIR/duplicate.out" 2>&1; then
  fail "duplicate ADR number should fail validation"
fi
assert_contains "$(cat "$TMP_DIR/duplicate.out")" "duplicate ADR number"

repo="$TMP_DIR/missing-required"
mkdir -p "$repo"
write_adr "$repo" "0001-missing.md" "# Missing metadata"
if node "$VALIDATOR" "$repo" >"$TMP_DIR/missing-required.out" 2>&1; then
  fail "missing ADR metadata should fail validation"
fi
assert_contains "$(cat "$TMP_DIR/missing-required.out")" "frontmatter status is required"
assert_contains "$(cat "$TMP_DIR/missing-required.out")" "frontmatter date is required"

repo="$TMP_DIR/self-reference"
mkdir -p "$repo"
write_adr "$repo" "0001-self.md" "---
status: accepted
date: 2026-06-26
supersedes: ADR-0001
---

# Self"
if node "$VALIDATOR" "$repo" >"$TMP_DIR/self-reference.out" 2>&1; then
  fail "self-referencing ADR should fail validation"
fi
assert_contains "$(cat "$TMP_DIR/self-reference.out")" "must not reference itself"

repo="$TMP_DIR/supersession"
mkdir -p "$repo"
write_adr "$repo" "0001-old.md" "---
status: superseded by ADR-0002
date: 2026-06-26
superseded_by: ADR-0002
---

# Old"
write_adr "$repo" "0002-new.md" "---
status: accepted
date: 2026-06-26
supersedes: ADR-0001
---

# New"
node "$VALIDATOR" "$repo" >/dev/null

repo="$TMP_DIR/broken-supersession"
mkdir -p "$repo"
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
if node "$VALIDATOR" "$repo" >"$TMP_DIR/broken.out" 2>&1; then
  fail "missing reverse supersession should fail validation"
fi
assert_contains "$(cat "$TMP_DIR/broken.out")" "does not list superseded_by"

repo="$TMP_DIR/claude-index"
mkdir -p "$repo"
cat > "$repo/CLAUDE.md" <<'EOF'
<!-- ADR:INDEX:START -->
<!-- ADR:INDEX:END -->
<!-- ADR:INDEX:START -->
<!-- ADR:INDEX:END -->
EOF
if node "$VALIDATOR" "$repo" >"$TMP_DIR/index.out" 2>&1; then
  fail "duplicate CLAUDE.md index markers should fail validation"
fi
assert_contains "$(cat "$TMP_DIR/index.out")" "ADR index blocks"

repo="$TMP_DIR/index-missing"
mkdir -p "$repo"
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
if node "$VALIDATOR" "$repo" >"$TMP_DIR/index-missing.out" 2>&1; then
  fail "index missing an on-disk ADR should fail validation"
fi
assert_contains "$(cat "$TMP_DIR/index-missing.out")" "missing 0003-three.md"

repo="$TMP_DIR/index-extra"
mkdir -p "$repo"
write_adr "$repo" "0001-one.md" "---
status: accepted
date: 2026-06-26
---

# One"
cat > "$repo/CLAUDE.md" <<'EOF'
<!-- ADR:INDEX:START -->
- [0001](docs/adr/0001-one.md) — One [accepted]
- [0002](docs/adr/0002-ghost.md) — Ghost [accepted]
<!-- ADR:INDEX:END -->
EOF
if node "$VALIDATOR" "$repo" >"$TMP_DIR/index-extra.out" 2>&1; then
  fail "index listing a missing ADR file should fail validation"
fi
assert_contains "$(cat "$TMP_DIR/index-extra.out")" "0002-ghost.md, which is not in docs/adr/"

repo="$TMP_DIR/index-complete"
mkdir -p "$repo"
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
- [0003](docs/adr/0003-three.md) — Three [accepted]
<!-- ADR:INDEX:END -->
EOF
out="$(node "$VALIDATOR" "$repo")"
assert_contains "$out" "next ADR-0004"

printf 'adr validator smoke test: ok\n'
