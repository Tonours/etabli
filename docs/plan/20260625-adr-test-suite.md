# Implemented: test suite for the ADR plugin

## Metadata
- Archived: 2026-06-25
- Source plan: Tests for the ADR plugin — deterministic hook smoke (local) + claude -p end-to-end for /adr
- Status: IMPLEMENTED and validated (all checks green, e2e run for real)
- Commit / branch: not committed yet
- Companion archive: `20260625-adr-capture-system.md` (the plugin itself)

## Outcome
Two test layers, one per component, matched to its nature:
- `tests/adr-hook-smoke.sh` — deterministic smoke for `detect-adr-signal.mjs`. 6 cases, each in a throwaway git repo (the hook reads `git status --porcelain` of the cwd, so a real repo is needed — distinct from the sed-on-JSON fixtures of `claude-hooks-smoke.sh`). Offline, < 1s, local (not in CI per decision).
- `tests/adr-skill-e2e.sh` — end-to-end for the `/adr` skill via `claude -p`. Out of CI, manual, ~1 USD/run, OAuth required.

## Files
- `tests/adr-hook-smoke.sh` — created. Dedicated script, not an extension of `claude-hooks-smoke.sh` (different fixture mechanism: real git repo vs JSON sed).
- `tests/adr-skill-e2e.sh` — created. `realpath` anti-stale guard on `~/.claude/skills/adr` (refuses to test a foreign/stale skill; creates a temp symlink to this repo and restores via trap). 3 `claude -p` runs with `--output-format json --max-turns --max-budget-usd`.
- `claude/skills/adr/SKILL.md` — modified. Added a legitimate pre-approval clause to step 4 ("pre-approved, write directly" skips the wait, never the three-condition gate). This is what lets the write path run headless.

## Validation run (2026-06-25, all green)
Hook smoke (`bash tests/adr-hook-smoke.sh`): 6/6 PASS — no-signal, primary `last_assistant_message`, fallback transcript, non-structural→silent, missing-marker→silent, anti-noise (ADR present)→silent.
Existing `claude-hooks-smoke.sh`: still green (no regression).
Skill e2e (`bash tests/adr-skill-e2e.sh`, 3 real `claude -p` runs):
- B — trivial rename → refused, no ADR file written.
- A — real decision, pre-approved → `docs/adr/0001-*.md` + CLAUDE.md index created.
- A2 — second decision → `docs/adr/0002-*.md` + index updated in place (single START marker, no duplication).
Temp skill symlink cleaned up by the trap.

## Key decisions
- Hook = deterministic smoke (CI-safe shape, but kept local per Q3); skill = e2e claude -p, out of CI (LLM/cost/OAuth). Split by nature.
- Dedicated `tests/adr-hook-smoke.sh` rather than extending `claude-hooks-smoke.sh`: the hook needs a real git repo, a different mechanism from the pure-function router/guard fixtures.
- Approval point (Q2) settled as option C: test both refusal (deterministic-ish) and the full write path. Required a pre-approval clause in SKILL.md, framed as legitimate user behavior, not a test flag.
- `claude -p` inherits the interactive OAuth session (no `ANTHROPIC_API_KEY`); verified by a `say ok` probe (`is_error:false`, 0.23 USD). Hence no `--bare`.
- Bounds confirmed verbatim against `cli-reference.md:89-90`: `--max-turns`, `--max-budget-usd` (print-mode-only). No `--timeout` for `claude -p`.

## Follow-ups
- The ADR plugin + its tests are validated but NOT committed to git.
- The e2e test is manual and out of CI by design — run on demand, not in a loop.
- Bootstrap of existing Forest decisions remains a separate plan.
