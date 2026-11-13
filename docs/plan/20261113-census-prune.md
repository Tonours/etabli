# Implemented: prune the surfaces the 28-day census shows unused

## Metadata
- Archived: 2026-11-13
- Source plan: `PLAN.md` — prune the surfaces the 28-day transcript census shows unused
- Source plan SHA-256: `be661306c920ea995735675ced4116db9edb255444d42e28245c89dc8648e61f`
- Status: IMPLEMENTED
- Commit / branch: `chore/census-prune` from 34ee3f50, reviewed head db9b6bec
- Workflow initiative: none

## Outcome
- RTK integration removed; `rtk-guard.mjs` joins the retired hook names so `claude-hooks-merge` cleans installed settings (old-install migration smoke, idempotent).
- Cold contracts and their feeder sections removed; all retired paths, plus the `bug-check`, `linear-work` and `linear-project-setup` contracts, are in `RETIRED_FILES`.
- 14 sub-weekly skills removed from catalog, lock, overrides, vendor sources and disk; `PINNED_ON` updated; fixtures moved to kept skills.
- `verify` route folded into `answer`; work commands reduced to `/linear-ticket-create` and `/pr-council-review`; Pi Task* fact stated once.
- `pr-body-guard` lets an unreadable body through per invocation; literal here-strings are now checked.
- `prs-today` removed; ADR-0045; entry-chain cap 330 (chain 315 lines).

## Context
- `/tmp/etabli-census/out.txt`, `out-mbw.txt`: 2 349 and 2 696 sessions; removed skills at 0-2 sessions in 28 days.
- `scripts/deploy-agent-workflow` never runs `claude-hooks-merge`; migration must precede the hook file removal on each machine.

## Decisions
### Fail open on unreadable PR bodies
- Context: path and runtime refusals cost retries on correct bodies.
- Choice: `{unchecked:true}` per invocation; other invocations and commits still checked; non-regular and >1 MiB files stay refused.
- Rejected options: soft deny (keeps the retry cost); unchecked for expanding heredocs (expansion corrupts the body, refusal prevents a real bug).
- Rationale: hygiene guard, already fail-open on crash.
- Consequences: a body file written in the same command is not checked.

### Refuted census findings kept
- Context: recon contradicted part of the census answer.
- Choice: keep thermo-nuclear, apply-adr, pi-dmi-stamp, Cursor runner, PLAN hash, evidence labels.
- Rejected options: delete per census.
- Rationale: each has a live consumer.
- Consequences: listed in ADR-0045.

## Accepted Drift
- Original plan/spec: delete only the listed contracts.
- Implemented reality: their feeder sections (run-learning, long loops, effectiveness comparison, run incidents) went too.
- Why accepted: they only produced or read the deleted artifacts; recorded in ADR-0045.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: exit 0, 15/15
- command: `scripts/verify-agentic-infra full`
  - result: 46/49; the 3 failures (pr-review-gates, pr-review-lifecycle, mutation-probe-test) fail identically on 34ee3f50
- command: `cd pi && bun test extensions/__tests__/`
  - result: 105 pass / 0 fail
- command: hand mutants on `pr-body-guard.mjs`
  - result: 4/4 killed; the probe generated none (masker limitation)
- command: hunters and cross-family adversary (`gpt-6.1-sol`, two rounds)
  - result: Logic GO, Spec and Threat findings folded or accepted, R2 confirmed the here-string fix
- command: migration `claude-hooks-merge` then `claude-hooks-check` on macmini (two config dirs) and macbook-work
  - result: rtk-guard entries removed, check ok

## Follow-up State
- Remaining risks: same-command body files unchecked; hostile-parser gaps in the static decoder (quoted fd copy, `<<< --help`, NUL in ANSI-C, backslash-newline); running Pi sessions keep the RTK extension until restarted.
- Parking lot: the 3 pre-existing full-group failures.
- Superseded docs/specs: none.
- Next links: ADR-0045; post-merge per machine: pull, `deploy-agent-workflow --apply`, `claude-hooks-check`, `deploy-agent-workflow --check`.
