#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
FIXTURES="$ROOT_DIR/tests/fixtures/session-handoff"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT="$TMP_DIR/project"
mkdir -p "$PROJECT/.workflow/handoff-fixture" "$PROJECT/.workflow/handoff-unresolved"
cp "$FIXTURES/handoff-plan.fixture" "$PROJECT/PLAN.md"
cp "$FIXTURES/active-run.json" "$PROJECT/.workflow/.active-run.json"
cp "$FIXTURES/events.jsonl" "$PROJECT/.workflow/handoff-fixture/events.jsonl"
cp "$FIXTURES/unresolved-events.jsonl" "$PROJECT/.workflow/handoff-unresolved/events.jsonl"

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --json >"$TMP_DIR/handoff.json"
jq -e '
  .schema_version == 1 and
  .run == "handoff-fixture" and
  (.objective | contains("cold resume")) and
  .state == "handoff event recorded" and
  .decisions == ["preserve the current validator","bound resume output"] and
  .done == ["session parser fixture","resume output fixture"] and
  .pending == ["runtime visibility fixture","full validation"] and
  .blocker == null and
  .next_action == "implement the runtime visibility fixture" and
  .do_not_redo == ["obsolete parser hypothesis"] and
  .git.available == false and
  .projection_only == true
' "$TMP_DIR/handoff.json" >/dev/null

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-unresolved --json >"$TMP_DIR/unresolved.json"
jq -e '.blocker == "privacy boundary remains open" and .validations[-1].command == "bash tests/unrelated-green.sh"' "$TMP_DIR/unresolved.json" >/dev/null

LONG_ARG="$(printf '%0500d' 0)"
jq -nc --arg command "bash tests/long-$LONG_ARG.sh" '{schema_version:2,ts:"2026-08-10T09:03:00Z",event:"validation_run",run:"handoff-unresolved",detail:{command:$command,exit:0}}' \
  >>"$PROJECT/.workflow/handoff-unresolved/events.jsonl"
"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-unresolved --json >"$TMP_DIR/bounded.json"
jq -e '.blocker == "privacy boundary remains open" and (.validations[-1].command | length) <= 240' "$TMP_DIR/bounded.json" >/dev/null

"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" >"$TMP_DIR/handoff.md"
for needle in '# Session handoff' '## Done' '## Validations' '## Blocker' '## Next action' '## Do not redo' 'implement the runtime visibility fixture' 'obsolete parser hypothesis'; do
  grep -Fq -- "$needle" "$TMP_DIR/handoff.md" || { printf 'handoff markdown misses: %s\n' "$needle" >&2; exit 1; }
done

if grep -Fiq -- 'transcript' "$TMP_DIR/handoff.json"; then
  printf 'handoff output should not reference transcript content\n' >&2
  exit 1
fi

before_hash="$(shasum -a 256 "$PROJECT/.workflow/handoff-fixture/events.jsonl" | awk '{print $1}')"
"$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run handoff-fixture >/dev/null
after_hash="$(shasum -a 256 "$PROJECT/.workflow/handoff-fixture/events.jsonl" | awk '{print $1}')"
[ "$before_hash" = "$after_hash" ] || { printf 'session handoff must not mutate the ledger\n' >&2; exit 1; }

if "$ROOT_DIR/scripts/session-handoff" --repo "$PROJECT" --run missing >/dev/null 2>&1; then
  printf 'missing explicit run should fail closed\n' >&2
  exit 1
fi

printf 'session handoff smoke test: ok\n'
