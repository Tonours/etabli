# Implemented: Ambient automatic Codex team orchestration

## Metadata
- Archived: 2026-07-24
- Source plan: Make Codex team orchestration ambient and automatic
- Status: IMPLEMENTED
- Commit / branch: local `main`, not committed

## Outcome
- Codex now evaluates `parent-only`, `scout`, `council`, or `fresh-review` on
  every request without requiring a skill name or delegation keyword.
- Non-trivial eligible work with a materially useful independent packet
  automatically receives a Terra read-only scout when the collaboration runner
  is available.
- Trivial, ineligible, tightly coupled, sensitive, externally mutating, and
  explicit opt-out work stays parent-only.
- Sidecars are leaf agents, use fresh context by default, and cannot write the
  shared worktree; the parent remains the sole writer and integrator.
- Council selection remains deterministic and requires a live
  protocol-compatible participant portfolio.

## Context
- `workflow/skills/orchestration.md`: canonical Codex ambient team policy.
- `workflow/skills/multi-model-orchestration.md`: existing Pi scoring and
  protocol-v2 participant constraints had to remain intact.
- `codex/skills/codex-dynamic-workflows/SKILL.md`: the prior adapter required
  explicit use and allowed disjoint sidecar edits.
- `codex/AGENTS.md`: ambient activation is deployed into the live Codex
  instruction surface by the existing deployment mechanism.

## Decisions
### Make classification systematic without forcing wasteful sidecars
- Context: the user required automatic use on every request, while the existing
  blind quality gate showed that full panels can add latency without quality.
- Choice: classify every request automatically, but keep parent-only as a valid
  mode when no useful independent packet exists.
- Rejected options: force a sidecar for trivial requests; require explicit
  invocation of `codex-dynamic-workflows`.
- Rationale: preserves automatic governance while avoiding performative
  orchestration.
- Consequences: ordinary substantive Codex work delegates automatically; small
  work remains fast.

### Keep the parent as the only writer
- Context: Codex sidecars share the filesystem and the old skill allowed
  disjoint worker edits.
- Choice: sidecars are read-only leaf agents; the parent applies accepted
  findings and runs validation.
- Rejected options: concurrent shared-worktree edits based only on prose file
  ownership.
- Rationale: prevents conflicting diffs and ambiguous responsibility.
- Consequences: parallelism is concentrated in reconnaissance and review.

### Require a proven Codex council portfolio
- Context: the shared Pi council uses Luna/Terra plus GLM, while the current
  Codex surface proves Terra/Sol and protocol v2 reserves Sol for adjudication.
- Choice: automatically admit a Terra scout; run a council only when a distinct
  protocol-compatible second participant is live-proven. Otherwise record
  `degraded` or stop `blocked`.
- Rejected options: infer a council from two broad heuristic criteria; claim a
  same-model pair as protocol-compatible; create a new event protocol in this
  change.
- Rationale: keeps runtime and ledger claims honest.
- Consequences: automatic scout orchestration works now; automatic councils
  remain capability-gated.

## Accepted Drift
- Original plan/spec: initial wording mapped Sol low/medium/high directly to
  scout and reviewer roles.
- Implemented reality: Terra uses low/medium/high for Codex sidecars, while Sol
  remains the parent and exceptional adjudicator.
- Why accepted: this matches current protocol-v2 participant validation and
  avoids an unsupported runtime claim.

## Validation Evidence
- `bash tests/codex-organization-smoke.sh`
  - result: exit 0, `codex organization smoke test: ok`
- `bash tests/workflow-docs-smoke.sh`
  - result: exit 0, `workflow docs smoke test: ok`
- `scripts/workflow-efficiency-report --json`
  - result: exit 0; instruction ratio `0.21269169751454256`, within the `0.25`
    target; `source_of_truth_conflicts: 0`
- `git diff --check`
  - result: exit 0
- `scripts/deploy-codex --dry-run --codex-home /Users/tonours/.codex`
  - result: correctly refused the pre-existing `AGENTS.md` symlink topology
    with one conflict and made no changes
- `cmp codex/AGENTS.md /Users/tonours/.codex/skills/AGENTS.md`
  - result: exit 0 after applying only the missing policy lines to the resolved
    live target; no forced deployment was used
- `rg 'Apply the Codex ambient team profile' /Users/tonours/.codex/AGENTS.md`
  - result: live entrypoint contains the ambient policy
- Fresh-context Terra diff review
  - first verdict: `BLOCK`; found a local council heuristic and an unsupported
    Codex council portfolio
  - fixes: council selection delegated exclusively to the canonical profile;
    unsupported portfolios now degrade or block
  - final verdict: `GO`, `No findings.`

## Follow-up State
- Remaining risks: actual subagent availability and provenance remain
  session-scoped; the contract reports missing capability as `blocked` or
  `unknown`.
- Live activation: `~/.codex/AGENTS.md` resolves through the user's existing
  `skills/AGENTS.md` topology and now matches the tracked Codex instructions.
- Parking lot: consider a new council protocol only after Codex proves a second
  compatible participant and comparative quality evidence justifies it.
- Superseded docs/specs: none.
- Next links: `workflow/skills/orchestration.md`,
  `docs/codex-app-subagents.md`.
