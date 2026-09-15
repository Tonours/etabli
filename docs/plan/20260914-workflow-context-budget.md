# Implemented: resident instruction context cut ~26–49% on hot workflow routes, gated by a ratchet-only context budget, plus a bounded recursive self-improvement loop

### Metric = declared characters, not billed tokens

- Choice: use one deterministic character measurement with frozen membership.
- Rejected: infer provider usage from a static estimate.
- Consequence: the gate is reproducible and uncertainty stays explicit.

The gate's source-of-truth files are versioned with the workflow.

## Outcome
- New gate `scripts/workflow-context-budget` +
  `workflow/runtime/context-budget.json`: measures declared read-chain
  surfaces in JS `String.length` chars against ceilings; `--ratchet` lowers
  ceilings to `ceil(chars * 1.03)`, never raises, refuses to write when any
  surface is `missing` or `over`. Registered in
  `workflow/runtime/agentic-infra-checks.tsv` (core cap 18 → 19).
- `workflow/spec.md` is now on-demand for hot routes; its route-critical rules
  were duplicated into `workflow/skills/implementation-loop.md` and
  `workflow/skills/plan-loop.md`. It stays canonical and wins on conflict.
- `workflow/events.md` split: validator/lock/protocol/measurement internals
  moved to `workflow/events-validator.md`; the compact agent contract stayed.
- New `workflow/templates/plan-archive.md`; symlink detail moved from
  `AGENTS.md` to `docs/symlink-layout.md` (resident "do not" warnings kept).
- `scripts/workflow-retrospect` emits `context_budget`, `telemetry`
  (measured/unmeasured only — unknowns never counted as measured), and
  `terminal` (completed/blocked/in_progress) sections; tolerates corrupt
  `events.jsonl` lines instead of dying under `pipefail`.
- `workflow/skills/self-improvement-loop.md` Token lens: retrospect →
  candidates → READY `PLAN.md` → trim → `--ratchet`. Unattended
  `recurring-run` may only retrospection-write under `.workflow/<slug>/`;
  applying anything requires a user-invoked `plan-implement`.

| surface | baseline | chars | ratcheted ceiling | Δ |
| --- | ---: | ---: | ---: | ---: |
| always-on | 28423 | 16150 | 16635 | −43 % |
| plan-loop | 5657 | 4180 | 4306 | −26 % |
| plan-implement | 80451 | 52991 | 54581 | −34 % |
| implement | 74632 | 48747 | 50210 | −35 % |
| review | 21800 | 21800 | 21800 | 0 % |
| verify | 3093 | 3071 | 3093 | −1 % |
| spec-map | 32258 | 32256 | 32258 | ~0 % |

These are resident-instruction characters, not billed tokens; est_tokens is
`chars/4` and provider-billed savings are explicitly unverified (38 of 53
`outcome_metric` ledgers are unmeasured). The resident-context multiplier is
the evidence: ledger total/(input+output) ratios of 37×–420×.

## Context
- `workflow/runtime/context-budget.json`: surface membership is the contract;
  `always-on`/`plan-loop`/`plan-implement` memberships are pinned in
  `tests/workflow-context-budget-smoke.sh`.
- `workflow/events.md` vs `workflow/events-validator.md`: the validator doc is
  deliberately cold (opened only when editing the event system); surface
  descriptions say so.
- `.workflow/workflow-context-budget/baseline.json`: frozen pre-change
  measurements; `review-patch.diff` + hunter/adversary outputs in the same dir.

## Measurement design

The gate measures declared resident instruction characters on each hot route.
It reads one frozen membership file and applies ratchet-only ceilings.
A missing surface or an over-ceiling surface is a hard failure.

The reported character count is a deterministic proxy, not a billing receipt.
Static estimates are labelled as estimates and never promoted to provider data.
Unattended runs may write only their scoped evidence ledger.
Applying a candidate still requires a reviewed READY plan and explicit consent.

## Scope boundary

Canonical workflow rules remain available on demand and win on conflict.
Route-critical rules are duplicated where a hot path needs them immediately.
Cold validator detail stays out of the resident chain unless the task edits it.
Membership pins and smoke fixtures make accidental surface growth visible.

The loop measures first, proposes second, and changes only after review.
It does not rewrite its own contract from a single retrospective observation.
A failed ratchet never writes a larger ceiling.
Unknown telemetry remains unknown in the report.

## Privacy boundary

Public docs retain the reusable control and acceptance rule.
Operational traces, identities, and raw transcripts remain in private storage.
Only opaque references cross the boundary into public evidence.
## Decisions
### Surface decision
- Choice: keep route-critical rules available on hot paths and validator detail cold.
- Rejected: remove the canonical specification or infer membership from prose.
- Consequence: context growth stays visible and conflict resolution remains explicit.

### spec.md on-demand, with rule duplication instead of removal
- Choice: duplicate the route-critical spec rules into the loop contracts, keep spec.md canonical + conflict-winning, ceiling the `spec-map` surface so growth cannot hide there.
- Rejected: linking without duplicating (hot routes would lose the rules).

### Recursive self-improvement stays READY-gated
- Choice: unattended runs measure and report only; application requires user-invoked `plan-implement`; ceilings raise only via reviewed diff + Decision Log.
- Consequences: the loop cannot patch the harness autonomously; `--ratchet` itself fails closed on non-green runs.

## Accepted drift

The initial target was based on an incomplete surface inventory.
The implemented baseline includes every resident file paid on the hot route.
The measured reduction remains reported as characters, not token savings.

An unattended retrospective can report candidates but cannot apply them.
Intentional budget growth requires a reviewed diff and a Decision Log entry.
The plan slot remains singular so stale proposals cannot be applied silently.

## Evidence boundary

Review outputs identify the scope and command without exposing raw case data.
Private operational detail is retained once in the approved context store.
Public replacements are synthetic or generic and contain no account identifiers.

## Follow-up State

- Remaining risks: scaffold deployments carry the new files only after a redeploy; the unrelated local type-check issue remains outside this migration.
- Parking lot: `events-validator.md` could join a future `events-maint` surface if the event system becomes a frequent edit target; unattended-bound could get a mechanical allowlist if prose ever proves insufficient; terminal counts in retrospect are the regression trigger for the next self-improvement cycle.
- Superseded docs/specs: none.
- Next links: `docs/workflow-context-budget.md` (metric + loop doc), `workflow/skills/self-improvement-loop.md` § Token lens, `.workflow/workflow-context-budget/baseline.json`.
