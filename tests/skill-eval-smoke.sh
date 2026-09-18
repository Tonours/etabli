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

# Strict manifests bind both result documents to the exact evaluator bundle.
mkdir -p "$TMP_DIR/evaluator-bundle"
printf '%s\n' 'runner-v2' >"$TMP_DIR/evaluator-bundle/runner.txt"
printf '%s\n' 'oracle-v2' >"$TMP_DIR/evaluator-bundle/oracle.txt"
RUNNER_SHA="$(hash256 "$TMP_DIR/evaluator-bundle/runner.txt" | awk '{print $1}')"
BUNDLE_SHA="$(node --input-type=module -e 'import { fingerprintEvaluatorBundle } from "./scripts/lib/evaluator-bundle.mjs"; console.log(fingerprintEvaluatorBundle(process.argv[1], ["evaluator-bundle/oracle.txt", "evaluator-bundle/runner.txt"]))' "$TMP_DIR")"
cat >"$TMP_DIR/manifest-v2.json" <<JSON
{
  "schema_version": 2,
  "strict": true,
  "manifest_id": "strict-evaluator-v2",
  "visibility": "frozen_public",
  "objective": {"kind":"quality","metric":"held_in_passed","direction":"increase","minimum_delta":1},
  "evaluator": {
    "id": "bundle-v2",
    "path": "evaluator-bundle/runner.txt",
    "sha256": "$RUNNER_SHA",
    "bundle": {
      "root": ".",
      "paths": ["evaluator-bundle/oracle.txt", "evaluator-bundle/runner.txt"],
      "sha256": "$BUNDLE_SHA"
    }
  },
  "tasks": [
    { "id": "held-in", "split": "held_in" },
    { "id": "held-out", "split": "held_out" },
    { "id": "safety", "split": "safety" }
  ]
}
JSON
V2_MANIFEST_SHA="$(hash256 "$TMP_DIR/manifest-v2.json" | awk '{print $1}')"
cat >"$TMP_DIR/baseline-v2.json" <<JSON
{"schema_version":2,"manifest_id":"strict-evaluator-v2","manifest_sha256":"$V2_MANIFEST_SHA","evaluator_sha256":"$RUNNER_SHA","evaluator_bundle_sha256":"$BUNDLE_SHA","artifact_fingerprint":"$FINGERPRINT_A","outcomes":[{"task_id":"held-in","passed":false},{"task_id":"held-out","passed":true},{"task_id":"safety","passed":true}]}
JSON
cat >"$TMP_DIR/candidate-v2.json" <<JSON
{"schema_version":2,"manifest_id":"strict-evaluator-v2","manifest_sha256":"$V2_MANIFEST_SHA","evaluator_sha256":"$RUNNER_SHA","evaluator_bundle_sha256":"$BUNDLE_SHA","artifact_fingerprint":"$FINGERPRINT_B","outcomes":[{"task_id":"held-in","passed":true},{"task_id":"held-out","passed":true},{"task_id":"safety","passed":true}]}
JSON
"$ROOT_DIR/scripts/skill-eval" compare \
  --manifest "$TMP_DIR/manifest-v2.json" \
  --baseline "$TMP_DIR/baseline-v2.json" \
  --candidate "$TMP_DIR/candidate-v2.json" \
  --baseline-artifact "$TMP_DIR/artifact-a" \
  --candidate-artifact "$TMP_DIR/artifact-b" \
  --evaluator-root "$TMP_DIR" \
  --json >"$TMP_DIR/strict-accepted.json"
jq -e --arg sha "$BUNDLE_SHA" '.schema_version == 2 and .verdict == "accepted" and .evaluator_bundle_sha256 == $sha' "$TMP_DIR/strict-accepted.json" >/dev/null
printf '%s\n' 'unbundled-evaluator' >"$TMP_DIR/evaluator-bundle/unbundled.txt"
UNBUNDLED_SHA="$(hash256 "$TMP_DIR/evaluator-bundle/unbundled.txt" | awk '{print $1}')"
jq --arg path "evaluator-bundle/unbundled.txt" --arg sha "$UNBUNDLED_SHA" \
  '.evaluator.path = $path | .evaluator.sha256 = $sha' "$TMP_DIR/manifest-v2.json" >"$TMP_DIR/manifest-v2-unbundled.json"
if "$ROOT_DIR/scripts/skill-eval" compare \
  --manifest "$TMP_DIR/manifest-v2-unbundled.json" \
  --baseline "$TMP_DIR/baseline-v2.json" \
  --candidate "$TMP_DIR/candidate-v2.json" \
  --baseline-artifact "$TMP_DIR/artifact-a" \
  --candidate-artifact "$TMP_DIR/artifact-b" \
  --evaluator-root "$TMP_DIR" >"$TMP_DIR/strict-unbundled.json"; then
  printf 'strict evaluator entry point outside bundle should be non-comparable\n' >&2
  exit 1
else
  [ "$?" -eq 2 ] || { printf 'unbundled evaluator should exit 2\n' >&2; exit 1; }
fi
jq -e '.status == "non_comparable" and (.reasons[0] | contains("evaluator.path"))' "$TMP_DIR/strict-unbundled.json" >/dev/null
printf '%s\n' 'runner-v2-mutated' >"$TMP_DIR/evaluator-bundle/runner.txt"
if "$ROOT_DIR/scripts/skill-eval" compare \
  --manifest "$TMP_DIR/manifest-v2.json" \
  --baseline "$TMP_DIR/baseline-v2.json" \
  --candidate "$TMP_DIR/candidate-v2.json" \
  --baseline-artifact "$TMP_DIR/artifact-a" \
  --candidate-artifact "$TMP_DIR/artifact-b" \
  --evaluator-root "$TMP_DIR" >"$TMP_DIR/strict-drift.json"; then
  printf 'strict evaluator bundle drift should be non-comparable\n' >&2
  exit 1
else
  [ "$?" -eq 2 ] || { printf 'strict evaluator bundle drift should exit 2\n' >&2; exit 1; }
fi
jq -e '.status == "non_comparable" and (.reasons[0] | contains("evaluator bundle"))' "$TMP_DIR/strict-drift.json" >/dev/null

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
  .baseline.splits.held_in.passed == 1 and .baseline.splits.held_in.total == 2 and
  .candidate.splits.held_in.passed == 2 and .candidate.splits.held_in.total == 2 and
  (.baseline.splits.held_in.outcomes | length) == 2 and
  (.reasons | length) == 0
' "$TMP_DIR/accepted.json" >/dev/null

# A v2 result cannot silently downgrade into the legacy v1 comparison path.
jq --arg bundle "$BUNDLE_SHA" '.schema_version = 2 | .evaluator_bundle_sha256 = $bundle' \
	"$TMP_DIR/baseline.json" >"$TMP_DIR/baseline-v2-on-v1.json"
jq --arg bundle "$BUNDLE_SHA" '.schema_version = 2 | .evaluator_bundle_sha256 = $bundle' \
	"$TMP_DIR/candidate-accepted.json" >"$TMP_DIR/candidate-v2-on-v1.json"
if "$ROOT_DIR/scripts/skill-eval" compare --manifest "$FIXTURES/manifest.json" --baseline "$TMP_DIR/baseline-v2-on-v1.json" --candidate "$TMP_DIR/candidate-v2-on-v1.json" --baseline-artifact "$TMP_DIR/artifact-a" --candidate-artifact "$TMP_DIR/artifact-b" >"$TMP_DIR/version-drift.json"; then
	printf 'v2 results must not downgrade to a v1 manifest comparison\n' >&2
	exit 1
else
	[ "$?" -eq 2 ] || { printf 'version drift should exit 2\n' >&2; exit 1; }
fi
jq -e '.status == "non_comparable" and (.reasons[0] | contains("schema_version"))' "$TMP_DIR/version-drift.json" >/dev/null

if "$ROOT_DIR/scripts/skill-eval" compare --manifest "$FIXTURES/manifest.json" --baseline "$TMP_DIR/baseline.json" --candidate "$TMP_DIR/candidate-held-out-regression.json" --baseline-artifact "$TMP_DIR/artifact-a" --candidate-artifact "$TMP_DIR/artifact-b" >"$TMP_DIR/held-out.json"; then
  printf 'held-out regression should reject the candidate\n' >&2
  exit 1
else
  [ "$?" -eq 1 ] || { printf 'held-out regression should exit 1\n' >&2; exit 1; }
fi
jq -e '.status == "comparable" and .verdict == "rejected" and (.reasons | index("held_out_regression")) != null and (.regressions.held_out | index("held-out-uncertainty")) != null' "$TMP_DIR/held-out.json" >/dev/null

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

# Per-task transition guards reject a safety swap even when its aggregate total ties.
node --input-type=module <<'NODE'
import { compareDocuments } from "./scripts/lib/skill-eval.mjs"
const manifest = {
  schema_version: 1,
  manifest_id: "transition-probe",
  visibility: "frozen_public",
  evaluator: { sha256: "a".repeat(64) },
  tasks: [
    { id: "incident", split: "held_in" },
    { id: "safe-a", split: "safety" },
    { id: "safe-b", split: "safety" },
    { id: "held-out", split: "held_out" },
  ],
}
const result = (fingerprint, passed) => ({
  schema_version: 1,
  manifest_id: "transition-probe",
  manifest_sha256: "b".repeat(64),
  evaluator_sha256: "a".repeat(64),
  artifact_fingerprint: fingerprint,
  outcomes: manifest.tasks.map((task, index) => ({ task_id: task.id, passed: passed[index] })),
})
const comparison = compareDocuments(
  manifest,
  "b".repeat(64),
  result("c".repeat(64), [false, true, false, true]),
  result("d".repeat(64), [true, false, true, true]),
)
if (comparison.verdict !== "rejected") throw new Error("safety swap was accepted")
if (!comparison.regressions.safety.includes("safe-a")) throw new Error("safety transition was not reported")
if (!comparison.reasons.includes("safety_case_regression")) throw new Error("safety transition reason missing")
const incomplete = compareDocuments(
  manifest,
  "b".repeat(64),
  result("e".repeat(64), [false, false, true, true]),
  result("f".repeat(64), [true, false, true, true]),
)
if (incomplete.verdict !== "rejected" || !incomplete.reasons.includes("baseline_safety_incomplete")) {
  throw new Error("incomplete safety baseline was accepted")
}
console.log("per-task transition guard ok")
NODE

# Strict objectives allow measured efficiency or reliability gains while every
# previously passing task remains protected.
node --input-type=module <<'NODE'
import { compareDocuments } from "./scripts/lib/skill-eval.mjs"
const sha = "a".repeat(64)
const bundle = "b".repeat(64)
const tasks = [
  { id: "in", split: "held_in" },
  { id: "out", split: "held_out" },
  { id: "safe", split: "safety" },
]
const manifest = (objective) => ({
  schema_version: 2, strict: true, manifest_id: `objective-${objective.kind}`,
  visibility: "frozen_public", objective,
  evaluator: { path: "oracle", sha256: sha, bundle: { root: ".", paths: ["oracle"], sha256: bundle } },
  tasks,
})
const result = (m, fingerprint, measurement) => ({
  schema_version: 2, manifest_id: m.manifest_id, manifest_sha256: sha,
  evaluator_sha256: sha, evaluator_bundle_sha256: bundle,
  artifact_fingerprint: fingerprint,
  outcomes: tasks.map((task) => ({ task_id: task.id, passed: true })),
  measurement,
})
for (const [objective, baselineValue, candidateValue] of [
  [{ kind: "efficiency", metric: "total_tokens", direction: "decrease", minimum_delta: 10, measurement_population: "same-runs-v1" }, 100, 80],
  [{ kind: "reliability", metric: "success_rate", direction: "increase", minimum_delta: 0.1, measurement_population: "same-runs-v1" }, 0.6, 0.8],
]) {
  const m = manifest(objective)
  const measurement = (value) => ({ population: "same-runs-v1", metric: objective.metric, value, sample_count: 5 })
  const comparison = compareDocuments(m, sha, result(m, "c".repeat(64), measurement(baselineValue)), result(m, "d".repeat(64), measurement(candidateValue)), bundle, sha)
  if (comparison.verdict !== "accepted" || comparison.objective.kind !== objective.kind) throw new Error(`${objective.kind} gain was not accepted`)
  const tied = compareDocuments(m, sha, result(m, "e".repeat(64), measurement(baselineValue)), result(m, "f".repeat(64), measurement(baselineValue)), bundle, sha)
  if (tied.verdict !== "rejected" || !tied.reasons.includes("objective_not_met")) throw new Error(`${objective.kind} tie was accepted`)
  try {
    compareDocuments(m, sha, result(m, "1".repeat(64), measurement(baselineValue)), result(m, "2".repeat(64), { ...measurement(candidateValue), population: "other-runs" }), bundle, sha)
    throw new Error(`${objective.kind} population drift was accepted`)
  } catch (error) {
    if (!String(error.message).includes("population drift")) throw error
  }
  try {
    const replacement = (value) => ({ ...measurement(value), population: "replacement-runs" })
    compareDocuments(m, sha, result(m, "3".repeat(64), replacement(baselineValue)), result(m, "4".repeat(64), replacement(candidateValue)), bundle, sha)
    throw new Error(`${objective.kind} candidate-selected population was accepted`)
  } catch (error) {
    if (!String(error.message).includes("population drift")) throw error
  }
}
try {
  compareDocuments(manifest({ kind: "efficiency", metric: "total_tokens", direction: "decrease", minimum_delta: 10 }), sha, {}, {}, bundle, sha)
  throw new Error("objective without measurement_population was accepted")
} catch (error) {
  if (!String(error.message).includes("measurement_population")) throw error
}
try {
  const bad = manifest({ kind: "speed", metric: "elapsed_ms", direction: "decrease", minimum_delta: 1 })
  compareDocuments(bad, sha, result(bad, "3".repeat(64)), result(bad, "4".repeat(64)), bundle, sha)
  throw new Error("unsupported objective was accepted")
} catch (error) {
  if (!String(error.message).includes("supported objective")) throw error
}
console.log("objective-aware comparison guard ok")
NODE

for needle in 'quality, efficiency, or reliability' 'not lower' 'frozen_public' 'not confidentially isolated' 'synthetic smoke proves only comparator behavior'; do
  grep -Fiq -- "$needle" "$CONTRACT" || { printf 'skill evaluation contract misses: %s\n' "$needle" >&2; exit 1; }
done

printf 'skill evaluation smoke test: ok\n'
