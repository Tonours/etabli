# Implemented: grok-4.7 in the harness evaluator and a project-wide model currency sweep

## Metadata
- Archived: 2026-09-23
- Source plan: `PLAN.md` — grok-4.7 in the harness evaluator, plus a project-wide model currency sweep
- Source plan SHA-256: `870076b78e7e904ecf0c4b097a5e36e527cc52d89ac3af2d6fa4a277c4bd4dc7`
- Status: IMPLEMENTED
- Commit / branch: `main`
- Workflow initiative: `model-currency-sweep`

## Outcome
- `scripts/lib/etabli-harness-eval.sh` `HARNESS_GROK_MODEL` changed from `grok-4.6` to `grok-4.7`.
  - The manifest `evaluator.sha256` was re-pinned to `9d1447d2…`; `evaluator.id` is unchanged (`binary-final-state-v1`).
  - The smoke assertion and `docs/harness-eval.md` were updated, with a note that receipts before and after are not comparable.
- `github-copilot/gpt-5.6-luna` changed to `github-copilot/gpt-6-luna`.
- The `pi-review-hunter-smoke` sample id changed to `cursor/claude-opus-5-5@300k`.
- Machine-local changes, not tracked:
  - `~/.claude/rules/claude-only-agents.md` forbidden namespaces widened to `opencode-go/`, `opencode/`, `github-copilot/` and non-Claude `cursor/`; `kimi-coding/` removed;
  - `~/.pi/agent/settings.json` synced in deploy mode: `kimi-coding/k3` removed, 15 current ids added.
- The sweep checked every live Pi id with a script: 0 are missing from `pi --list-models`.

## Context
- The model string feeds the grok cell's model-mismatch fail gate and each receipt's `model_requested`, so it is grading-relevant input and the re-pin is required.
- `frozen_public` means candidate-readable (`workflow/skills/skill-evaluation.md`). The v1 manifest is `schema_version: 1`, and there are 8 prior lib re-pins as precedent.
- Live model settings that are current and unchanged:
  - Claude agent aliases;
  - `pr-council-review` (`opus`, `gpt-6-astra`);
  - real-agent scenarios (`haiku`);
  - Pi default and harness Pi `zai/glm-5.3`;
  - `~/.codex/config.toml` `gpt-6-astra`.

## Decisions
### Re-pin v1 instead of cutting v2
- Context: the user asked for grok-4.7 in the evaluator now; plan C (v2 split) is not started.
- Choice: follow the repo's re-pin precedent and document the comparability break.
- Rejected options: a new evaluator id now (that is plan C's scope), or leaving grok-4.6.
- Consequences: Grok receipts form two series around 2026-09-23.

## Accepted Drift
- Original plan/spec: "grading unchanged".
- Implemented reality: grading logic is unchanged, but the requested-model value moves the mismatch gate and receipts (plan adversary).
- Why accepted: that is the correct description; the re-pin covers it.

## Validation Evidence
- `print-argv --runner grok`: `-m grok-4.7`.
- The lib sha equals the manifest sha.
- `settings-consistency` 6/6; the new assertion failed before the change.
- `pi-review-hunter-smoke` and `workflow-docs-smoke`: pass.
- `env -u TYPESAFE_API_KEY scripts/verify-agentic-infra core`: 22/22.
- `etabli-harness-eval-smoke` now passes its sha check and then stops at the known macOS 14 `jq` hermetic-PATH failure, as on `main`; Linux CI covers the rest.
- Reviews, all same-family: plan adversary GO WITH NOTES; Logic GO; Spec GO; code-diff adversary GO WITH NOTES.
- Event ledger `.workflow/model-currency-sweep/events.jsonl`, validated with `--profile autonomous-completed`.

## Follow-up State
- Remaining risks: new routes are catalogue-listed but not exercised live.
- Parking lot:
  - Cursor IDE Task model `claude-opus-5-thinking-high` (`review.md:34`, `pr-review.md:53`, `workflow-docs-smoke.sh:568`).
  - Optional pruning of older roster entries (glm-5.2*, glm-5-turbo, gpt-5.x, qwen3.7-*, mimo-v2.5, xai/grok-4.5).
  - Plan C: the v2 grading split and the hermetic `jq` fix.
- Superseded docs/specs: none.
- Next links: `docs/harness-eval.md`, `docs/plan/20260923-model-roster-refresh.md`.
