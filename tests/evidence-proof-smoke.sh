#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TOOL="$ROOT_DIR/scripts/evidence-proof"
OWNED_ROOT="$(mktemp -d)"
RUN_TMP="$OWNED_ROOT/run"
CASES_DIR="$OWNED_ROOT/cases"
mkdir -p "$RUN_TMP" "$CASES_DIR"

cleanup() {
  rm -rf "$OWNED_ROOT"
}
trap cleanup EXIT

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

assert_rejected() {
  local label="$1"
  local pack="$2"
  local validation_root="${3:-$ROOT_DIR}"
  if "$TOOL" validate --pack "$pack" --root "$validation_root" >/dev/null 2>&1; then
    printf 'expected evidence pack rejection: %s\n' "$label" >&2
    exit 1
  fi
}

copy_case() {
  local name="$1"
  local destination="$CASES_DIR/$name"
  cp -R "$PACK_DIR" "$destination"
  printf '%s\n' "$destination"
}

rebind_target_pack() {
  local pack_dir="$1"
  local subject_path="$2"
  local subject_real="$3"
  local receipt_sha

  jq --arg subject_path "$subject_path" '.target.subject_path = $subject_path' "$pack_dir/pack.json" >"$pack_dir/pack.next"
  mv "$pack_dir/pack.next" "$pack_dir/pack.json"
  jq --arg subject_real "$subject_real" '.subject.path = $subject_real' "$pack_dir/receipt.json" >"$pack_dir/receipt.next"
  mv "$pack_dir/receipt.next" "$pack_dir/receipt.json"
  receipt_sha="$(sha256_file "$pack_dir/receipt.json")"
  jq --arg receipt_sha "$receipt_sha" '(.artifacts[] | select(.id == "execution-receipt").sha256) = $receipt_sha' "$pack_dir/pack.json" >"$pack_dir/pack.next"
  mv "$pack_dir/pack.next" "$pack_dir/pack.json"
}

PACK_DIR="${EVIDENCE_PROOF_DOGFOOD_DIR:-$OWNED_ROOT/pack}"
case "$PACK_DIR" in
  /*) ;;
  *) PACK_DIR="$ROOT_DIR/$PACK_DIR" ;;
esac
[ ! -e "$PACK_DIR" ] || {
  printf 'write-once dogfood output already exists: %s\n' "$PACK_DIR" >&2
  exit 1
}

MUTATING_SUBJECT="$OWNED_ROOT/mutating-subject.sh"
MUTATING_PACK="$OWNED_ROOT/mutating-pack"
printf '%s\n' '#!/bin/sh' 'printf "mutated\\n" >>"$0"' >"$MUTATING_SUBJECT"
chmod +x "$MUTATING_SUBJECT"
if "$TOOL" capture --out "$MUTATING_PACK" --cwd "$OWNED_ROOT" --subject "$MUTATING_SUBJECT" -- "$MUTATING_SUBJECT" >/dev/null 2>&1; then
  printf 'capture accepted a subject that mutated during execution\n' >&2
  exit 1
fi
[ ! -e "$MUTATING_PACK/receipt.json" ] || {
  printf 'self-mutating capture wrote a verification receipt\n' >&2
  exit 1
}

CAPTURE_JSON="$(
  "$TOOL" capture \
    --out "$PACK_DIR" \
    --cwd "$RUN_TMP" \
    --subject "$ROOT_DIR/scripts/scaffold-project" \
    --observe-tree project \
    -- "$ROOT_DIR/scripts/scaffold-project" "$RUN_TMP/project" --new
)"

jq -e '.status == "captured" and .exit == 0' <<<"$CAPTURE_JSON" >/dev/null
for expected in \
  AGENTS.md \
  CLAUDE.md \
  docs/agent-workflow.md \
  docs/agent-memory/README.md \
  docs/plan/README.md \
  docs/claude-code-workflow.md \
  docs/project-context.md; do
  jq -e --arg path "$expected" '.files | any(.path == $path and .bytes > 0 and (.sha256 | test("^[a-f0-9]{64}$")))' "$PACK_DIR/observed-tree.json" >/dev/null
done

rm -rf "$RUN_TMP"
[ ! -e "$RUN_TMP" ] || {
  printf 'owned run directory survived cleanup: %s\n' "$RUN_TMP" >&2
  exit 1
}

CAPTURED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"owned_path_removed":true,"path_sha256":"%s"}\n' "$(printf '%s' "$RUN_TMP" | shasum -a 256 | awk '{print $1}')" >"$PACK_DIR/cleanup.json"
CLEANUP_SHA="$(sha256_file "$PACK_DIR/cleanup.json")"
TARGET_REF="$(git -C "$ROOT_DIR" rev-parse HEAD)"

jq -n \
  --argjson capture "$CAPTURE_JSON" \
  --arg ref "$TARGET_REF" \
  --arg captured_at "$CAPTURED_AT" \
  --arg cleanup_sha "$CLEANUP_SHA" \
  '{
    schema_version: 1,
    run_id: "scaffold-real-product",
    mode: "product",
    target: {
      name: "etabli-scaffold-project",
      ref: $ref,
      subject_path: "scripts/scaffold-project",
      subject_sha256: $capture.subject_sha256,
      environment_sha256: $capture.environment_sha256
    },
    artifacts: ($capture.artifacts + [{
      id: "cleanup",
      path: "cleanup.json",
      sha256: $cleanup_sha,
      kind: "cleanup",
      captured_at: $captured_at
    }]),
    execution: {
      status: "parent_observed",
      receipt_artifact: "execution-receipt",
      launch: {status: "passed", evidence: ["execution-receipt"]},
      doctor: {status: "not_applicable", evidence: [], reason: "one-shot CLI has no persistent health endpoint"},
      isolation: {status: "passed", evidence: ["observed-tree"]},
      cleanup: {status: "passed", evidence: ["cleanup"]}
    },
    scenarios: [{
      id: "new-project-scaffold",
      outcome: "the new-project flow writes the documented scaffold tree",
      status: "pass",
      action_evidence: ["execution-receipt", "command-stdout"],
      result_evidence: ["observed-tree"],
      side_effect_expected: true,
      side_effect_evidence: ["observed-tree"]
    }]
  }' >"$PACK_DIR/pack.json"

BASE_RESULT="$("$TOOL" validate --pack "$PACK_DIR/pack.json" --root "$ROOT_DIR" --assert)"
jq -e '.validation == "valid" and .integrity == "integrity_valid" and .verdict == "VERIFIED" and .execution == "parent_observed_execution"' <<<"$BASE_RESULT" >/dev/null

# Revalidate after the observed run directory is gone: the write-once capture is
# self-contained and cleanup evidence is part of the pack.
"$TOOL" validate --pack "$PACK_DIR/pack.json" --root "$ROOT_DIR" --assert >/dev/null

TARGET_ROOT="$OWNED_ROOT/target-root"
mkdir -p "$TARGET_ROOT/inside" "$OWNED_ROOT/target-outside"
cp "$ROOT_DIR/scripts/scaffold-project" "$TARGET_ROOT/inside/scaffold-project"
cp "$ROOT_DIR/scripts/scaffold-project" "$OWNED_ROOT/target-outside/scaffold-project"

IN_ROOT_ANCESTOR_CASE="$(copy_case target-in-root-symlink-ancestor)"
ln -s inside "$TARGET_ROOT/alias"
rebind_target_pack \
  "$IN_ROOT_ANCESTOR_CASE" \
  "alias/scaffold-project" \
  "$(realpath "$TARGET_ROOT/inside/scaffold-project")"
"$TOOL" validate --pack "$IN_ROOT_ANCESTOR_CASE/pack.json" --root "$TARGET_ROOT" --assert >/dev/null

TERMINAL_SYMLINK_CASE="$(copy_case target-terminal-symlink)"
ln -s inside/scaffold-project "$TARGET_ROOT/subject-link"
rebind_target_pack \
  "$TERMINAL_SYMLINK_CASE" \
  "subject-link" \
  "$(realpath "$TARGET_ROOT/inside/scaffold-project")"
assert_rejected target-terminal-symlink "$TERMINAL_SYMLINK_CASE/pack.json" "$TARGET_ROOT"

ESCAPING_ANCESTOR_CASE="$(copy_case target-escaping-symlink-ancestor)"
ln -s "$OWNED_ROOT/target-outside" "$TARGET_ROOT/escape"
rebind_target_pack \
  "$ESCAPING_ANCESTOR_CASE" \
  "escape/scaffold-project" \
  "$(realpath "$OWNED_ROOT/target-outside/scaffold-project")"
assert_rejected target-escaping-symlink-ancestor "$ESCAPING_ANCESTOR_CASE/pack.json" "$TARGET_ROOT"

OBSERVE_ROOT="$OWNED_ROOT/observe-root"
mkdir -p "$OBSERVE_ROOT/inside/tree" "$OWNED_ROOT/observe-outside/tree"
printf 'inside\n' >"$OBSERVE_ROOT/inside/tree/result.txt"
printf 'outside\n' >"$OWNED_ROOT/observe-outside/tree/result.txt"
ln -s inside "$OBSERVE_ROOT/alias"
ln -s "$OWNED_ROOT/observe-outside" "$OBSERVE_ROOT/escape"

IN_ROOT_OBSERVE_JSON="$(
  "$TOOL" capture \
    --out "$OWNED_ROOT/observe-in-root-pack" \
    --cwd "$OBSERVE_ROOT" \
    --subject "$ROOT_DIR/scripts/evidence-proof" \
    --observe-tree alias/tree \
    -- /bin/echo observed
)"
jq -e '.status == "captured" and .exit == 0' <<<"$IN_ROOT_OBSERVE_JSON" >/dev/null

if "$TOOL" capture \
  --out "$OWNED_ROOT/observe-escaping-pack" \
  --cwd "$OBSERVE_ROOT" \
  --subject "$ROOT_DIR/scripts/evidence-proof" \
  --observe-tree escape/tree \
  -- /bin/echo observed >/dev/null 2>&1; then
  printf 'capture accepted an observed tree escaping --cwd through a symlink ancestor\n' >&2
  exit 1
fi

EXTERNAL_CAPTURE_CWD="$OWNED_ROOT/external-capture-cwd"
EXTERNAL_SUBJECT_DIR="$OWNED_ROOT/external-subject"
EXTERNAL_PREDECLARED_DIR="$OWNED_ROOT/external-predeclared"
mkdir -p "$EXTERNAL_CAPTURE_CWD" "$EXTERNAL_SUBJECT_DIR" "$EXTERNAL_PREDECLARED_DIR"
EXTERNAL_SUBJECT="$EXTERNAL_SUBJECT_DIR/subject.sh"
EXTERNAL_PREDECLARED="$EXTERNAL_PREDECLARED_DIR/declaration.json"
printf '%s\n' '#!/bin/sh' 'printf "external inputs accepted\\n"' >"$EXTERNAL_SUBJECT"
chmod +x "$EXTERNAL_SUBJECT"
printf '%s\n' '{"fixture":true}' >"$EXTERNAL_PREDECLARED"
EXTERNAL_INPUT_CAPTURE_JSON="$(
  "$TOOL" capture \
    --out "$OWNED_ROOT/external-input-pack" \
    --cwd "$EXTERNAL_CAPTURE_CWD" \
    --subject "$EXTERNAL_SUBJECT" \
    --predeclared "$EXTERNAL_PREDECLARED" \
    -- "$EXTERNAL_SUBJECT"
)"
jq -e '
  .status == "captured" and
  .exit == 0 and
  (.artifacts | any(.id == "predeclared-input"))
' <<<"$EXTERNAL_INPUT_CAPTURE_JSON" >/dev/null

HASH_CASE="$(copy_case hash-mismatch)"
jq '.artifacts[0].sha256 = ("0" * 64)' "$HASH_CASE/pack.json" >"$HASH_CASE/pack.next"
mv "$HASH_CASE/pack.next" "$HASH_CASE/pack.json"
assert_rejected hash-mismatch "$HASH_CASE/pack.json"

EMPTY_CASE="$(copy_case empty-artifact)"
: >"$EMPTY_CASE/observed-tree.json"
EMPTY_SHA="$(sha256_file "$EMPTY_CASE/observed-tree.json")"
jq --arg sha "$EMPTY_SHA" '(.artifacts[] | select(.id == "observed-tree").sha256) = $sha' "$EMPTY_CASE/pack.json" >"$EMPTY_CASE/pack.next"
mv "$EMPTY_CASE/pack.next" "$EMPTY_CASE/pack.json"
assert_rejected empty-artifact "$EMPTY_CASE/pack.json"

SYMLINK_CASE="$(copy_case symlink-artifact)"
rm "$SYMLINK_CASE/observed-tree.json"
ln -s receipt.json "$SYMLINK_CASE/observed-tree.json"
assert_rejected symlink-artifact "$SYMLINK_CASE/pack.json"

OUTSIDE_CASE="$(copy_case outside-artifact)"
printf 'outside\n' >"$CASES_DIR/outside.txt"
OUTSIDE_SHA="$(sha256_file "$CASES_DIR/outside.txt")"
jq --arg sha "$OUTSIDE_SHA" '(.artifacts[] | select(.id == "observed-tree")) |= (.path = "../outside.txt" | .sha256 = $sha)' "$OUTSIDE_CASE/pack.json" >"$OUTSIDE_CASE/pack.next"
mv "$OUTSIDE_CASE/pack.next" "$OUTSIDE_CASE/pack.json"
assert_rejected outside-artifact "$OUTSIDE_CASE/pack.json"

STALE_CASE="$(copy_case stale-target)"
jq '.target.subject_sha256 = ("0" * 64)' "$STALE_CASE/pack.json" >"$STALE_CASE/pack.next"
mv "$STALE_CASE/pack.next" "$STALE_CASE/pack.json"
assert_rejected stale-target "$STALE_CASE/pack.json"

MISSING_CASE="$(copy_case missing-evidence)"
rm "$MISSING_CASE/cleanup.json"
assert_rejected missing-evidence "$MISSING_CASE/pack.json"

BLOCKED_PASS_CASE="$(copy_case blocked-presented-as-pass)"
jq '.scenarios[0].action_evidence = []' "$BLOCKED_PASS_CASE/pack.json" >"$BLOCKED_PASS_CASE/pack.next"
mv "$BLOCKED_PASS_CASE/pack.next" "$BLOCKED_PASS_CASE/pack.json"
assert_rejected blocked-presented-as-pass "$BLOCKED_PASS_CASE/pack.json"

INJECTION_CASE="$(copy_case command-from-pack)"
MARKER="$OWNED_ROOT/untrusted-command-ran"
jq --arg marker "$MARKER" '.command = ["sh", "-c", ("touch " + $marker)]' "$INJECTION_CASE/pack.json" >"$INJECTION_CASE/pack.next"
mv "$INJECTION_CASE/pack.next" "$INJECTION_CASE/pack.json"
assert_rejected command-from-pack "$INJECTION_CASE/pack.json"
[ ! -e "$MARKER" ] || {
  printf 'validator executed untrusted pack content\n' >&2
  exit 1
}

UI_CASE="$(copy_case ui-proxy)"
printf 'deterministic UI proxy artifact\n' >"$UI_CASE/screenshot.bin"
printf 'proxy accessibility result\n' >"$UI_CASE/accessibility.txt"
printf 'proxy console result\n' >"$UI_CASE/console.txt"
printf 'proxy network result\n' >"$UI_CASE/network.txt"
UI_SHA="$(sha256_file "$UI_CASE/screenshot.bin")"
UI_ACCESSIBILITY_SHA="$(sha256_file "$UI_CASE/accessibility.txt")"
UI_CONSOLE_SHA="$(sha256_file "$UI_CASE/console.txt")"
UI_NETWORK_SHA="$(sha256_file "$UI_CASE/network.txt")"
jq --arg sha "$UI_SHA" --arg accessibility_sha "$UI_ACCESSIBILITY_SHA" --arg console_sha "$UI_CONSOLE_SHA" --arg network_sha "$UI_NETWORK_SHA" --arg captured_at "$CAPTURED_AT" '
  .mode = "ui"
  | .artifacts += [
      {id:"ui-screenshot",path:"screenshot.bin",sha256:$sha,kind:"screenshot",captured_at:$captured_at},
      {id:"ui-accessibility",path:"accessibility.txt",sha256:$accessibility_sha,kind:"accessibility",captured_at:$captured_at},
      {id:"ui-console",path:"console.txt",sha256:$console_sha,kind:"console",captured_at:$captured_at},
      {id:"ui-network",path:"network.txt",sha256:$network_sha,kind:"network",captured_at:$captured_at}
    ]
  | .execution = {
      status:"integrity_only",receipt_artifact:null,
      launch:{status:"not_applicable",evidence:[],reason:"proxy fixture"},
      doctor:{status:"not_applicable",evidence:[],reason:"proxy fixture"},
      isolation:{status:"not_applicable",evidence:[],reason:"proxy fixture"},
      cleanup:{status:"not_applicable",evidence:[],reason:"proxy fixture"}
    }
  | .scenarios = [{id:"layout",outcome:"proxy layout",status:"pass",action_evidence:["ui-screenshot"],result_evidence:["ui-screenshot"],side_effect_expected:false,side_effect_evidence:[]}]
  | .ui = {
      responsive_in_scope:true,motion_in_scope:false,reference_in_scope:false,
      viewports:[
        {label:"narrow",width:375,height:812,evidence:["ui-screenshot"]},
        {label:"desktop",width:1280,height:800,evidence:["ui-screenshot"]}
      ],
      checks:{
        keyboard:{status:"passed",evidence:["ui-screenshot"]},
        focus:{status:"passed",evidence:["ui-screenshot"]},
        accessibility:{status:"passed",evidence:["ui-accessibility"]},
        console:{status:"passed",evidence:["ui-console"]},
        network:{status:"passed",evidence:["ui-network"]},
        responsive:{status:"passed",evidence:["ui-screenshot"]},
        reduced_motion:{status:"not_applicable",evidence:[],reason:"motion out of scope"},
        reference:{status:"not_applicable",evidence:[],reason:"reference out of scope"}
      }
    }
  ' "$UI_CASE/pack.json" >"$UI_CASE/pack.next"
mv "$UI_CASE/pack.next" "$UI_CASE/pack.json"
UI_RESULT="$("$TOOL" validate --pack "$UI_CASE/pack.json" --root "$ROOT_DIR")"
jq -e '.verdict == "INCONCLUSIVE" and .execution == "proxy_supported"' <<<"$UI_RESULT" >/dev/null

UI_REFERENCE_CASE="$(copy_case ui-reference-in-scope)"
cp "$UI_CASE/screenshot.bin" "$UI_REFERENCE_CASE/screenshot.bin"
cp "$UI_CASE/accessibility.txt" "$UI_REFERENCE_CASE/accessibility.txt"
cp "$UI_CASE/console.txt" "$UI_REFERENCE_CASE/console.txt"
cp "$UI_CASE/network.txt" "$UI_REFERENCE_CASE/network.txt"
cp "$UI_CASE/pack.json" "$UI_REFERENCE_CASE/pack.json"
jq '.ui.reference_in_scope = true | .ui.checks.reference = {status:"passed",evidence:["ui-screenshot"]}' \
  "$UI_REFERENCE_CASE/pack.json" >"$UI_REFERENCE_CASE/pack.next"
mv "$UI_REFERENCE_CASE/pack.next" "$UI_REFERENCE_CASE/pack.json"
UI_REFERENCE_RESULT="$("$TOOL" validate --pack "$UI_REFERENCE_CASE/pack.json" --root "$ROOT_DIR")"
jq -e '.verdict == "INCONCLUSIVE" and .execution == "proxy_supported"' <<<"$UI_REFERENCE_RESULT" >/dev/null
jq '.ui.checks.reference.status = "not_applicable" | .ui.checks.reference.reason = "missing"' \
  "$UI_REFERENCE_CASE/pack.json" >"$UI_REFERENCE_CASE/pack.next"
mv "$UI_REFERENCE_CASE/pack.next" "$UI_REFERENCE_CASE/pack.json"
assert_rejected ui-reference-in-scope-without-pass "$UI_REFERENCE_CASE/pack.json"

UI_NARROW_ONLY_CASE="$(copy_case ui-missing-desktop)"
cp "$UI_CASE/screenshot.bin" "$UI_NARROW_ONLY_CASE/screenshot.bin"
cp "$UI_CASE/accessibility.txt" "$UI_NARROW_ONLY_CASE/accessibility.txt"
cp "$UI_CASE/console.txt" "$UI_NARROW_ONLY_CASE/console.txt"
cp "$UI_CASE/network.txt" "$UI_NARROW_ONLY_CASE/network.txt"
cp "$UI_CASE/pack.json" "$UI_NARROW_ONLY_CASE/pack.json"
jq '.ui.viewports |= map(select(.width < 1024))' "$UI_NARROW_ONLY_CASE/pack.json" >"$UI_NARROW_ONLY_CASE/pack.next"
mv "$UI_NARROW_ONLY_CASE/pack.next" "$UI_NARROW_ONLY_CASE/pack.json"
assert_rejected ui-missing-desktop "$UI_NARROW_ONLY_CASE/pack.json"

INVESTIGATION_CASE="$(copy_case investigation-confirmed)"
jq '
  .mode = "investigation"
  | del(.scenarios)
  | .investigation = {
      question:"Does the scaffold command create the documented tree?",
      reproduction:{status:"reproduced",evidence:["observed-tree"]},
      hypotheses:[
        {id:"command",mechanism:"the scaffold command writes the tree",falsifier:"the tree remains absent after the command",status:"supported",evidence:["observed-tree"]},
        {id:"fixture",mechanism:"a pre-existing fixture created the tree",falsifier:"the isolated directory starts empty",status:"rejected",evidence:["execution-receipt"]},
        {id:"manual",mechanism:"a manual write created the tree",falsifier:"the parent-observed command accounts for the write",status:"rejected",evidence:["command-stdout"]}
      ],
      intervention:{kind:"failing_passing_pair",mechanism_id:"command",predicted_change:"running the command creates the tree",observed_change:"empty baseline became the hashed tree",baseline_evidence:["command-stdout"],treatment_evidence:["observed-tree"]},
      verdict:"CAUSE_CONFIRMED",
      conclusion:"The isolated parent-observed command caused the documented tree."
    }
  ' "$INVESTIGATION_CASE/pack.json" >"$INVESTIGATION_CASE/pack.next"
mv "$INVESTIGATION_CASE/pack.next" "$INVESTIGATION_CASE/pack.json"
INVESTIGATION_RESULT="$("$TOOL" validate --pack "$INVESTIGATION_CASE/pack.json" --root "$ROOT_DIR" --assert)"
jq -e '.verdict == "VERIFIED" and .investigation_verdict == "CAUSE_CONFIRMED"' <<<"$INVESTIGATION_RESULT" >/dev/null

NO_INTERVENTION_CASE="$(copy_case investigation-no-intervention)"
cp "$INVESTIGATION_CASE/pack.json" "$NO_INTERVENTION_CASE/pack.json"
jq '.investigation.intervention = null' "$NO_INTERVENTION_CASE/pack.json" >"$NO_INTERVENTION_CASE/pack.next"
mv "$NO_INTERVENTION_CASE/pack.next" "$NO_INTERVENTION_CASE/pack.json"
assert_rejected confirmed-without-intervention "$NO_INTERVENTION_CASE/pack.json"

SUPPORTED_CASE="$(copy_case investigation-supported)"
cp "$NO_INTERVENTION_CASE/pack.json" "$SUPPORTED_CASE/pack.json"
jq '.investigation.verdict = "CAUSE_SUPPORTED"' "$SUPPORTED_CASE/pack.json" >"$SUPPORTED_CASE/pack.next"
mv "$SUPPORTED_CASE/pack.next" "$SUPPORTED_CASE/pack.json"
SUPPORTED_RESULT="$("$TOOL" validate --pack "$SUPPORTED_CASE/pack.json" --root "$ROOT_DIR")"
jq -e '.verdict == "INCONCLUSIVE" and .investigation_verdict == "CAUSE_SUPPORTED"' <<<"$SUPPORTED_RESULT" >/dev/null

NOT_REPRODUCED_CASE="$(copy_case investigation-not-reproduced)"
cp "$SUPPORTED_CASE/pack.json" "$NOT_REPRODUCED_CASE/pack.json"
jq '.investigation.reproduction.status = "not_reproduced" | .investigation.verdict = "NOT_REPRODUCED"' \
  "$NOT_REPRODUCED_CASE/pack.json" >"$NOT_REPRODUCED_CASE/pack.next"
mv "$NOT_REPRODUCED_CASE/pack.next" "$NOT_REPRODUCED_CASE/pack.json"
NOT_REPRODUCED_RESULT="$("$TOOL" validate --pack "$NOT_REPRODUCED_CASE/pack.json" --root "$ROOT_DIR")"
jq -e '.verdict == "NOT_VERIFIED" and .investigation_verdict == "NOT_REPRODUCED"' <<<"$NOT_REPRODUCED_RESULT" >/dev/null

PERF_WORK="$OWNED_ROOT/performance-work"
PERFORMANCE_CASE="$CASES_DIR/performance"
mkdir -p "$PERF_WORK"
printf '%s\n' \
  '#!/usr/bin/env node' \
  'import { createHash } from "node:crypto";' \
  'import { readFileSync } from "node:fs";' \
  'const canonical = (value) => Array.isArray(value) ? `[${value.map(canonical).join(",")}]` : value && typeof value === "object" ? `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(",")}}` : JSON.stringify(value);' \
  'const declarationBytes = readFileSync("declaration.json");' \
  'const declaration = JSON.parse(declarationBytes);' \
  'const sha = (value) => createHash("sha256").update(value).digest("hex");' \
  'const firstWarmupAt = new Date().toISOString();' \
  'const baseline = Array.from({ length: 20 }, (_, index) => index + 100);' \
  'const candidate = Array.from({ length: 20 }, (_, index) => index + 80);' \
  'const design = { order: declaration.design.order, seed: declaration.design.seed, outlier_policy: declaration.design.outlier_policy, warmups: declaration.design.warmups };' \
  'const bindings = Object.fromEntries(["baseline", "candidate"].map((arm) => [arm, { command_sha256: sha(canonical(declaration[arm].command)), subject_sha256: declaration[arm].subject_sha256, fixture_sha256: declaration[arm].fixture_sha256 }]));' \
  'process.stdout.write(`${JSON.stringify({ schema_version: 1, declaration_sha256: sha(declarationBytes), first_warmup_at: firstWarmupAt, design, bindings, baseline, candidate })}\n`);' \
  >"$PERF_WORK/runner.mjs"
chmod +x "$PERF_WORK/runner.mjs"
SUBJECT_SHA="$(sha256_file "$PERF_WORK/runner.mjs")"
RUNNER_COMMAND="$(jq -nc --arg runner "$PERF_WORK/runner.mjs" '[$runner]')"
jq -n --arg subject "$SUBJECT_SHA" --argjson runner "$RUNNER_COMMAND" '{
  schema_version:1,
  metric:{name:"elapsed",unit:"milliseconds",direction:"lower",minimum_improvement_pct:10,maximum_observed_p95_regression_pct:5,tail_gate:true,quantile:"nearest-rank-observed-p95"},
  design:{order:"interleaved",seed:"fixed-seed",outlier_policy:"none",warmups:{baseline:2,candidate:2},runner_command:$runner},
  baseline:{command:["baseline"],subject_sha256:$subject,fixture_sha256:("a" * 64)},
  candidate:{command:["candidate"],subject_sha256:$subject,fixture_sha256:("a" * 64)}
}' >"$PERF_WORK/declaration.json"
PERF_CAPTURE_JSON="$(
  "$TOOL" capture \
    --out "$PERFORMANCE_CASE" \
    --cwd "$PERF_WORK" \
    --subject runner.mjs \
    --predeclared declaration.json \
    --stdout-kind benchmark_samples \
    -- "$PERF_WORK/runner.mjs"
)"
ENV_SHA="$(jq -r '.environment_sha256' <<<"$PERF_CAPTURE_JSON")"
FIRST_WARMUP_AT="$(jq -r '.first_warmup_at' "$PERFORMANCE_CASE/stdout.bin")"
jq -n --argjson capture "$PERF_CAPTURE_JSON" --arg subject "$SUBJECT_SHA" --arg env "$ENV_SHA" --arg first_warmup_at "$FIRST_WARMUP_AT" '{
  schema_version:1,
  run_id:"parent-observed-performance",
  mode:"performance",
  target:{name:"benchmark-runner",ref:"fixture",subject_path:"runner.mjs",subject_sha256:$subject,environment_sha256:$env},
  artifacts:$capture.artifacts,
  execution:{
    status:"parent_observed",receipt_artifact:"execution-receipt",
    launch:{status:"passed",evidence:["execution-receipt"]},
    doctor:{status:"not_applicable",evidence:[],reason:"one-shot benchmark runner"},
    isolation:{status:"not_applicable",evidence:[],reason:"temporary fixture root"},
    cleanup:{status:"not_applicable",evidence:[],reason:"owned by enclosing smoke"}
  },
  performance:{
    declaration_artifact:"predeclared-input",
    samples_artifact:"benchmark-samples",
    first_warmup_at:$first_warmup_at,
    baseline_environment_sha256:$env,
    candidate_environment_sha256:$env
  }
}' >"$PERFORMANCE_CASE/pack.json"
PERFORMANCE_RESULT="$("$TOOL" validate --pack "$PERFORMANCE_CASE/pack.json" --root "$PERF_WORK" --assert)"
jq -e '.verdict == "VERIFIED" and .samples.baseline == 20 and .samples.candidate == 20 and .baseline.observed_p95_nearest_rank == 118 and .candidate.observed_p95_nearest_rank == 98' <<<"$PERFORMANCE_RESULT" >/dev/null

INCOMPARABLE_CASE="$CASES_DIR/performance-incomparable"
cp -R "$PERFORMANCE_CASE" "$INCOMPARABLE_CASE"
jq '.performance.baseline_environment_sha256 = ("b" * 64)' "$INCOMPARABLE_CASE/pack.json" >"$INCOMPARABLE_CASE/pack.next"
mv "$INCOMPARABLE_CASE/pack.next" "$INCOMPARABLE_CASE/pack.json"
INCOMPARABLE_RESULT="$("$TOOL" validate --pack "$INCOMPARABLE_CASE/pack.json" --root "$PERF_WORK")"
jq -e '.verdict == "INCONCLUSIVE" and .comparable == false' <<<"$INCOMPARABLE_RESULT" >/dev/null

SHORT_SAMPLE_CASE="$CASES_DIR/performance-too-few-samples"
cp -R "$PERFORMANCE_CASE" "$SHORT_SAMPLE_CASE"
jq '{schema_version,declaration_sha256,first_warmup_at,design,bindings,baseline:(.baseline[0:19]),candidate:(.candidate[0:19])}' "$PERFORMANCE_CASE/stdout.bin" >"$SHORT_SAMPLE_CASE/stdout.next"
mv "$SHORT_SAMPLE_CASE/stdout.next" "$SHORT_SAMPLE_CASE/stdout.bin"
SHORT_SHA="$(sha256_file "$SHORT_SAMPLE_CASE/stdout.bin")"
SHORT_BYTES="$(wc -c <"$SHORT_SAMPLE_CASE/stdout.bin" | tr -d ' ')"
jq --arg sha "$SHORT_SHA" --argjson bytes "$SHORT_BYTES" '.stdout.sha256 = $sha | .stdout.bytes = $bytes' "$SHORT_SAMPLE_CASE/receipt.json" >"$SHORT_SAMPLE_CASE/receipt.next"
mv "$SHORT_SAMPLE_CASE/receipt.next" "$SHORT_SAMPLE_CASE/receipt.json"
SHORT_RECEIPT_SHA="$(sha256_file "$SHORT_SAMPLE_CASE/receipt.json")"
jq --arg sha "$SHORT_SHA" --arg receipt_sha "$SHORT_RECEIPT_SHA" '(.artifacts[] | select(.id == "benchmark-samples").sha256) = $sha | (.artifacts[] | select(.id == "execution-receipt").sha256) = $receipt_sha' "$SHORT_SAMPLE_CASE/pack.json" >"$SHORT_SAMPLE_CASE/pack.next"
mv "$SHORT_SAMPLE_CASE/pack.next" "$SHORT_SAMPLE_CASE/pack.json"
assert_rejected performance-too-few-samples "$SHORT_SAMPLE_CASE/pack.json" "$PERF_WORK"

LATE_DECLARATION_CASE="$CASES_DIR/performance-late-declaration"
cp -R "$PERFORMANCE_CASE" "$LATE_DECLARATION_CASE"
jq '(.artifacts[] | select(.id == "predeclared-input").captured_at) = "2999-01-01T00:00:00Z"' "$LATE_DECLARATION_CASE/pack.json" >"$LATE_DECLARATION_CASE/pack.next"
mv "$LATE_DECLARATION_CASE/pack.next" "$LATE_DECLARATION_CASE/pack.json"
assert_rejected performance-late-declaration "$LATE_DECLARATION_CASE/pack.json" "$PERF_WORK"

printf 'evidence-proof smoke: ok (%s)\n' "$PACK_DIR"
