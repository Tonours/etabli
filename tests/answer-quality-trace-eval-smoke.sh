#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/good" "$TMP_DIR/bad"

cat >"$TMP_DIR/good/trace.md" <<'MD'
# Trace — good handoff

Status: verified
Verdict: pass

## User Request

Continue the active answer-quality goal.

## Answer Under Review

The answer reported files changed, validation, remaining risks, and no commit.

## Evidence

- workflow/answer-quality.md:1
- command: scripts/answer-quality-audit --skip-obvault

## Validation

- command: scripts/answer-quality-audit --skip-obvault
- result: passed

## Quality Verdict

Pass: the handoff was evidence-backed and named remaining risk.

## Gaps / Follow-up

Live model output quality remains not verified.
MD

cat >"$TMP_DIR/bad/trace.md" <<'MD'
# Trace — bad handoff

Status: verified
Verdict: pass

## User Request

Continue the goal.

## Answer Under Review

This answer is guaranteed 10/10 and always correct.
MD

"$ROOT_DIR/scripts/answer-quality-trace-eval" "$TMP_DIR/good" >/dev/null

if "$ROOT_DIR/scripts/answer-quality-trace-eval" "$TMP_DIR/bad" >/dev/null 2>&1; then
  printf 'answer quality trace eval should fail malformed trace\n' >&2
  exit 1
fi

printf 'answer quality trace eval smoke test: ok\n'
