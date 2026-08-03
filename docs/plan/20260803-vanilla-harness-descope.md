# Implemented: harness de-scoping toward a vanilla-closer setup

## Metadata
- Archived: 2026-08-03
- Source plan: Review of recent etabli changes + de-scoping toward a vanilla-closer harness
- Status: IMPLEMENTED (6 of 7 steps; route injection deferred)
- Commit / branch: `refactor/vanilla-harness-descope`, `56c1f75..ff76c82`

## Outcome

Seven commits, **-11 079 lines net across 117 files**. `verify-agentic-infra full`
went from a red baseline to 44 PASS / 1 FAIL (`skill-lock`, pre-existing on `main`).

| Step | Commit | Effect |
| --- | --- | --- |
| red test + style | `56c1f75` | 240/240; baseline green for the first time since `d3fd845` |
| thinking override (P0) | `4280b21` | -29 net |
| untrack skills-archive | `1763b6f` | -5853 |
| multi-model portfolio | `71f449b` | -2606 |
| model-network-tune | `9fefaea` | -382 |
| reporting scripts | `68b3b2a` | -2127 |
| stale prose + ADR-0013 | `7f6020c` | -78 |
| quick-card restore | `ff76c82` | +115 (regression fix, see below) |

Not done: route injection removal (both adapters). It is the only change no
mechanical check can observe; deferred for an explicit decision rather than
shipped blind. Carried into the follow-up plan as its step 2.

## Context

- `pi/extensions/workflow-router.ts:504-517` — the route-adaptive thinking
  override read `pi.getThinkingLevel()` (session level), never
  `defaultThinkingLevel`. A "floor" against the session level would have
  ratcheted upward forever.
- `scripts/workflow-event:7,293` — executes `workflow-measurement-integrity`
  on every ledger append.
- `scripts/lib/no-progress-guard.mjs:189` — whitelists `workflow-event` as the
  no-progress escape hatch.
- `.workflow/*/events.jsonl` — 13 events total, all 2026-07-04/05, none since.
- `workflow/runtime/agentic-infra-checks.tsv` — profile membership; the manifest
  smoke hard-fails on a row whose target file is gone.

## Decisions

### Delete the route-adaptive thinking override instead of flooring it
- Context: P0 was the override clobbering the user's thinking level on every turn,
  carved out for `zai/glm-5.2` only in `ce2c400`.
- Choice: replace the whole mechanism with an explicit "xhigh on adversary /
  sec-pr / bug-check / pr-review, otherwise don't touch" rule.
- Rejected: a floor of `max(defaultThinkingLevel, route)`.
- Rationale: with `defaultThinkingLevel: "high"` a floor makes the `medium`
  branch unreachable and the `high` branch a no-op — the feature collapses to
  exactly that explicit rule anyway. The floor was a detour to the same place.
- Consequences: `ce2c400`'s intent partially survives (glm-5.2 reaches xhigh on
  those four routes, not always). All other providers stop being clobbered.

### Keep the ledger CLI while deleting the reporters
- Context: the user's answer was "delete all telemetry", but `workflow-event` is
  the no-progress guard's only documented escape hatch.
- Choice: delete six reporting scripts; keep `workflow-event`,
  `no-progress-guard.mjs`, and `workflow-measurement-integrity`.
- Rejected: deleting all eight; deleting the guard too.
- Rationale: the guard was explicitly kept by the same decision set. Deleting its
  escape hatch would leave a blocker naming a missing tool, violating the repo's
  own "every check names its remediation" principle.
- Consequences: the reporting surface is gone; ledger validation still works.

### Keep `multi_execution_completed` as a ledger schema
- Context: it carries the council's name but has nine consumers.
- Choice: relax the jq validator (drop hardcoded model IDs, `adjudicator` becomes
  any non-empty string); keep the event type.
- Rationale: removing the council is not a licence to retro-edit the ledger protocol.

## Accepted Drift

- Original plan: delete seven reporting scripts.
  Implemented: six. `workflow-measurement-integrity` turned out to be ledger
  infrastructure, not a reporter (see Validation Evidence).
- Original plan: step 3 touches 18 files. Implemented: 30, after the portfolio
  surface was found to include `multiExecution` machinery, two extra smokes, and
  the check manifest.
- Original plan's validation grep omitted `multiExecution` / `portfolio` /
  `one-writer-portfolio` — a false-green that would have passed while the
  machinery survived in a dozen files. Corrected mid-flight.

## Validation Evidence

- command: `scripts/verify-agentic-infra full`
  - result: 44 PASS, 1 FAIL (`skill-lock`: `caveman`/`grill-me` lock drift,
    confirmed pre-existing on `main` by stashing the branch)
- command: `bun test pi/extensions/__tests__/`
  - result: 225 pass, 0 fail
- command: `scripts/-suite --json --strategy baseline`
  - result: `suite_failed: 0` after restoring `workflow-measurement-integrity`;
    it was 3 while the file was deleted (`lh-ledger-resume-terminal-completed`,
    `lh-no-progress-event-shape`, `lh-handoff-event-shape`)
- command: `bash tests/workflow-docs-smoke.sh`
  - result: ok

## Follow-up State

- Remaining risks: route injection still active on both adapters; the harness is
  not "closer to vanilla" in the way the request intended.
- Parking lot:
  - `skill-lock` fails on `main` (`caveman`, `grill-me` not declared in
    `skill-surface.tsv`). Needs `bun run update:skills-lock`, unrelated to this work.
  - Two Pi capabilities (`supports_subagents`, `supports_taskexecute_tracking`)
    lost their live probe with the removed smoke; left `unknown` with an
    explicitly unprovable `proof_command` rather than relabelled without evidence.
- Superseded docs/specs: `workflow/skills/multi-model-orchestration.md` deleted;
  ADR-0013 records the removal.
- Next links: `docs/adr/0013-remove-the-multi-model-council-and-telemetry-reporters.md`

## Lessons

Three process failures worth keeping, all mine:

1. **A green baseline was recorded while a test was red.** `prefer-ipv4-dns`
   asserted a Node getter Bun does not implement; archived plans claimed
   "238 pass / 0 fail" when it was 238/1. Any harness-efficiency figure resting
   on that baseline is unverified.
2. **`bash tests/x.sh | tail` swallows the exit code.** I reported a failing
   smoke as passing because I read `$?` after a pipe. Read the exit code from
   the direct call.
3. **`rg` and this shell's `git grep -l` wrapper returned false-empty results**
   for these patterns; only `grep -rl --include=` was reliable. A 12-file test
   surface was found only by cross-checking with a positive control. Never trust
   a "no references" result without one.

A fourth, found after the fact: a `grep -v` intended to drop two lines emptied
`workflow/agent-quick-card.md` entirely (119 -> 0 lines) in `68b3b2a`. Restored
in `ff76c82`. Filtering a file in place needs a line-count assertion after.
