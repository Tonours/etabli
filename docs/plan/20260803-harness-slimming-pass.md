# Implemented: harness slimming — Pi extensions and per-turn context

## Metadata
- Archived: 2026-08-03
- Source plan: Harness slimming pass — Pi extensions, token efficiency, context window
- Status: IMPLEMENTED (3 of 3 steps)
- Commit / branch: `refactor/vanilla-harness-descope`, `120be3c..67f1a40`

## Outcome

| Measure | Before | After |
| --- | --- | --- |
| Pi extension lines | 2667 | **1650** (-38%) |
| Extension files | 14 | 12 |
| Route injection per turn | ~301 tok | **0** |
| Always-loaded Pi instructions | 10 700 chars | 10 521 |

Net across the run: 72 files changed, -2375 lines. On a 50-turn session the
injection removal alone frees ~15k tokens of context.

`scripts/verify-agentic-infra full`: 44 PASS, 1 FAIL (`skill-lock`, pre-existing
on `main`). `scripts/router-eval`: 53/53, accuracy 1.0. 192 Pi tests pass.

## Context

Measured, not estimated — the analysis contradicted the request's premise:

- `pi/extensions/filter-output.ts` — 760 lines, 46 secret-redaction patterns,
  33K test file. Security control, kept.
- `pi/extensions/rtk.ts` + runtime — 266 lines. `rtk` compresses tool output; it
  *is* a token optimisation. Cutting it would have worsened the stated goal.
- Router injection measured on real prompts: 834-1426 chars/turn (~209-357 tok)
  against a ~2 700 tok fixed instruction load. Over 50 turns the per-turn cost
  dominates.
- `dist/core/skills.d.ts` — Pi's `Skill` type carries `name`, `description`,
  `filePath` and no body; `formatSkillsForPrompt` emits metadata only. So the
  57 439 chars of skill bodies cost **zero** per turn. This closed the plan's
  one blocking assumption and confirmed the priority order.

## Decisions

### Cut by measured cost, not by file size
- Context: the request asked to remove "a large part" of the Pi extensions.
- Choice: remove `tasks-till-done` (710), `block-google-providers` (213), and
  route injection (~250 across both adapters).
- Rejected: cutting `filter-output` (the largest file) and `rtk`.
- Rationale: size is not the criterion. One is a security boundary, the other is
  itself a token optimisation. The honest ceiling was ~44% of extension lines,
  not "most of them" — stated up front rather than discovered late.

### Rewrite `agent-scenarios-smoke.sh` instead of deleting it
- Context: it executed the deleted hook, so the obvious move was deletion.
- Choice: add a `claude_route_probe` helper that renders the same fields from
  `classifyWorkflowRoute` directly.
- Rationale: it is the Claude/Pi route-parity matrix; deleting it would have
  silently dropped 11 scenarios. Verified by the fresh-context review to still
  assert against independently stored `expected.json` needles — it can fail.

### Keep the Pi `appendEntry` decision record
- Context: with no injection, it looked like dead weight.
- Choice: keep it. No `registerEntryRenderer` exists for it, so it is not a UI
  feature — it is the only observation point for the Pi-side classifier, and
  five extension tests assert through it.
- Consequence: if it is ever removed, Pi routing becomes untested; `router-eval`
  covers the Claude library only.

### Do not mark ADR-0007 superseded
- Context: `scripts/validate-adrs` demanded reciprocity for a `supersedes` field.
- Choice: drop the field from ADR-0014 and explain the narrowing in prose.
- Rationale: ADR-0007 bundled classification-with-guards and injection. Only the
  second is reversed; its guard half (READY gate, check-freeze, ops-stop) is
  still in force. Flipping it to `superseded` would have been false.

## Accepted Drift

- Plan said step 2 touched "5 test surfaces". Real count: ~40 router invocations
  in `tests/claude-hooks-smoke.sh` alone (481 -> 295 lines) plus four other
  files. User authorized deleting the router assertions and relying on
  `router-eval` after it was verified to cover routes and knowledge-routing.
- Plan scoped step 3 to `pi/` only. It forced edits to `workflow/spec.md`
  (routing row + adapter note) and `workflow/skills/orchestration.md`, crossing
  the plan's own escalation gate. User authorized the `workflow/` edits.
- `supports_structured_task_state` was `confirmed` on a proof command that step 3
  deleted. Downgraded to `unknown` with an explicitly unprovable command rather
  than left as a false claim.

## Validation Evidence

- command: `scripts/verify-agentic-infra full`
  - result: 44 PASS, 1 FAIL (`skill-lock` only)
- command: `scripts/router-eval`
  - result: total=53 passed=53 accuracy=1
- command: `bun test pi/extensions/__tests__/`
  - result: 192 pass, 0 fail
- command: `cd pi && bun run typecheck`
  - result: clean
- command: fresh-context diff review (subagent, read-only)
  - result: BLOCK on one finding, fixed; differential test of old vs new
    `classifyWorkflowRoute` across 94 prompts returned 0 diffs, and all six
    guards verified to retain full logic, not just signatures.

## Follow-up State

- Remaining risks: no mechanical check observes the behavioral effect of
  removing injection. `router-eval` proves the classifier intact, not that
  agents route well without injected context. Judged in daily use; revertible
  alone.
- Parking lot:
  - `skill-lock` fails on `main` (`caveman`, `grill-me` absent from
    `skill-surface.tsv`). Needs `bun run update:skills-lock`.
  - `scripts/lib/route-context-manifest.mjs` is orphaned; the manifest JSON and
    its bash checker still run while nothing consumes them at runtime.
  - `@agwab/pi-workflow` is 48M of the 431M npm install, `proxy_supported`, and
    contract-gated to explicit requests only. `@tintinweb/pi-tasks` (288K) lost
    its only consumer with `tasks-till-done`.
- Next links: `docs/adr/0014-stop-injecting-route-context-into-every-prompt.md`

## Lessons

**A known-failing check can hide a new one.** `pi-import-smoke` still imported
the deleted `block-google-providers.ts` and failed — but `skill-lock` fails
earlier in the same group (rows 46 and 47 of `agentic-infra-checks.tsv`) and
stops the run. Three consecutive `verify-agentic-infra full` runs reported
"44 PASS / 1 FAIL" and I recorded that in ADR-0014 as validation. It took a
fresh-context review to catch it. When a group already has a red check, run the
specific target directly — the group result is not proof for anything ordered
after the failure.

Second: the installed `~/.pi/agent/settings.json` is a real file, not a symlink
to the repo. It kept declaring two deleted extensions until it was fixed by
hand. Repo-side removals do not propagate to it.
