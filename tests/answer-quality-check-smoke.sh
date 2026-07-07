#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/good-research.md" <<'MD'
# Research

Status: verified.

Sources:
- https://example.com/source

Finding: the behavior is verified by the cited source.
MD

cat >"$TMP_DIR/bad-research.md" <<'MD'
# Research

Finding: I searched the web and this is guaranteed 10/10.
MD

cat >"$TMP_DIR/good-handoff.md" <<'MD'
# Handoff

Validation:
- command: bash tests/example.sh
- result: passed

Remaining risks: not verified against production.
MD

cat >"$TMP_DIR/bad-handoff.md" <<'MD'
# Handoff

Everything is fine.
MD

cat >"$TMP_DIR/good-repo.md" <<'MD'
# Repo Answer

Status: verified.

Evidence:
- workflow/spec.md:72
- command: git status --short
MD

cat >"$TMP_DIR/bad-repo.md" <<'MD'
# Repo Answer

Looks good from memory.
MD

cat >"$TMP_DIR/good-obvault.md" <<'MD'
# obvault Answer

Status: verified.

Read [[second-brain-operating-model]] and [[_index]]. Validation uses the vault
validator before claiming the vault is healthy.
MD

cat >"$TMP_DIR/bad-overclaim.md" <<'MD'
# Answer

This is guaranteed 10/10 and always correct.
MD

"$ROOT_DIR/scripts/answer-quality-check" --mode research "$TMP_DIR/good-research.md" >/dev/null
"$ROOT_DIR/scripts/answer-quality-check" --mode handoff "$TMP_DIR/good-handoff.md" >/dev/null
"$ROOT_DIR/scripts/answer-quality-check" --mode repo "$TMP_DIR/good-repo.md" >/dev/null
"$ROOT_DIR/scripts/answer-quality-check" --mode obvault "$TMP_DIR/good-obvault.md" >/dev/null

if "$ROOT_DIR/scripts/answer-quality-check" --mode research "$TMP_DIR/bad-research.md" >/dev/null 2>&1; then
  printf 'answer quality check should fail research without URL/status and with overclaim\n' >&2
  exit 1
fi

if "$ROOT_DIR/scripts/answer-quality-check" --mode handoff "$TMP_DIR/bad-handoff.md" >/dev/null 2>&1; then
  printf 'answer quality check should fail handoff without validation and risks\n' >&2
  exit 1
fi

if "$ROOT_DIR/scripts/answer-quality-check" --mode repo "$TMP_DIR/bad-repo.md" >/dev/null 2>&1; then
  printf 'answer quality check should fail repo answer without local evidence and label\n' >&2
  exit 1
fi

if "$ROOT_DIR/scripts/answer-quality-check" "$TMP_DIR/bad-overclaim.md" >/dev/null 2>&1; then
  printf 'answer quality check should fail unsupported overclaims\n' >&2
  exit 1
fi

printf 'answer quality check smoke test: ok\n'
