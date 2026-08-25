#!/usr/bin/env bash
set -euo pipefail

# worker-recovery smoke — hermetic scratch repos, no model, no network.
# Validates the salvage contract: dirty tree -> autoresearch/recovery/<topic>-*
# branch carrying the work, clean return to main, main unchanged, gitignored
# files never committed; clean tree -> no-op; merge state -> refusal (exit 3).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HELPER="$ROOT_DIR/scripts/worker-recovery"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'worker-recovery smoke: %s\n' "$1" >&2; exit 1; }

[ -x "$HELPER" ] || fail "scripts/worker-recovery must be executable"
bash -n "$HELPER" || fail "bash -n failed"

mk_repo() {
  git init -q -b main "$TMP/$1"
  printf 'alpha\n' >"$TMP/$1/a.txt"
  printf 'ignored.txt\n' >"$TMP/$1/.gitignore"
  git -C "$TMP/$1" add -A
  git -C "$TMP/$1" -c user.email=s@s -c user.name=s commit -qm init
}

# 1. dirty tracked tree -> salvage branch, work preserved, main intact
mk_repo r1
printf 'alpha CHANGED\n' >"$TMP/r1/a.txt"
MAIN_BEFORE=$(git -C "$TMP/r1" rev-parse main)
OUT=$(cd "$TMP/r1" && WORKER_RECOVERY_ROOT="$TMP/r1" "$HELPER" R1 smoke) ||
  fail "salvage failed on dirty tree"
case "$OUT" in autoresearch/recovery/R1-*) ;; *) fail "unexpected branch name: $OUT" ;; esac
git -C "$TMP/r1" show "$OUT:a.txt" | grep -q CHANGED || fail "work not preserved on salvage branch"
[ "$(git -C "$TMP/r1" rev-parse main)" = "$MAIN_BEFORE" ] || fail "main moved"
[ -z "$(git -C "$TMP/r1" status --porcelain)" ] || fail "tree dirty after salvage"
[ "$(git -C "$TMP/r1" branch --show-current)" = main ] || fail "not back on main"

# 2. clean tree -> no-op, no branch created
mk_repo r2
OUT=$(cd "$TMP/r2" && WORKER_RECOVERY_ROOT="$TMP/r2" "$HELPER" R2 smoke) || fail "clean tree should exit 0"
[ "$OUT" = clean ] || fail "clean tree should print clean, got: $OUT"
[ -z "$(git -C "$TMP/r2" for-each-ref --format=x -- 'refs/heads/autoresearch/recovery/*' --count=1 2>/dev/null || true)" ] ||
  fail "no-op created a recovery branch"

# 3. merge in progress -> refusal
mk_repo r3
git -C "$TMP/r3" checkout -q -b side
printf 'side\n' >"$TMP/r3/a.txt"
git -C "$TMP/r3" -c user.email=s@s -c user.name=s commit -qam side
git -C "$TMP/r3" checkout -q main
printf 'main\n' >"$TMP/r3/a.txt"
git -C "$TMP/r3" -c user.email=s@s -c user.name=s commit -qam mainedit
git -C "$TMP/r3" -c user.email=s@s -c user.name=s merge --no-commit side >/dev/null 2>&1 || true
if (cd "$TMP/r3" && WORKER_RECOVERY_ROOT="$TMP/r3" "$HELPER" R3 smoke); then fail "merge state must be refused"; else
  [ "$(cd "$TMP/r3" && WORKER_RECOVERY_ROOT="$TMP/r3" "$HELPER" R3 smoke 2>/dev/null; echo $?)" = 3 ] || fail "merge refusal must exit 3"
fi

# 4. gitignored file never committed, stays on disk
mk_repo r4
printf 'alpha CHANGED\n' >"$TMP/r4/a.txt"
printf 'secret-local\n' >"$TMP/r4/ignored.txt"
OUT=$(cd "$TMP/r4" && WORKER_RECOVERY_ROOT="$TMP/r4" "$HELPER" R4 smoke)
git -C "$TMP/r4" cat-file -e "$OUT:ignored.txt" 2>/dev/null && fail "gitignored file was committed"
[ -f "$TMP/r4/ignored.txt" ] || fail "gitignored file lost from disk"

printf 'worker-recovery smoke test: ok\n'
