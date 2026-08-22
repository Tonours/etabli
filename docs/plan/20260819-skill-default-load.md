# Implemented: skill default-load KonMari (slices 1+2)

## Metadata
- Archived: 2026-08-19
- Source plan: `PLAN.md` — Marie Kondo recentering of Etabli on the used workflow kernel
- Source plan SHA-256: `ff15ea6ed80cb546bc5d80fe01c1f733583a1b27eda3889030e1aacfb80f6fd0`
- Status: IMPLEMENTED
- Commit / branch: `refactor/skill-default-load` (uncommitted at archive)

## Outcome
Default-loaded skills are the 13-name keep-list. `review` is visible on `~/.agents`. Suites, ui.sh, captures, and `github-pr-review` are opt-in (not `pi_core`, not `agents_visible`, not `cross_harness`). `suite-router` is no longer mandatory in `workflow/spec.md`. `-suite-smoke` moved from `core` to `full`. Vendor linking is unchanged. Empty `cross_harness` no longer crashes bash `set -u`.

## Context
- `workflow/runtime/skill-surface.tsv`: catalog flags
- Conversation retrospect 2026-08-19: 58/95 skills unmentioned; slash catalog use near zero; Grok volume leader
- ADR-0013/0014: no council, no prompt injection, no extra global router

## Decisions
### Keep-list of 13, including `review` for Grok
- Context: `review` was `pi_core` but `agents_visible=0`
- Choice: `agents_visible=1` for the whole keep-list
- Rejected options: leave review hidden from Grok
- Rationale: Grok is the highest-volume runtime in the 30d corpus
- Consequences: `~/.agents/skills/review` is linked

### `cross_harness=0` on demoted Pi skills
- Context: installer linked `cross_harness` into Claude/Codex even when not Grok-visible
- Choice: zero cross-harness Pi skills
- Rejected options: only flipping `pi_core`/`agents_visible`
- Rationale: otherwise ui.sh/suites stay on Claude/Codex menus
- Consequences: Claude CSS skills remain via `claude/scopes/shared/skills/`

### Empty array sentinel
- Context: bash 3 + `set -u` treats empty `arr[@]` as unbound
- Choice: initialize `CROSS_HARNESS_PI_SKILLS=("")` and skip empty names
- Rejected options: leave the crash
- Rationale: same pattern already used in `check-fix-symlinks.sh` when the catalog is missing
- Consequences: one skipped empty iteration; deploy/fix-links smokes pass

## Accepted Drift
- Original plan/spec: Slice 2 file list did not name README or installer empty-array guards
- Implemented reality: README `/plan-implement` example no longer mandates suite-router; three scripts guard empty `cross_harness`
- Why accepted: without those, spec and CI would contradict the new flags

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: all groups PASS (15 core checks; no )
- command: `scripts/router-eval --min-accuracy 1 --require-alignment`
  - result: 53/53, accuracy 1, alignment_rate 1
- command: `bash tests/dual-runtime-guard-matrix-smoke.sh`
  - result: ok
- command: `bash tests/deploy-agent-workflow-smoke.sh`
  - result: ok after empty-array fix
- command: `bash tests/fix-links-smoke.sh`
  - result: ok
- command: `bash tests/workflow-docs-smoke.sh`
  - result: ok
- command: `cd pi && bun run verify:skills`
  - result: Verified 79 skill hashes
- command: `awk` keep-list
  - result: 13 `pi_core` names identical to 13 `agents_visible`; `cross_harness` empty

## Follow-up State
- Remaining risks: leftover home symlinks for demoted skills until `scripts/install.sh` or `check-fix-symlinks --fix`; Claude work CSS still in shared scope
- Parking lot: Slice 3 (thin adapters), `bff-ticket-loop` archive, Claude-only command trim
- Superseded docs/specs: `docs/workflow-guide.md` §7 council table; `workflow/spec.md` mandatory suite-router paragraph
- Next links: `workflow/spec.md`, `workflow/runtime/skill-surface.tsv`, `workflow/agent-quick-card.md`
