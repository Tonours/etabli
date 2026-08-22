# Implemented: isolate review hunt from lead filter

## Metadata
- Archived: 2026-08-22
- Source plan: `PLAN.md` — Isolate review hunt from lead filter
- Source plan SHA-256: `213ce6b99aa9fde687a4c16ab6251d2c782892b19b786d95d2c93cbbfc9ddb93`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `refactor/skill-default-load`

## Outcome
- `/review` and `/pr-review` pin the patch once, dispatch Logic and Spec
  hunters in fresh contexts, then lead-filter with Act on / Consider /
  `Dismissed: none`.
- Claude reuses the existing `reviewer` agent twice (no `spec-reviewer.md`).
  `/review`, `/pr-review`, and `/github-pr-review` now preapprove `Agent`.
- Pi hunters run via `pi -p --tools read`; spawn failure is
  `HUNTER_SPAWN_UNAVAILABLE`, not same-session Logic self-review.
- GO/BLOCK, deciding-code, and the eight-lens table stay. Convention defers to
  the Standards hunter when that hunter runs.

## Context
- The previous sequential break-first then plan-fit pass starved extra-lens
  bugs and often graded the implementer's own session.
- `tests/claude-agents-smoke.sh` still allows only `reviewer scout worker`.

## Decisions
### Two briefs on one reviewer agent
- Context: a fourth Claude agent would fail the exact-set smoke.
- Choice: Logic and Spec templates, same `reviewer` agent, parent names the axis.
- Rejected options: add `spec-reviewer.md`; keep sequential same-session passes.
- Rationale: meets isolation without expanding the bounded agent set.
- Consequences: Spec must not mix into Logic; first line of each spawn is the gate.

### Parent pins the patch; no `gh` on hunters
- Context: the read-only Bash guard allows `git diff`, not `gh`.
- Choice: parent captures `git`/`gh` output; hunters receive the bytes.
- Rejected options: extend the guard with `gh`; hunters re-run `git diff`.
- Rationale: pin-once stays true; PR review still works with user-approved Bash.

### Pi hunters are `pi -p`, not `pi-subagents`
- Context: Pi profile is parent-only; `supports_subagents` is unknown.
- Choice: `pi -p --tools read` as a new process; honest stop if unavailable.
- Rejected options: re-enable `pi-subagents`; fake isolation in the parent transcript.
- Rationale: same process-isolation pattern as `/adversary`.

## Accepted Drift
- Original plan/spec: validation listed docs-smoke pins only, then adversary
  added `claude-agents-smoke` and `claude-commands-smoke`.
- Implemented reality: all three smokes are the done gate and pass.
- Why accepted: folded from the plan-mode adversary before implementation.

## Validation Evidence
- command: `bash tests/workflow-docs-smoke.sh`
  - result: pass (2026-08-22)
- command: `bash tests/claude-agents-smoke.sh`
  - result: pass (2026-08-22)
- command: `bash tests/claude-commands-smoke.sh`
  - result: pass (2026-08-22)
- command: `git diff --check`
  - result: clean (2026-08-22)
- review: Logic hunter `claude-fable-5-thinking-high` GO WITH NOTES; Spec hunter
  same model, one low plan-fit note; both folded (`quality: none`, parallel
  dispatch, PR-review convention deferral).
- code-diff adversary: `claude-fable-5-thinking-high` (openai-codex/gpt-5.5
  usage-limited; zai/glm-5.2 hung). Verdict GO WITH NOTES; MEDIUM/LOW folded.
  Cross-family vs implementer grok-4.6.
- simplify: clean
- quality: none (docs/contract + smoke; no language/UI product surface)

## Follow-up State
- Remaining risks: Pi `pi -p` unavailable on a machine → honest
  `HUNTER_SPAWN_UNAVAILABLE`; hunter axis leak if the parent omits `Axis:`.
- Parking lot: Fowler smells, blast-radius, daily 4-model interrogate, live
  Matt-vs-Etabli eval.
- Superseded docs/specs: sequential break-first / plan-fit as the review machine.
- Next links: untracked `workflow/templates/review-*.md` must be staged with the
  rest before commit; dry `/review` on a small diff is still a human check.
