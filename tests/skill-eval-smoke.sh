#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/scripts/lib/hash.sh"
FIXTURES="$ROOT_DIR/tests/fixtures/skill-eval"
CONTRACT="$ROOT_DIR/workflow/skills/skill-evaluation.md"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MANIFEST_SHA="$(hash256 "$FIXTURES/manifest.json" | awk '{print $1}')"
mkdir -p "$TMP_DIR/artifact-a" "$TMP_DIR/artifact-b"
printf '%s\n' 'skill fixture' >"$TMP_DIR/artifact-a/SKILL.md"
printf '%s\n' 'skill fixture' 'candidate change' >"$TMP_DIR/artifact-b/SKILL.md"
FINGERPRINT_A="$($ROOT_DIR/scripts/skill-eval fingerprint "$TMP_DIR/artifact-a")"
FINGERPRINT_B="$($ROOT_DIR/scripts/skill-eval fingerprint "$TMP_DIR/artifact-b")"

render_result() {
  local source="$1"
  local target="$2"
  sed \
    -e "s/__MANIFEST_SHA256__/$MANIFEST_SHA/g" \
    -e "s/__BASELINE_FINGERPRINT__/$FINGERPRINT_A/g" \
    -e "s/__CANDIDATE_FINGERPRINT__/$FINGERPRINT_B/g" \
    "$source" >"$target"
}

for name in baseline candidate-accepted candidate-held-out-regression candidate-safety-regression candidate-evaluator-drift candidate-incomplete; do
  render_result "$FIXTURES/$name.json" "$TMP_DIR/$name.json"
done

"$ROOT_DIR/scripts/skill-eval" compare \
  --manifest "$FIXTURES/manifest.json" \
  --baseline "$TMP_DIR/baseline.json" \
  --candidate "$TMP_DIR/candidate-accepted.json" \
  --baseline-artifact "$TMP_DIR/artifact-a" \
  --candidate-artifact "$TMP_DIR/artifact-b" \
  --json >"$TMP_DIR/accepted.json"

jq -e '
  .status == "comparable" and
  .verdict == "accepted" and
  .visibility == "frozen_public" and
  .isolation_claim == "frozen_public_not_isolated" and
  .baseline.splits.held_in == {"passed":1,"total":2} and
  .candidate.splits.held_in == {"passed":2,"total":2} and
  (.reasons | length) == 0
' "$TMP_DIR/accepted.json" >/dev/null

if "$ROOT_DIR/scripts/skill-eval" compare --manifest "$FIXTURES/manifest.json" --baseline "$TMP_DIR/baseline.json" --candidate "$TMP_DIR/candidate-held-out-regression.json" --baseline-artifact "$TMP_DIR/artifact-a" --candidate-artifact "$TMP_DIR/artifact-b" >"$TMP_DIR/held-out.json"; then
  printf 'held-out regression should reject the candidate\n' >&2
  exit 1
else
  [ "$?" -eq 1 ] || { printf 'held-out regression should exit 1\n' >&2; exit 1; }
fi
jq -e '.status == "comparable" and .verdict == "rejected" and (.reasons | index("held_out_regression")) != null' "$TMP_DIR/held-out.json" >/dev/null

if "$ROOT_DIR/scripts/skill-eval" compare --manifest "$FIXTURES/manifest.json" --baseline "$TMP_DIR/baseline.json" --candidate "$TMP_DIR/candidate-safety-regression.json" --baseline-artifact "$TMP_DIR/artifact-a" --candidate-artifact "$TMP_DIR/artifact-b" >"$TMP_DIR/safety.json"; then
  printf 'safety regression should reject the candidate\n' >&2
  exit 1
else
  [ "$?" -eq 1 ] || { printf 'safety regression should exit 1\n' >&2; exit 1; }
fi
jq -e '(.reasons | index("safety_regression")) != null' "$TMP_DIR/safety.json" >/dev/null

for non_comparable in candidate-evaluator-drift candidate-incomplete; do
  if "$ROOT_DIR/scripts/skill-eval" compare --manifest "$FIXTURES/manifest.json" --baseline "$TMP_DIR/baseline.json" --candidate "$TMP_DIR/$non_comparable.json" --baseline-artifact "$TMP_DIR/artifact-a" --candidate-artifact "$TMP_DIR/artifact-b" >"$TMP_DIR/$non_comparable-output.json"; then
    printf '%s should be non-comparable\n' "$non_comparable" >&2
    exit 1
  else
    [ "$?" -eq 2 ] || { printf '%s should exit 2\n' "$non_comparable" >&2; exit 1; }
  fi
  jq -e '.status == "non_comparable" and .verdict == "rejected"' "$TMP_DIR/$non_comparable-output.json" >/dev/null
done

[ "$FINGERPRINT_A" != "$FINGERPRINT_B" ] || { printf 'artifact change should alter fingerprint\n' >&2; exit 1; }

sed "s/$FINGERPRINT_B/0000000000000000000000000000000000000000000000000000000000000000/" \
  "$TMP_DIR/candidate-accepted.json" >"$TMP_DIR/candidate-fingerprint-drift.json"
if "$ROOT_DIR/scripts/skill-eval" compare --manifest "$FIXTURES/manifest.json" --baseline "$TMP_DIR/baseline.json" --candidate "$TMP_DIR/candidate-fingerprint-drift.json" --baseline-artifact "$TMP_DIR/artifact-a" --candidate-artifact "$TMP_DIR/artifact-b" >"$TMP_DIR/fingerprint-drift.json"; then
  printf 'candidate artifact fingerprint drift should be non-comparable\n' >&2
  exit 1
else
  [ "$?" -eq 2 ] || { printf 'artifact fingerprint drift should exit 2\n' >&2; exit 1; }
fi
jq -e '.status == "non_comparable" and (.reasons[0] | contains("candidate artifact_fingerprint"))' "$TMP_DIR/fingerprint-drift.json" >/dev/null

ln -s "$TMP_DIR/artifact-a/SKILL.md" "$TMP_DIR/artifact-b/link.md"
if "$ROOT_DIR/scripts/skill-eval" fingerprint "$TMP_DIR/artifact-b" >/dev/null 2>&1; then
  printf 'artifact fingerprint should reject symlinks\n' >&2
  exit 1
fi

for needle in 'strictly exceed' 'not lower' 'frozen_public' 'not confidentially isolated' 'synthetic smoke proves only comparator behavior'; do
  grep -Fiq -- "$needle" "$CONTRACT" || { printf 'skill evaluation contract misses: %s\n' "$needle" >&2; exit 1; }
done

printf 'skill evaluation smoke test: ok\n'
