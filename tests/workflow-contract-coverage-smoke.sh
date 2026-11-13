#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_file() {
  [ -f "$1" ] || {
    printf 'missing file: %s\n' "$1" >&2
    exit 1
  }
}

assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -Fq -- "$needle" "$path" || {
    printf 'expected %s in %s\n' "$needle" "$path" >&2
    exit 1
  }
}

# The deployment is independent of the reference scan, so it runs in the
# background while the reference index is built and asserted (its ~0.3s of
# per-file spawn overhead would otherwise dominate the smoke's wall clock).
DEPLOY_TARGET="$TMP_DIR/deployed-project"
DEPLOY_LOG="$TMP_DIR/deploy.log"
"$ROOT_DIR/scripts/deploy-workflow" "$DEPLOY_TARGET" >"$DEPLOY_LOG" 2>&1 &
DEPLOY_PID=$!

# One tree pass collects every `workflow/skills/*.md` mention (was: one
# recursive grep per contract — N walks over pi/node_modules dominated the
# core profile wall time). Vendored node_modules trees are skipped: they are
# third-party code, so a mention there must not count as a repo reference
# (this only tightens the check).
REFERENCES_INDEX="$TMP_DIR/contract-references.txt"
grep -Roh --exclude-dir=node_modules -- 'workflow/skills/[A-Za-z0-9._-]*\.md' \
  "$ROOT_DIR/claude" \
  "$ROOT_DIR/skills" \
  "$ROOT_DIR/pi" \
  "$ROOT_DIR/extras" \
  "$ROOT_DIR/README.md" \
  "$ROOT_DIR/workflow/spec.md" >"$REFERENCES_INDEX" || true
grep -Roh --exclude-dir=adr --exclude-dir=plan -- 'workflow/skills/[A-Za-z0-9._-]*\.md' \
  "$ROOT_DIR/docs" >>"$REFERENCES_INDEX" || true
sort -u "$REFERENCES_INDEX" -o "$REFERENCES_INDEX"

# The contract inventory is built once (sorted filenames); name handling uses
# parameter expansion — per-contract basename/grep forks used to cost more
# wall time than the scan itself once the deployment overlapped it.
CONTRACT_NAMES="$TMP_DIR/contract-names.txt"
EXPECTED_REFS="$TMP_DIR/expected-refs.txt"
: >"$CONTRACT_NAMES"
: >"$EXPECTED_REFS"
while IFS= read -r contract_path; do
  contract_name="${contract_path##*/}"
  printf '%s\n' "$contract_name" >>"$CONTRACT_NAMES"
  printf 'workflow/skills/%s\n' "$contract_name" >>"$EXPECTED_REFS"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' -print | sort)

# Every contract must be referenced somewhere in the managed surfaces. One
# comm over two sorted lists (was: one grep -Fxq fork per contract).
unreferenced="$(comm -23 "$EXPECTED_REFS" "$REFERENCES_INDEX")"
if [ -n "$unreferenced" ]; then
  while IFS= read -r missing; do
    printf 'unreferenced workflow contract: %s\n' "$missing" >&2
  done <<<"$unreferenced"
  exit 1
fi

if ! wait "$DEPLOY_PID"; then
  printf 'deploy-workflow failed:\n' >&2
  cat "$DEPLOY_LOG" >&2
  exit 1
fi
while IFS= read -r contract_name; do
  assert_file "$DEPLOY_TARGET/workflow/skills/$contract_name"
done <"$CONTRACT_NAMES"

# Route obligations (bounded fix, review reuse) stay stated where agents read them.
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" "**bounded fix** — a standard variant"
assert_contains "$ROOT_DIR/workflow/spec.md" "a bounded fix needs no plan but a failing"
assert_contains "$ROOT_DIR/workflow/spec.md" "returns findings and stops; host-restricted effects follow § Human checkpoints."
assert_contains "$ROOT_DIR/workflow/skills/adversary.md" "the only single-pass"
assert_contains "$ROOT_DIR/workflow/skills/review-rounds.md" "## Bounded fix"
assert_contains "$ROOT_DIR/skills/shared/plan-implement/SKILL.md" "--record-review origin/<base>"
assert_contains "$ROOT_DIR/skills/work/pr-council-review/SKILL.md" "\`reuse refused\` and runs phase A in full."
assert_contains "$ROOT_DIR/claude/README.md" "## Failure ownership"

# Thin wrappers rely on these canonical gates; removing duplication must not
# remove the obligations or each adapter's distinct delivery behavior.
for skill in implement plan-implement; do
  assert_contains "$ROOT_DIR/skills/shared/$skill/SKILL.md" 'workflow/skills/implementation-loop.md'
done
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'mutation: N survived of M'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'simplify: clean'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'quality: unavailable'
assert_contains "$ROOT_DIR/skills/shared/implement/SKILL.md" 'READY plan must cover the requested task'
assert_contains "$ROOT_DIR/skills/shared/plan-implement/SKILL.md" '## Delivery'
assert_contains "$ROOT_DIR/skills/shared/plan-implement/SKILL.md" 'No Linear ticket: open the PR'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'authority, safety gates and open findings persist.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Keep review context isolation'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Changes; current handoff in Notes / Handoff follows'
assert_contains "$ROOT_DIR/workflow/spec.md" '`workflow/skills/implementation-loop.md` § Standing rules.'
for template in PLAN_TEMPLATE.md PLAN_TEMPLATE_FULL.md; do
  for field in 'Current goal / phase:' 'Branch / SHA:' 'Proved checks / evidence paths:' 'Open findings / pending:' 'Next action / do-not-redo:'; do
    assert_contains "$ROOT_DIR/$template" "$field"
    assert_contains "$DEPLOY_TARGET/$template" "$field"
  done
done
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'prior procedures, decisions and tasks'
assert_contains "$ROOT_DIR/skills/work/pr-council-review/SKILL.md" 'If the harness files Bash output'
assert_contains "$ROOT_DIR/skills/work/pr-council-review/SKILL.md" 'If output stays inline, read phase B in that stream.'
assert_contains "$ROOT_DIR/skills/work/pr-council-review/SKILL.md" 'phase_b_output "$1"'
assert_contains "$ROOT_DIR/skills/work/pr-council-review/SKILL.md" 'Process exit zero is not approval'

assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'docs-only, config-only, or a bounded single-surface edit with no'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'runtime behavior change, outside contractual and AGENTS high-risk surfaces.'
# Editorial routing is narrow; semantic gates and in-flight escalation remain.
assert_contains "$ROOT_DIR/workflow/spec.md" 'non-semantic editorial edits on any repo'
assert_contains "$ROOT_DIR/workflow/spec.md" 'In-flight delta'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Exclude AGENTS high-risk'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'surfaces, directives, prompt/heredoc strings, smoke-pinned contract text'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'executable/assertion logic, routes, gates, obligations, schemas and locks.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Verified generated `skills-lock.json` hashes may follow editorial skill text;'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'keeping both scopes and records. Simplify **this diff only**.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Quality lens in that same pass, on the cumulative diff:'
assert_contains "$ROOT_DIR/workflow/agent-rules.md" 'operating Fleet (CLI/daemon/skill, reporting or host questions)'
assert_contains "$ROOT_DIR/workflow/agent-rules.md" 'GitHub `Tonours/fleet`. `FLEET_SESSION_ID` alone is not a trigger.'

for template in PLAN_TEMPLATE.md PLAN_TEMPLATE_FULL.md; do
  assert_contains "$ROOT_DIR/$template" 'within 400 words; link detailed evidence'
  assert_contains "$ROOT_DIR/$template" 'Owner decisions / constraints:'
  assert_contains "$ROOT_DIR/$template" 'Criteria / open safety findings:'
done
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'indispensable state may exceed the target with an explanation, never truncation.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'No automatic clear, compaction or restart.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'code before summarizing counts, failures and the artifact path.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'streams and required review tables; summaries never replace decisive evidence'
assert_contains "$ROOT_DIR/workflow/skills/investigation.md" 'results in private artifacts; surface the command, exit code, decisive excerpts'
assert_contains "$ROOT_DIR/skills/shared/plan-implement/SKILL.md" '--record-review origin/<base> <complete-round-report> <reuse-file>'
assert_contains "$ROOT_DIR/skills/work/pr-council-review/SKILL.md" 'Packaging certifies no review: verify eligibility/provenance before passing it.'

assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Delegation stays optional.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Pi keeps execution parent-only.'
assert_contains "$ROOT_DIR/skills/shared/plan-implement/SKILL.md" 'keeps the plan gate.'
assert_contains "$ROOT_DIR/skills/shared/plan-implement/SKILL.md" '--eligible-review'
assert_contains "$ROOT_DIR/skills/work/pr-council-review/SKILL.md" '--no-reuse'

printf 'workflow contract coverage smoke test: ok\n'
