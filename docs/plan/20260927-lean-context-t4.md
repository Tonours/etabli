# Implemented: Lean context T4 — governed skill listing, deduplicated resident rules, slimmer hot chains, stable Pi prompt, fail-closed rtk

## Metadata
- Archived: 2026-09-27
- Source plan: `PLAN.md` — Lean context T4 — faire plus avec moins sur les surfaces de contexte Claude et Pi, mesuré avant/après
- Source plan SHA-256: `45820407719bd63db3e1ff570f915b205fcd79bf3dda33ff6f21a23efcdaa359`
- Status: IMPLEMENTED
- Commit / branch: `refactor/lean-context-t4`, stacked on `feat/etabli-audit-t9` (base `main` at `4d6fd5e`); not pushed
- Workflow initiative: `lean-context-t4`, `lean-context-t4-review` (both blocked, budget spent), `lean-context-t4-review2` and `-review3` (blocked after F1), `lean-context-t4-review4` (completed at F2)

## Outcome
- L1 (skills): personal Claude skills are governed in the live `settings.json` layer, set to `user-invocable-only` by `--fix` (never `off`), without touching the tracked profile map. `deploy --apply` is idempotent (no new `.bak`). Model-facing listing: 16 482 → 3 651 chars.
- L2 (resident rules): the shared rules have one source. `claude/CLAUDE.md` imports `pi/AGENTS.md` through its deployed link `~/.pi/agent/AGENTS.md`, and `claude/RTK.md` counts in the always-on surface. Always-on: 13 493 (plus RTK.md) → 11 789 chars. Claude memory: 7 548 chars ≤ 7 636.
- L3 (hot chains): the T/D/F round machine and long-loop discipline moved to the cold files `workflow/skills/review-rounds.md` and `workflow/skills/long-loop.md`; `events-validator.md` became conditional.

  | Chain | Before | After (chars) |
  | --- | --- | --- |
  | implement | 56 125 | 48 723 |
  | plan-implement | 61 488 | 54 086 |
  | ship (with the PR contract as a required read) | 90 150 | 80 905 |

- L4 (Pi router): the route contract arrives as a `message` (`etabli-route-contract`, `display: false`) instead of a `systemPrompt` mutation. System-prompt mutations: 77 → 0 out of 230 turns.
- L5 (rtk): Claude `rtk-guard` and the Pi rewriter share `workflow/runtime/rtk-data-flow.mjs`, a structural allow-list: only a single simple command, optionally piped into `head`/`tail`/`cat` with plain options, is compacted. Only exact `[path/]rtk [options] hook claude [options]` hook lines are retired; any other rtk-mentioning Bash PreToolUse hook fails `claude-hooks-check`.

  | Measure | Claude | Pi |
  | --- | --- | --- |
  | data commands rewritten | 0/10 | 0/10 |
  | display commands rewritten | 6/6 | 5/6 |
  | unsupported syntax rewritten | 0/17 | 0/34, 0 runner calls |

- Benchmark: `tests/fixtures/lean-bench/` (versioned, not wired as a check).
- Baseline: `workflow/runtime/token-bench-baseline.json` updated to the T4 state.

## Context
- `pi/node_modules/@earendil-works/pi-coding-agent/dist/core/extensions/types.d.ts:845-846`: `BeforeAgentStartEventResult.message` is the documented channel.
- `rtk rewrite` exits 3 when it rewrites; before T4, Pi treated that as an error, so 0 rewrites happened.
- Pi runs each command in a fresh `bash -c` (`pi-coding-agent/dist/core/tools/bash.js:54`).
- Claude Code starts a separate process per command, but re-applies the user shell snapshot (https://code.claude.com/docs/en/tools-reference#what-persists-between-commands).

## Decisions
### Structural allow-list for rtk instead of a denylist
- Context: 14 review rounds found new shell bypasses of the denylist, one after another: quotes, `$'…'`, functions, `LESS`, prefixes, `if`, `2>&1`, U+00A0, `${…}`, comments, continuations, case variants.
- Choice:
  - compact only a single simple command;
  - reject compound operators, newlines, unquoted backslashes, `${`/`$[`, non-ASCII blanks, prefixes, assignments and state commands;
  - apply the same structural approach to hook retirement (one closed regex).
- Rejected options: keep extending the denylist (did not converge).
- Rationale: closed by construction; each Bash call starts from a fresh shell.
- Consequences: `cd x && git diff`, prefixed commands, and `less`/`more` pipes are no longer compacted.

### Governance of personal skills in the live layer
- Context: adding them to the tracked map would break the `~/.claude` pass.
- Choice: live-only keys, `on` refused, `--fix` sets `user-invocable-only`; `off`/`name-only` chosen by the user stay accepted.
- Rationale: native user states (R2 F3).

## Accepted Drift
- Original plan/spec: `tests/deploy-agent-workflow-smoke.sh` updated for the FAIL/WARN branch.
- Implemented reality: unchanged.
  - A deploy against a disposable HOME repointed the repo's `pi/extensions/node_modules` (repaired).
  - A hermetic copy of the repo is blocked by the pinned-keeper invariant.
  - Coverage comes from the live `deploy --apply` runs and `tests/claude-skill-load-check-smoke.sh`.
- Why accepted: a test that mutates the repo is worse than no test.
- Original plan/spec: AC3 targets set before the demotions, and AC6 measured on paid runs.
- Implemented reality: AC3 uses measured values (ceilings ×1.03 as the ratchet barrier), and AC6 uses the deterministic `/context` A/B.
- Why accepted: recorded demotions.

## Validation Evidence
- command: `scripts/verify-agentic-infra full|core|shell-docs|pi`
  - result: 81/81, 27/27, 75/75, 6/6; RUN labels equal the manifest selection
- command: `bun test pi/extensions/__tests__/`
  - result: 357/357
- command: lean-bench
  - result:
    - `bench.py`: listing 3 651, load-check exit 0, unsupported 0/17 with 0 outputs and 0 errors, negative controls detected;
    - `pi-rtk.ts`: 0/34, 0 errors, 0 calls, negative control detected;
    - `pi-router.ts`: 0 mutations out of 230.
- command: `scripts/claude-hooks-check`, both `claude-skill-load-check` roots, `scripts/router-eval`, `scripts/workflow-router-parity`, `scripts/check-fix-symlinks.sh`, `scripts/workflow-context-budget`, `scripts/token-bench --check`
  - result: all ok
- Paid runs from the first T4 run (kept in `/tmp/lean-bench/`): `/context` A/B shows Skills 9.9 k → 9 k and 79 → 34 User entries; Pi 10 878 < 11 149.
- Reviews: fresh-context Logic and Spec hunters. Cross-family Codex `gpt-6-astra`, effective model checked every pass, across plan passes and code rounds of five runs. Final F2: Logic GO, Spec GO, Codex GO.

## Follow-up State
- Remaining risks:
  - redefinitions of `head`/`tail`/`cat` in the Claude shell snapshot, `CLAUDE_ENV_FILE` or `BASH_ENV` are not detected (checked absent on 2026-09-27);
  - runtime-built rtk invocations (`$'…'`, command substitution) stay outside the bounded hook rule;
  - Pi still bypasses a pipe on its first sighting.
- Parking lot:
  - share the three shell scanners (`shellWords`, `splitPipelineParts`, `maskQuoted`);
  - claude.ai connectors (−11 k tokens, user decision).
- Superseded docs/specs: `docs/plan/20260927-discarded-parked-t4-for-t9-audit.md` (parking record, removed).
- Next links: `docs/research/20260927-harness-practices-audit.md`.
