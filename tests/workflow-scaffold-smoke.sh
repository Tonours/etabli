#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/tests/lib/workflow-scaffold.sh"

NEW_PROJECT="$TMP_DIR/new-project"
"$SCRIPT" "$NEW_PROJECT" >/dev/null

HELP_OUTPUT="$TMP_DIR/deploy-workflow-help.out"
"$SCRIPT" --help >"$HELP_OUTPUT"
assert_contains "$HELP_OUTPUT" "--check"

assert_file "$NEW_PROJECT/AGENTS.md"
assert_file "$NEW_PROJECT/docs/agent-workflow.md"
assert_file "$NEW_PROJECT/docs/agent-memory/README.md"
assert_file "$NEW_PROJECT/docs/plan/README.md"
assert_file "$NEW_PROJECT/docs/claude-code-workflow.md"
assert_file "$NEW_PROJECT/docs/project-context.md"
assert_file "$NEW_PROJECT/workflow/plan-archive.md"
assert_file "$NEW_PROJECT/workflow/spec.md"
assert_file "$NEW_PROJECT/workflow/answer-quality.md"
assert_file "$NEW_PROJECT/workflow/skill-design.md"
assert_file "$NEW_PROJECT/workflow/git-contract.md"
assert_file "$NEW_PROJECT/workflow/pr-body-contract.md"
assert_file "$NEW_PROJECT/workflow/templates/escaped-defect.md"
assert_file "$NEW_PROJECT/workflow/review-rubric.md"
for retired in workflow/contract-details.md workflow/memory.md workflow/project-constraints.md workflow/evidence-pack.schema.json workflow/skills/long-loop.md; do
  assert_not_exists "$NEW_PROJECT/$retired"
done
assert_file "$NEW_PROJECT/workflow/ticket-template.md"
assert_file "$NEW_PROJECT/workflow/linear-ticket-template.md"
assert_file "$NEW_PROJECT/workflow/templates/review-logic-hunter.md"
assert_file "$NEW_PROJECT/workflow/templates/review-spec-hunter.md"
assert_file "$NEW_PROJECT/workflow/templates/review-threat-hunter.md"
assert_file "$NEW_PROJECT/workflow/templates/review-lead.md"
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "Every runner delivers the hunter template's full text in the brief"
assert_contains "$NEW_PROJECT/workflow/templates/review-lead.md" "template: inline|missing"
assert_contains "$NEW_PROJECT/workflow/templates/review-logic-hunter.md" "and last \`STATUS: complete\`"
assert_contains "$NEW_PROJECT/workflow/templates/review-threat-hunter.md" "and last \`STATUS: complete\`"
assert_contains "$NEW_PROJECT/workflow/templates/review-spec-hunter.md" "Last line: \`STATUS: complete\`"
assert_contains "$NEW_PROJECT/workflow/skills/plan-loop.md" "Record four inventories"
assert_not_exists "$NEW_PROJECT/workflow/templates/review-execution-hunter.md"
assert_not_contains "$NEW_PROJECT/workflow/templates/review-lead.md" "execution:"
assert_not_contains "$NEW_PROJECT/workflow/review-rubric.md" "Deploy state"
assert_not_contains "$NEW_PROJECT/workflow/skills/review.md" "sends request or user data out of the process"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_file "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "Mutation probe (standard, bounded fix included, and high-risk tiers, diffs touching executable"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "Resolve \`<probe>\`: workspace \`workflow/runtime/mutation-probe.mjs\`, then \`~/.pi/agent/workflow/runtime/\`, then \`~/.claude/workflow/runtime/\`."
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "- \`mutation: unavailable (<reason>)\` when the tool cannot be resolved or"
assert_contains "$NEW_PROJECT/PLAN_TEMPLATE.md" "- simplify: / quality: / mutation:"
assert_contains "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md" "- simplify: / quality: / mutation:"
assert_contains "$NEW_PROJECT/workflow/answer-quality.md" "and the \`mutation:\` record when the probe applies."
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "13b become one review per \`workflow/skills/review.md\` § Standard review"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "no plan adversary (step 5 is high-risk only)"
assert_not_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "step 13b falls back to a documented same-family"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "cross-model** (no eligible route → \`blocked\`); **standard and small skip it**."
assert_not_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "**high-risk and standard require cross-model**"
assert_not_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "fallback: double-sample with \`cross_model: unavailable (<category>)\`"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "the branch has an open PR, re-read its body against the final diff first"
assert_contains "$NEW_PROJECT/workflow/skills/adversary.md" "- **high-risk tier: cross-model required.**"
assert_contains "$NEW_PROJECT/workflow/skills/adversary.md" "high-risk → \`blocked\`; standard → one fresh labeled \`same-family\` review,"
assert_not_contains "$NEW_PROJECT/workflow/skills/adversary.md" "**high-risk and standard tiers: cross-model required.**"
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "## Standard review"
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "path in the brief. Never the parent's same-family runner while an eligible"
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "\`workflow/skills/adversary.md\` § Cross-harness frontier pool, recorded"
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "- Deadline: a Pi child runs with \`PI_REVIEW_HUNTER_TIMEOUT=1800\`, so a timeout"
assert_contains "$NEW_PROJECT/workflow/skills/review-rounds.md" "same budget, its D1 over the whole cumulative patch"
assert_contains "$NEW_PROJECT/workflow/skills/review-rounds.md" "rounds stay spent across upgrades"
assert_contains "$NEW_PROJECT/workflow/templates/review-lead.md" "claude-agent|pool-route"
assert_contains "$NEW_PROJECT/workflow/templates/plan-archive.md" "- Tier: <small|bounded-fix|standard|high-risk>; review: <self|single|full>"
assert_contains "$NEW_PROJECT/docs/plan/README.md" "- Tier: <small|bounded-fix|standard|high-risk>; review: <self|single|full>"
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "A standard run takes neither fallback: it follows § Standard review."
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "- Shape: one Logic hunter child, then Spec in the parent recorded"
assert_contains "$NEW_PROJECT/workflow/skills/review.md" "- Provenance: a pool route records the effective model from the harness's own"
assert_contains "$NEW_PROJECT/workflow/skills/review-rounds.md" "escalations met); a high finding is rejected only by the D1 reviewer, never"
assert_contains "$NEW_PROJECT/workflow/skills/review-rounds.md" "or a review due with T1 and D1 spent → high-risk: plan adversary on the"
assert_contains "$NEW_PROJECT/workflow/skills/review-rounds.md" "T2: findings → fold → next unspent D."
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "Pin once; high-risk dispatches fresh Logic and Spec hunters; standard"
assert_not_contains "$NEW_PROJECT/workflow/skills/review-rounds.md" "double-sample"
assert_not_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "double-sample"
assert_not_contains "$NEW_PROJECT/workflow/skills/adversary.md" "double-sample"
assert_not_contains "$NEW_PROJECT/workflow/skills/review.md" "double-sample"
# Every line this change added to the tier contracts stays pinned whole.
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/GLOSSARY.md" "$pin"
done <<'PINS'
The review budget of one run (`workflow/skills/review-rounds.md`): T1 and T2 are full rounds, D1 and D2 are delta rounds on the fix diff; findings after D2 block the run. A bounded fix and a standard run get T1 and D1 only (a standard D1 covers the whole cumulative patch); one counter spans tier upgrades.
**Standard review**:
The single fresh-context review of a standard run: one Logic hunter on another model family, Spec in the parent; a labeled `same-family` pass only when every eligible route is technically unavailable, recorded as `cross_model: unavailable (<category>)` (`workflow/skills/review.md`).
_Avoid_: light review, second opinion
PINS
while IFS= read -r pin; do
  assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "$pin"
done <<'PINS'
- **standard** (default) — runtime code change on a known surface. Plan and
READY gate kept, no plan adversary (step 5 is high-risk only); steps 13 and
13b become one review per `workflow/skills/review.md` § Standard review (no
code-diff adversary, `spec: parent`, labeled `same-family` fallback). Re-review
and escalation: `workflow/skills/review-rounds.md` § Bounded fix and standard.
5. High-risk: run `workflow/skills/adversary.md` before editing (standard skips it).
Pin once; high-risk dispatches fresh Logic and Spec hunters; standard
runs its single review (§ Risk tiers). When its
13b. Code-diff adversary per `workflow/skills/adversary.md`: **high-risk requires
cross-model** (no eligible route → `blocked`); **standard and small skip it**.
Single same-family pass alone → `blocked` (the labeled single review of a
bounded fix or a standard run aside). Name `adversary_model`.
**High** findings: accept/reject via cross-model, not
- adversary plan review (high-risk only);
- adversary code-diff review (high-risk: named model; standard and a bounded fix: their one review);
tier; one fresh-context review, cross-family or labeled `same-family`, for a bounded fix or standard);
PINS
while IFS= read -r pin; do
  assert_contains "$NEW_PROJECT/workflow/skills/adversary.md" "$pin"
done <<'PINS'
(`workflow/skills/review-rounds.md` T/D table): high-risk T rounds use fresh hunters plus the
plan. High-risk only, after the fresh-context review (Logic + Spec hunters, then lead):
- **high-risk tier: cross-model required.** Read-only, name
high-risk → `blocked`; standard → one fresh labeled `same-family` review,
a residual-risk line in the final report.
- **Other tiers:** small skips this pass (its self-review covers it); standard
and a bounded fix have their one fresh-context review instead, cross-family
required at standard while a route is available, preferred for a bounded fix.
A same-family one only when labeled `same-family`, never as independent:
the only single-pass same-family exception; a high finding upgrades a bounded fix to standard.
- `high`: accept/reject via a **cross-model** pass (standard: its D1
reviewer). The implementer alone must not close a high finding.
PINS
while IFS= read -r pin; do
  assert_contains "$NEW_PROJECT/workflow/spec.md" "$pin"
done <<'PINS'
their tier's review evidence (adversary at high-risk), implemented-plan archive under `docs/plan/`, and
- Review: Logic hunter then Spec hunter (standard: one cross-family Logic hunter, Spec in the parent), plus the Threat hunter on access,
Shared contracts remain authoritative; this exception changes storage, and keeps its four-axis review until its own plan changes it (ADR-0052).
work runs its tier's sequence (standard: one cross-family review, no adversary); a bounded fix needs no plan but a failing
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "$pin"
done <<'PINS'
**high-risk** requires cross-model; **small** and **standard** skip it
(standard has its one review per `workflow/skills/review.md` § Standard
review). An answer without provenance, or
fallback. The pass runs after Logic+Spec lead review; a single same-family
pass cannot replace it.
- Name `adversary_model`.
- High findings: accept/reject via cross-model (standard: its D1 reviewer),
not the implementer alone.
- Plan-mode adversary is required before high-risk implementation completion.
PINS
# Every line of review.md § Standard review, review-rounds.md § Bounded fix and standard, and the high-risk clauses of the loop, stay pinned whole.
while IFS= read -r pin; do
  assert_contains "$NEW_PROJECT/workflow/skills/review-rounds.md" "$pin"
done <<'PINS'
A bounded fix (`workflow/skills/implementation-loop.md` § Risk tiers) has a
smaller budget: its single review is T1, and blocking findings fold into one D1
by a fresh reviewer of the same kind. Still blocking after D1, or a fix that
leaves the surface → upgrade to standard with a plan, never a second T.
With no plan, record each round in the final report. A standard run has the
same budget, its D1 over the whole cumulative patch (§ Delta re-review
escalations met); a high finding is rejected only by the D1 reviewer, never
the implementer alone. Still blocking after D1, a fix on a high-risk surface,
or a review due with T1 and D1 spent → high-risk: plan adversary on the
current plan before more edits, then a full tour as the next unspent T. Spent
rounds stay spent across upgrades: a bounded fix upgraded after T1 and D1
reaches high-risk's T2, never a fresh T1.
PINS
while IFS= read -r pin; do
  assert_contains "$NEW_PROJECT/workflow/skills/review.md" "$pin"
done <<'PINS'
The single review of a standard run (`workflow/skills/implementation-loop.md`
§ Risk tiers) replaces steps 13 and 13b there; no code-diff adversary follows.
- Shape: one Logic hunter child, then Spec in the parent recorded
  `spec: parent`, plus the Threat hunter on the same route when step 5b fires.
- Route: the author-family inversion route of step 4 when one exists;
  otherwise, or after a sentinel from it, the next non-author route of
  `workflow/skills/adversary.md` § Cross-harness frontier pool, recorded
  `runner: pool-route`: that route's own read-only command (Codex:
  `codex exec --sandbox read-only --model <model>`) with the full hunter
  template, the `Axis:`, Intent and `Standards:` lines and the pinned patch
  path in the brief. Never the parent's same-family runner while an eligible
  route is untried.
- Deadline: a Pi child runs with `PI_REVIEW_HUNTER_TIMEOUT=1800`, so a timeout
  meets the technical-unavailability bar of `workflow/skills/adversary.md`
  § Code diff mode.
- Provenance: a pool route records the effective model from the harness's own
  record; a pool-route answer without effective-model provenance, or any
  truncated answer, is rerun once, then `blocked`. A Pi child's requested
  `--model` id is its provenance (`hunter_model:`; `pi --mode text` prints no
  effective model).
- Every eligible route technically unavailable → one fresh same-family Logic
  hunter labeled `same-family`, recorded `cross_model: unavailable
  (<category>)`, with a residual-risk line in the final report.
- Re-review: `workflow/skills/review-rounds.md` § Bounded fix and standard.
PINS
while IFS= read -r pin; do
  assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "$pin"
done <<'PINS'
  mandatory (13b), both hunters mandatory (13).
5. High-risk: run `workflow/skills/adversary.md` before editing (standard skips it).
- adversary plan review (high-risk only);
- adversary code-diff review (high-risk: named model; standard and a bounded fix: their one review);
PINS
assert_contains "$NEW_PROJECT/workflow/skills/adversary.md" "minutes fixed before launch and never shortened"
assert_contains "$NEW_PROJECT/workflow/skills/adversary.md" "recorded as \`cross_model: unavailable (<category>)\` with"
assert_contains "$NEW_PROJECT/workflow/skills/adversary.md" "plan mode: re-open each cited Observed Fact"
assert_contains "$NEW_PROJECT/workflow/skills/adversary.md" "short: rerun once; still unproven or truncated → \`blocked\`, never a"
assert_contains "$NEW_PROJECT/workflow/skills/adversary.md" "Keep each attempt's route, command, deadline, duration and result in"
assert_contains "$ROOT_DIR/GLOSSARY.md" "**Standard review**:"
assert_contains "$ROOT_DIR/GLOSSARY.md" "A bounded fix and a standard run get T1 and D1 only"
assert_not_contains "$ROOT_DIR/GLOSSARY.md" "the standard-tier fallback when every eligible cross-model route is technically unavailable"
assert_not_contains "$ROOT_DIR/GLOSSARY.md" "accepted for the standard tier instead of a cross-model pass"
assert_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "**high-risk** requires cross-model; **small** and **standard** skip it"
assert_not_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "**small** skips it; **standard** and **high-risk** require cross-model."
assert_not_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "Plan-mode adversary is required before autonomous implementation completion."
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/AGENTS.md" "$pin"
done <<'PINS'
  with its one cross-family review; settings sync, hooks and guards, secrets
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/AGENTS.md" "$pin"
done <<'PINS'
  with one cross-model code-diff pass; settings sync, hooks and guards, secrets
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/GLOSSARY.md" "$pin"
done <<'PINS'
**Double-sample**:
Two independent same-family adversary passes with recorded run ids: the standard-tier fallback when every eligible cross-model route is technically unavailable, recorded as `cross_model: unavailable (<category>)` (`workflow/skills/adversary.md`).
_Avoid_: second opinion, cross-check
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" "$pin"
done <<'PINS'
- Plan adversary, high-risk only (model, `shasum -a 256 PLAN.md` at dispatch, verdict, deltas):
- Code review and, at high-risk, code-diff adversary (reviewers, rounds, verdicts):
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/PLAN_TEMPLATE.md" "$pin"
done <<'PINS'
- Plan adversary (model, `shasum -a 256 PLAN.md` at dispatch, verdict, deltas):
- Code review and code-diff adversary (reviewers, rounds, verdicts):
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "$pin"
done <<'PINS'
- Plan adversary, high-risk only (model, `shasum -a 256 PLAN.md` at dispatch, verdict, deltas):
- Code review and, at high-risk, code-diff adversary (reviewers, rounds, verdicts):
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "$pin"
done <<'PINS'
- Plan adversary (model, `shasum -a 256 PLAN.md` at dispatch, verdict, deltas):
- Code review and code-diff adversary (reviewers, rounds, verdicts):
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/README.md" "$pin"
done <<'PINS'
  that never saw the conversation, on a second model family, tries to break
  it; high-risk work adds hunters and a cross-model adversary. A small docs or config edit gets a self-review instead.
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/README.md" "$pin"
done <<'PINS'
  that never saw the conversation and a second model family both try to break
  it. A small docs or config edit gets a self-review instead.
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/claude/scopes/shared/agents/adversary.md" "$pin"
done <<'PINS'
  human reviewer. This independent context is the point of the pass; do not defeat it.
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/claude/scopes/shared/agents/adversary.md" "$pin"
done <<'PINS'
  human reviewer. This is the point of the double-sample; do not defeat it.
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/docs/adr/README.md" "$pin"
done <<'PINS'
- [0052](0052-standard-tier-runs-one-cross-family-review.md) — Standard tier runs one cross-family review [accepted]
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "$pin"
done <<'PINS'
  **high-risk** requires cross-model; **small** and **standard** skip it
  (standard has its one review per `workflow/skills/review.md` § Standard
  review). An answer without provenance, or
  fallback. The pass runs after Logic+Spec lead review; a single same-family
  pass cannot replace it.
  not the implementer alone.
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "$pin"
done <<'PINS'
  **small** skips it; **standard** and **high-risk** require cross-model.
  Standard falls back to two fresh independent same-family samples only when
  every eligible route is technically unavailable, recorded as
  `cross_model: unavailable (<category>)`. An answer without provenance, or
  fallback. Required passes run after Logic+Spec lead review; a single same-family pass cannot
  replace them.
- Name `adversary_model` (or `same-family-pass: double-sample` + run ids).
- High findings: accept/reject via cross-model (or second sample), not the
  implementer alone.
- Plan-mode adversary is required before autonomous implementation completion.
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/workflow/skills/adversary.md" "$pin"
done <<'PINS'
   - **high-risk tier: cross-model required.** Read-only, name
     high-risk → `blocked`; standard → one fresh labeled `same-family` review,
     a residual-risk line in the final report.
   - **Other tiers:** small skips this pass (its self-review covers it); standard
     and a bounded fix have their one fresh-context review instead, cross-family
     required at standard while a route is available, preferred for a bounded fix.
     A same-family one only when labeled `same-family`, never as independent:
     the only single-pass same-family exception; a high finding upgrades a bounded fix to standard.
   - `high`: accept/reject via a **cross-model** pass (standard: its D1
     reviewer). The implementer alone must not close a high finding.
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/workflow/skills/adversary.md" "$pin"
done <<'PINS'
(`workflow/skills/review-rounds.md` T/D table): T rounds use fresh hunters plus the
plan. After the fresh-context review (Logic hunter + Spec hunter, then lead):
   - **high-risk and standard tiers: cross-model required.** Read-only, name
     high-risk → `blocked`; standard → a documented **double-sample** — two
     fresh same-family reviewers, independent contexts, merged findings —
     `same-family-pass` ids and a residual-risk line in the final report.
   - **small tier:** code-diff adversary is skipped (the loop's self-review
     covers it); a single same-family pass is never a substitute.
   - **bounded fix** (`workflow/skills/implementation-loop.md` § Risk tiers):
     its one fresh-context review stands in for this pass, cross-family
     preferred. A same-family one is allowed only when labeled `same-family`
     in the report, never presented as independent: the only single-pass
     same-family exception. Any high finding upgrades the fix to standard.
   - `high`: accept/reject via a **cross-model** pass (or the second sample in a
     double-sample). The implementer alone must not close a high finding.
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" "$pin"
done <<'PINS'
  READY gate kept, no plan adversary (step 5 is high-risk only); steps 13 and
  13b become one review per `workflow/skills/review.md` § Standard review (no
  code-diff adversary, `spec: parent`, labeled `same-family` fallback). Re-review
  and escalation: `workflow/skills/review-rounds.md` § Bounded fix and standard.
    Pin once; high-risk dispatches fresh Logic and Spec hunters; standard
    runs its single review (§ Risk tiers). When its
    cross-model** (no eligible route → `blocked`); **standard and small skip it**.
    Single same-family pass alone → `blocked` (the labeled single review of a
    bounded fix or a standard run aside). Name `adversary_model`.
    **High** findings: accept/reject via cross-model, not
  tier; one fresh-context review, cross-family or labeled `same-family`, for a bounded fix or standard);
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" "$pin"
done <<'PINS'
- **standard** (default) — runtime code change on a known surface. Full
  sequence below; step 13b falls back to a documented same-family
  double-sample only when every eligible cross-model route is unavailable.
5. Run `workflow/skills/adversary.md` before editing.
    Pin once; dispatch fresh Logic and Spec hunters: both for high-risk;
    standard may use Daily Pi per `workflow/skills/review.md`. When its
13b. Code-diff adversary per `workflow/skills/adversary.md`: tiered —
    **high-risk and standard require cross-model**; **small skips**. Standard
    falls back to a documented double-sample only when every eligible route is
    technically unavailable (`workflow/skills/adversary.md` § Code diff mode).
    Single same-family pass alone → `blocked` (the bounded fix's labeled single review aside).
    Name `adversary_model` (or `same-family-pass` ids plus
    `cross_model: unavailable (<category>)`).
    **High** findings: accept/reject via cross-model (or second sample), not
- adversary plan review (standard/high-risk; not a bounded fix);
- adversary code-diff review (standard/high-risk: named model; standard
  fallback: double-sample with `cross_model: unavailable (<category>)`;
  a bounded fix has its one review instead);
  tier; one fresh-context review, cross-family or labeled `same-family`, for a bounded fix);
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/workflow/skills/review-rounds.md" "$pin"
done <<'PINS'
step 13b, or a bounded fix's or standard run's single review). A clean T1 never needs it.
- T1: findings → fold → T2. T2: findings → fold → next unspent D.
## Bounded fix and standard
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/workflow/skills/review-rounds.md" "$pin"
done <<'PINS'
step 13b, or a bounded fix's single review). A clean T1 never
- T1: findings → fold → T2. T2: findings → fold → D1.
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/workflow/skills/review.md" "$pin"
done <<'PINS'
   children, never the parent (a standard run's Spec aside: § Standard review). Standards stays where step 6 runs it. An
   sentinel under Consider. A standard run takes neither fallback: it follows § Standard review.
   record `spec: parent`; a standard run uses this shape on every runtime.
   Accepted risk: that Spec pass shares the implementer's context (self-preference);
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/workflow/skills/review.md" "$pin"
done <<'PINS'
   children, never the parent. Standards stays where step 6 runs it. An
   record `spec: parent`. Accepted risk: that Spec pass shares the
   implementer's context (self-preference);
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/workflow/spec.md" "$pin"
done <<'PINS'
  their tier's review evidence (adversary at high-risk), implemented-plan archive under `docs/plan/`, and
PINS
while IFS= read -r pin; do
  assert_not_contains "$ROOT_DIR/workflow/spec.md" "$pin"
done <<'PINS'
  adversary evidence, review, implemented-plan archive under `docs/plan/`, and
- Review: Logic hunter then Spec hunter, plus the Threat hunter on access,
Shared contracts remain authoritative; this exception changes storage, not gates.
work runs its tier's full sequence; a bounded fix needs no plan but a failing
PINS
while IFS= read -r pin; do
  assert_contains "$ROOT_DIR/workflow/templates/review-lead.md" "$pin"
done <<'PINS'
runner: pi-child|cursor-task|claude-agent|pool-route
PINS
assert_not_contains "$NEW_PROJECT/workflow/spec.md" "work runs its tier's full sequence;"
assert_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "truncated, is rerun once; still unproven or truncated → \`blocked\`, never a"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "still unproven or truncated → \`blocked\`, never the fallback."
assert_not_contains "$NEW_PROJECT/workflow/pr-body-contract.md" "It also applies before each"
assert_not_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "then \`blocked\`; it never triggers the fallback."
assert_not_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "truncated, is rerun once, then \`blocked\`; never a fallback."
assert_contains "$NEW_PROJECT/workflow/skills/plan-loop.md" "Every Observed Fact an AC, step or check depends on cites \`path:line\`, or"
assert_contains "$NEW_PROJECT/PLAN_TEMPLATE.md" "- path:line or command → observed:"
assert_contains "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md" "- path:line or command → observed:"
assert_contains "$NEW_PROJECT/workflow/pr-body-contract.md" "(§ Honest status) also applies before each push to a branch with an open PR."
assert_contains "$NEW_PROJECT/workflow/pr-body-contract.md" "Before each push to a branch with an open PR, re-read the body against the"
assert_not_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "except step 13b accepts a documented same-family"
assert_not_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "**standard accepts a documented"
assert_not_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "named model or documented double-sample"
assert_not_contains "$NEW_PROJECT/workflow/skills/adversary.md" "cross-model preferred; a documented **double-sample**"
assert_not_contains "$ROOT_DIR/skills/shared/adversary/SKILL.md" "**standard** accepts cross-model or two fresh independent"
assert_same "$ROOT_DIR/scripts/lib/plan-cleanup-command.mjs" "$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
assert_file "$NEW_PROJECT/scripts/plan-cleanup"
for retired in scripts/lib/plan-status.mjs scripts/lib/hash.sh scripts/vendor; do
  assert_not_exists "$NEW_PROJECT/$retired"
done

[ -x "$NEW_PROJECT/scripts/plan-cleanup" ] || {
  printf 'expected deployed plan-cleanup to be executable\n' >&2
  exit 1
}
assert_same "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" "$NEW_PROJECT/AGENTS.md"
assert_not_exists "$NEW_PROJECT/CLAUDE.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" "$NEW_PROJECT/docs/agent-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/agent-memory.md" "$NEW_PROJECT/docs/agent-memory/README.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md" "$NEW_PROJECT/docs/plan/README.md"
assert_contains "$NEW_PROJECT/docs/plan/README.md" '- Source plan: `PLAN.md`'
assert_contains "$NEW_PROJECT/docs/plan/README.md" '- Source plan SHA-256:'
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md" "$NEW_PROJECT/docs/claude-code-workflow.md"
assert_same "$ROOT_DIR/workflow-scaffold/templates/docs/project-context.md" "$NEW_PROJECT/docs/project-context.md"
assert_same "$ROOT_DIR/workflow/plan-archive.md" "$NEW_PROJECT/workflow/plan-archive.md"
assert_same "$ROOT_DIR/workflow/spec.md" "$NEW_PROJECT/workflow/spec.md"
assert_same "$ROOT_DIR/workflow/review-rubric.md" "$NEW_PROJECT/workflow/review-rubric.md"
assert_same "$ROOT_DIR/workflow/ticket-template.md" "$NEW_PROJECT/workflow/ticket-template.md"
assert_same "$ROOT_DIR/workflow/linear-ticket-template.md" "$NEW_PROJECT/workflow/linear-ticket-template.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE.md" "$NEW_PROJECT/PLAN_TEMPLATE.md"
assert_same "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "$NEW_PROJECT/PLAN_TEMPLATE_FULL.md"
assert_same "$ROOT_DIR/scripts/plan-cleanup" "$NEW_PROJECT/scripts/plan-cleanup"

# Deployed docs must not dangle: every workflow/** reference resolves in the
# scaffold unless the target is explicitly etabli-only.
ETABLI_ONLY_REFS='^workflow/(runtime/|run/|self-improvement/)'
deployed_refs="$(grep -rhEo --include='*.md' 'workflow/[A-Za-z0-9._/-]+\.(md|json)' "$NEW_PROJECT" | sort -u)"
[ -n "$deployed_refs" ] || {
  printf 'reference scan found no workflow refs; the check is broken\n' >&2
  exit 1
}
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  if printf '%s\n' "$ref" | grep -Eq "$ETABLI_ONLY_REFS"; then
    continue
  fi
  if [ ! -e "$NEW_PROJECT/$ref" ]; then
    printf 'deployed doc references missing file: %s\n' "$ref" >&2
    exit 1
  fi
done <<<"$deployed_refs"

cat >"$NEW_PROJECT/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Subject: scaffold cleanup smoke
- Status: DRAFT
PLAN
(
  cd "$NEW_PROJECT"
  scripts/plan-cleanup --discard scaffold-smoke >/dev/null
)
assert_not_exists "$NEW_PROJECT/PLAN.md"
assert_file "$NEW_PROJECT/docs/plan/$(date -u +%Y%m%d)-discarded-scaffold-smoke.md"

while IFS= read -r contract_path; do
  contract_name="$(basename "$contract_path")"
  assert_file "$NEW_PROJECT/workflow/skills/$contract_name"
  assert_same "$contract_path" "$NEW_PROJECT/workflow/skills/$contract_name"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' | sort)
assert_contains "$NEW_PROJECT/AGENTS.md" "Ambient activation"
assert_contains "$NEW_PROJECT/AGENTS.md" "docs/agent-memory/"
assert_contains "$NEW_PROJECT/AGENTS.md" "docs/plan/"
assert_contains "$NEW_PROJECT/docs/agent-workflow.md" "Pi Coding Agent"
assert_contains "$NEW_PROJECT/docs/agent-workflow.md" "Claude Code"
assert_contains "$NEW_PROJECT/docs/claude-code-workflow.md" "workflow/skills/orchestration.md"
assert_contains "$NEW_PROJECT/docs/project-context.md" "Smallest useful check"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "## Outcome"
assert_contains "$NEW_PROJECT/workflow/linear-ticket-template.md" "Linear Fields"
assert_contains "$NEW_PROJECT/workflow/skills/implementation-loop.md" "Autonomous completion requires:"
assert_contains "$NEW_PROJECT/workflow/skills/orchestration.md" "Capability Labels"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "## Stop conditions"
assert_contains "$NEW_PROJECT/workflow/ticket-template.md" "Keep project-specific scope"
assert_not_exists "$NEW_PROJECT/.gitignore"
git -C "$NEW_PROJECT" init -q .
"$SCRIPT" "$NEW_PROJECT" >/dev/null
assert_contains "$NEW_PROJECT/.git/info/exclude" "etabli personal workflow ignores"
assert_contains "$NEW_PROJECT/.git/info/exclude" "/PLAN.md"
assert_contains "$NEW_PROJECT/.git/info/exclude" "/workflow/"
for managed in scripts/plan-cleanup scripts/lib/plan-cleanup-command.mjs scripts/lib/plan-status.mjs scripts/lib/hash.sh scripts/vendor/commonmark/commonmark.cjs; do
  git -C "$NEW_PROJECT" check-ignore -q -- "$managed" || { printf 'managed tooling exposed to project Git: %s\n' "$managed" >&2; exit 1; }
done
LINKED_MAIN="$TMP_DIR/linked-main"
LINKED_WORKTREE="$TMP_DIR/linked-worktree"
git init -q "$LINKED_MAIN"
git -C "$LINKED_MAIN" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m base
git -C "$LINKED_MAIN" worktree add -q "$LINKED_WORKTREE"
"$SCRIPT" "$LINKED_WORKTREE" >/dev/null
assert_contains "$LINKED_MAIN/.git/info/exclude" "etabli personal workflow ignores"
OLD_GIT_BIN="$TMP_DIR/old-git-bin"
OLD_GIT_PROJECT="$TMP_DIR/old-git-project"
mkdir -p "$OLD_GIT_BIN"
REAL_GIT="$(command -v git)"
cat >"$OLD_GIT_BIN/git" <<EOF
#!/bin/sh
for arg in "\$@"; do
  case "\$arg" in --path-format=*) printf '%s\\n' "\$arg"; exit 0 ;; esac
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$OLD_GIT_BIN/git"
git init -q "$OLD_GIT_PROJECT"
PATH="$OLD_GIT_BIN:$PATH" "$SCRIPT" "$OLD_GIT_PROJECT" >/dev/null
assert_contains "$OLD_GIT_PROJECT/.git/info/exclude" "etabli personal workflow ignores"
linked_status="$(git -C "$LINKED_WORKTREE" status --porcelain --untracked-files=all)"
[ -z "$linked_status" ] || { printf 'scaffold files exposed in a linked worktree:\n%s\n' "$linked_status" >&2; exit 1; }
printf '// changed managed helper\n' >>"$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
"$SCRIPT" "$NEW_PROJECT" --force >/dev/null
assert_same "$ROOT_DIR/scripts/lib/plan-cleanup-command.mjs" "$NEW_PROJECT/scripts/lib/plan-cleanup-command.mjs"
assert_not_exists "$NEW_PROJECT/.gitignore"

"$SCRIPT" "$NEW_PROJECT" >/dev/null

DRY_PROJECT="$TMP_DIR/dry-project"
"$SCRIPT" "$DRY_PROJECT" --dry-run >/dev/null
assert_not_exists "$DRY_PROJECT"

CONFLICT_PROJECT="$TMP_DIR/conflict-project"
mkdir -p "$CONFLICT_PROJECT"
printf 'custom instructions\n' >"$CONFLICT_PROJECT/AGENTS.md"

if "$SCRIPT" "$CONFLICT_PROJECT" >/dev/null 2>&1; then
  printf 'expected conflict deploy to fail\n' >&2
  exit 1
fi
assert_contains "$CONFLICT_PROJECT/AGENTS.md" "custom instructions"
assert_not_exists "$CONFLICT_PROJECT/CLAUDE.md"
assert_not_exists "$CONFLICT_PROJECT/workflow"
assert_not_exists "$CONFLICT_PROJECT/docs"
assert_not_exists "$CONFLICT_PROJECT/PLAN_TEMPLATE.md"
assert_not_exists "$CONFLICT_PROJECT/.gitignore"

PARENT_CONFLICT_PROJECT="$TMP_DIR/parent-conflict-project"
mkdir -p "$PARENT_CONFLICT_PROJECT"
printf 'not a directory\n' >"$PARENT_CONFLICT_PROJECT/docs"

if "$SCRIPT" "$PARENT_CONFLICT_PROJECT" >/dev/null 2>&1; then
  printf 'expected parent path conflict deploy to fail\n' >&2
  exit 1
fi
assert_contains "$PARENT_CONFLICT_PROJECT/docs" "not a directory"
assert_not_exists "$PARENT_CONFLICT_PROJECT/AGENTS.md"
assert_not_exists "$PARENT_CONFLICT_PROJECT/CLAUDE.md"
assert_not_exists "$PARENT_CONFLICT_PROJECT/workflow"

TARGET_FILE_PROJECT="$TMP_DIR/target-file-project"
TARGET_FILE_OUTPUT="$TMP_DIR/target-file-project.out"
printf 'not a directory\n' >"$TARGET_FILE_PROJECT"

if "$SCRIPT" "$TARGET_FILE_PROJECT" --force >"$TARGET_FILE_OUTPUT" 2>&1; then
  printf 'expected deploy to fail when target path is a file, even with --force\n' >&2
  exit 1
fi
assert_contains "$TARGET_FILE_OUTPUT" "exists but is not a directory"
assert_contains "$TARGET_FILE_PROJECT" "not a directory"

"$SCRIPT" "$PARENT_CONFLICT_PROJECT" --force >/dev/null
assert_file "$PARENT_CONFLICT_PROJECT/docs/agent-workflow.md"
if ! ls "$PARENT_CONFLICT_PROJECT"/docs.bak.* >/dev/null 2>&1; then
  printf 'expected docs backup after --force parent conflict\n' >&2
  exit 1
fi

"$SCRIPT" "$CONFLICT_PROJECT" --force >/dev/null
assert_contains "$CONFLICT_PROJECT/AGENTS.md" "project workflow scaffold"
if ! ls "$CONFLICT_PROJECT"/AGENTS.md.bak.* >/dev/null 2>&1; then
  printf 'expected AGENTS.md backup after --force\n' >&2
  exit 1
fi

printf 'custom instructions again\n' >"$CONFLICT_PROJECT/AGENTS.md"
"$SCRIPT" "$CONFLICT_PROJECT" --force >/dev/null
if [ "$(find "$CONFLICT_PROJECT" -maxdepth 1 -name 'AGENTS.md.bak.*' | wc -l | tr -d ' ')" -lt 2 ]; then
  printf 'expected repeated --force deploys to keep distinct AGENTS.md backups\n' >&2
  exit 1
fi

BROKEN_REPO="$TMP_DIR/broken-repo"
BROKEN_PROJECT="$TMP_DIR/broken-project"
BROKEN_OUTPUT="$TMP_DIR/broken-source.out"
mkdir -p "$BROKEN_REPO/scripts"
cp "$SCRIPT" "$BROKEN_REPO/scripts/deploy-workflow"
chmod +x "$BROKEN_REPO/scripts/deploy-workflow"

if "$BROKEN_REPO/scripts/deploy-workflow" "$BROKEN_PROJECT" --force >"$BROKEN_OUTPUT" 2>&1; then
  printf 'expected deploy to fail when workflow scaffold sources are missing, even with --force\n' >&2
  exit 1
fi
assert_contains "$BROKEN_OUTPUT" "MISSING"
assert_not_exists "$BROKEN_PROJECT"
assert_not_exists "$BROKEN_PROJECT/AGENTS.md"
assert_not_exists "$BROKEN_PROJECT/.gitignore"

printf 'workflow scaffold smoke test: ok\n'
