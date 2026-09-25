#!/usr/bin/env bash
# Fixtures for scripts/workflow-ref-linter: scaffold/etabli/misplaced gates.
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
LINTER="$ROOT_DIR/scripts/workflow-ref-linter"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- scaffold target: mixed root, exactly 3 failures ---
R1="$TMP_DIR/r1"
mkdir -p "$R1/docs" "$R1/scripts"
touch "$R1/scripts/real"
printf 'docs/ok.md|docs/ok.md\ndocs/exempt.md|docs/exempt.md\ndocs/bad.md|docs/bad.md\ndocs/quoted.md|docs/quoted.md\ndocs/fence.md|docs/fence.md\nscripts/real|scripts/real\n' >"$R1/files.txt"
printf 'Run `scripts/real` to deploy.\n' >"$R1/docs/ok.md"
printf 'Run `scripts/nope` here. <!-- etabli-only -->\n' >"$R1/docs/exempt.md"
printf 'Run `scripts/nope` here.\n' >"$R1/docs/bad.md"
printf 'Run `scripts/nope` here. `<!-- etabli-only -->`\n' >"$R1/docs/quoted.md"
printf '```bash\nscripts/nope --help\n`scripts/nope`\n```\n\n```bash\n`scripts/nope` <!-- etabli-only -->\n```\n' >"$R1/docs/fence.md"

OUT="$TMP_DIR/r1.out"
if "$LINTER" --target scaffold --root "$R1" --files-list "$R1/files.txt" >"$OUT" 2>"$TMP_DIR/r1.err"; then
  fail "scaffold mixed root should exit 1"
fi
[ "$(wc -l <"$OUT" | tr -d ' ')" = "3" ] || { cat "$OUT" >&2; fail "scaffold mixed root should report exactly 3 failures"; }
grep -q 'docs/bad.md:1: unresolved scaffold ref `scripts/nope`' "$OUT" || fail "bad.md failure missing"
grep -q 'docs/quoted.md:1: unresolved scaffold ref `scripts/nope`' "$OUT" || fail "quoted (spanned marker) failure missing"
grep -q 'docs/fence.md:3: unresolved scaffold ref `scripts/nope`' "$OUT" || fail "fence (no exclusion) failure missing"
grep -q 'docs/ok.md' "$OUT" && fail "ok.md must not fail"
grep -q 'docs/exempt.md' "$OUT" && fail "exempt.md must not fail"

# --- scaffold target: clean root exits 0 ---
R2="$TMP_DIR/r2"
mkdir -p "$R2/docs" "$R2/scripts"
touch "$R2/scripts/real"
printf 'docs/ok.md|docs/ok.md\ndocs/exempt.md|docs/exempt.md\nscripts/real|scripts/real\n' >"$R2/files.txt"
cp "$R1/docs/ok.md" "$R1/docs/exempt.md" "$R2/docs/"
"$LINTER" --target scaffold --root "$R2" --files-list "$R2/files.txt" >/dev/null 2>&1 \
  || fail "scaffold clean root should exit 0"

# --- scaffold target: listed doc missing under root fails closed ---
R2B="$TMP_DIR/r2b"
mkdir -p "$R2B/docs"
printf 'docs/gone.md|docs/gone.md\n' >"$R2B/files.txt"
if "$LINTER" --target scaffold --root "$R2B" --files-list "$R2B/files.txt" >"$TMP_DIR/r2b.out" 2>/dev/null; then
  fail "missing scaffold doc should exit 1"
fi
grep -q 'docs/gone.md:0: scaffold doc listed in FILES but missing' "$TMP_DIR/r2b.out" \
  || fail "missing-doc failure missing"

# --- etabli target: existence under root, markers ignored ---
R3="$TMP_DIR/r3"
mkdir -p "$R3/workflow" "$R3/scripts" "$R3/claude/scopes/shared/commands"
touch "$R3/scripts/have"
printf 'workflow/present.md|workflow/present.md\nworkflow/absent.md|workflow/absent.md\n' >"$R3/files.txt"
printf 'Run `scripts/have` now.\n' >"$R3/workflow/present.md"
printf 'Run `scripts/missing` now. <!-- etabli-only -->\n' >"$R3/workflow/absent.md"
printf 'Run `scripts/gone` now.\n' >"$R3/claude/scopes/shared/commands/demo.md"
if "$LINTER" --target etabli --root "$R3" --files-list "$R3/files.txt" >"$TMP_DIR/r3.out" 2>/dev/null; then
  fail "etabli root with missing ref should exit 1"
fi
[ "$(wc -l <"$TMP_DIR/r3.out" | tr -d ' ')" = "2" ] || { cat "$TMP_DIR/r3.out" >&2; fail "etabli should report exactly 2 failures"; }
grep -q 'workflow/absent.md:1: unresolved etabli ref `scripts/missing`' "$TMP_DIR/r3.out" \
  || fail "etabli missing-ref failure missing (markers must not exempt)"
grep -q 'claude/scopes/shared/commands/demo.md:1: unresolved etabli ref `scripts/gone`' "$TMP_DIR/r3.out" \
  || fail "etabli must scan claude/scopes/shared (union paths)"

# --- misplaced target: raw marker outside union fails, backticked passes ---
R4="$TMP_DIR/r4"
mkdir -p "$R4/docs"
printf 'docs/in.md|docs/in.md\n' >"$R4/files.txt"
printf 'In union. <!-- etabli-only -->\n' >"$R4/docs/in.md"
printf 'Outside union. <!-- etabli-only -->\n' >"$R4/docs/out.md"
printf 'Outside union but `<!-- etabli-only -->` only.\n' >"$R4/docs/quoted.md"
printf 'Outside union, non-md. <!-- etabli-only -->\n' >"$R4/docs/notes.txt"
mkdir -p "$R4/claude/scopes/shared/commands"
printf 'In union via claude dir scan. <!-- etabli-only -->\n' >"$R4/claude/scopes/shared/commands/in.md"
if "$LINTER" --target misplaced --root "$R4" --files-list "$R4/files.txt" >"$TMP_DIR/r4.out" 2>/dev/null; then
  fail "misplaced root should exit 1"
fi
[ "$(wc -l <"$TMP_DIR/r4.out" | tr -d ' ')" = "1" ] || { cat "$TMP_DIR/r4.out" >&2; fail "misplaced should report exactly 1 failure"; }
grep -q 'docs/out.md:1: misplaced etabli-only marker' "$TMP_DIR/r4.out" \
  || fail "misplaced out.md failure missing"

printf 'PASS: ref-linter smoke (scaffold/etabli/misplaced fixtures)\n'
