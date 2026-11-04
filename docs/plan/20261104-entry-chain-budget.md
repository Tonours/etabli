# Implemented: entry chain capped after a two-machine transcript census

## Metadata
- Archived: 2026-11-04
- Source plan: `PLAN.md` — Cap hot-context growth after a two-machine transcript census
- Status: IMPLEMENTED
- Source plan SHA-256: `cfaff42aab4f1075502e78664d56778a0333e81806a17d979cedbd648e545bb2`
- Commit / branch: main (direct commits, pushed with this archive)
- Workflow initiative: entry-chain-budget

## Outcome
- The entry chain (`AGENTS.md`, `workflow/spec.md`, `workflow/agent-rules.md`, `workflow/contract-details.md`) is capped at 420 lines by `tests/entry-chain-budget-smoke.sh` in the verify core group; the smoke self-tests an over-cap copy and names its remediation.
- `workflow/spec.md` states that editorial `workflow/` edits changing no route, gate, or obligation are small tier when no plan-route row matches; contractual changes keep their tier.
- ADR-0042 records the census, the deferred cuts, and a 2027-01-04 review date; `GLOSSARY.md` defines "entry chain".
- A flaky full-group failure was fixed in `tests/mutation-probe.test.mjs`: the snapshot helper retries an entry once on `ENOENT` only, and test fixtures set `gc.auto=0`/`maintenance.auto=false` so a detached Git maintenance lock cannot race the before/after compare.

## Context
- Census 2026-11-04: 9 923 transcript files under 60 days on this machine (105 777 `workflow/*.md` mentions) and 9 283 on macbook-work over ssh, counts only (181 767 mentions). Every tracked `workflow/*.md` carries at least 182 summed mentions.
- The entry chain grew from 112 lines (2026-03-21) to 616 (2026-08-30) before a hand trim, after ADR-0035 removed the former context-budget checks.

## Decisions
### Measure first, then cut only what the evidence supports
- Context: the request was to apply six anti-auto-reference cuts, including deleting `workflow/contract-details.md`, inlining skill contracts, and slimming `scripts/deploy-workflow`.
- Choice: census both machines first; ship only the cap and the meta-light rule.
- Rejected options: the three deletions above (recorded as deferred, not refuted, in ADR-0042).
- Rationale: mentions are a reference inventory inflated by injected prompts, not proof of effective reads; they only show no tracked contract is dead. The scaffold smoke also pins `contract-details.md` in deployed projects.
- Consequences: the cuts remain available to a future census that can measure effective opens; the cap forces a one-in-one-out conversation instead.

### Cap form: one `wc -l` smoke, not the removed budget subsystem
- Context: ADR-0035 removed the context-budget meta-checks.
- Choice: a single smoke in the existing verify harness, with a review date that deletes it if it never fires.
- Rejected options: a builtin in `scripts/verify-agentic-infra` (its negative test would sit outside automated checks).
- Rationale: the smoke carries its own cap+1 negative, killing the always-pass mutant.

## Accepted Drift
- Original plan/spec: hot-context naming and a `scripts/verify-agentic-infra` builtin.
- Implemented reality: canonical term is "entry chain" (GLOSSARY.md), check lives in `tests/entry-chain-budget-smoke.sh`; the mutation-probe snapshot fix joined the run after the full group exposed the flake.
- Why accepted: terminology sharpening on review, and the full group is the push gate.

## Validation Evidence
- command: `bash /tmp/etabli-census.sh` and `ssh macbook-work 'bash -s' < /tmp/etabli-census.sh`
  - result: exit 0 both; per-machine totals above.
- command: `scripts/verify-agentic-infra core`
  - result: PASS, 16/16 checks.
- command: `node --test tests/mutation-probe.test.mjs`
  - result: PASS, 35 pass, 1 skipped.
- command: `scripts/verify-agentic-infra full`
  - result: PASS, 46/46 checks (after one FAIL on the maintenance-lock flake, fixed and rerun).
- command: `node scripts/validate-adrs .`
  - result: PASS, 42 records.
- Plan adversary: Codex gpt-6.1-sol, CHALLENGED then delta READY. Review T1: Logic GO WITH NOTES (2 lows fixed), Spec No findings; D1 delta GO; code-diff adversary Codex (OpenAI, author Muse (Meta side)): No findings, GO.
  - result: mutation: n/a (0 mutants on the shell smoke); simplify: clean; quality: pass.

## Follow-up State
- Remaining risks: census mentions still cannot prove effective reads; the cap covers only the entry chain, not `workflow/skills/` (loads per route).
- Parking lot: deploy-workflow slimming needs its own migration plan for scaffolded work repos.
- Superseded docs/specs: none.
- Next links: ADR-0042 review date 2027-01-04 (rerun the census; delete the cap if it never fired and the chain did not grow).
