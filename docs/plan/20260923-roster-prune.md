# Implemented: superseded Pi roster entries pruned

## Metadata
- Archived: 2026-09-23
- Source plan: `PLAN.md` — prune superseded Pi roster entries
- Source plan SHA-256: `add85779c21d7a4f4836757eb9c9aa884e8db646940d720afb33d1c1ddd6a00f`
- Status: IMPLEMENTED
- Commit / branch: `main`
- Workflow initiative: `roster-prune`

## Outcome
- Rule: prune `provider/X-vN[-suffix]` only when the same provider lists the same line and suffix at a higher version.
- Pruned:
  - `zai/glm-5.2` (successor `glm-5.3`);
  - `zai/glm-5.2-highspeed`, replaced by `zai/glm-5.3-highspeed`;
  - `openai-codex/gpt-5.6-sol` and `gpt-5.6-luna` (successors `gpt-6-sol` and `gpt-6-luna`);
  - `xai/grok-4.5` (successor `grok-4.7`);
  - `opencode-go/qwen3.7-max` (successor `qwen3.8-max`).
- Kept (no same-suffix successor): `gpt-5.5`, `glm-5-turbo`, `gpt-5.6-terra`, `gpt-5.3-codex-spark`, `cursor/gpt-5.6-*`, `qwen3.7-plus`, `mimo-v2.5`, `composer-2.5`.
- Both sync legacy sets carry the pruned ids. The local Pi settings are converged (backup `settings.json.bak.20260923-131119`), and a second run is a no-op.
- The tracked-model probe in `install-main.sh` and `deploy-agent-workflow-smoke.sh` moved to `zai/glm-5.3`. The deploy smoke now asserts that retired ids are removed.

## Context
- The sync filters legacy ids and then re-adds tracked ids (`pi-agent-settings-sync.mjs:123-132`), so the tracked removal and the legacy additions must ship together to stay idempotent.

## Decisions
### Same-suffix successor rule
- Context: variant equivalence was ambiguous (plan adversary BLOCK).
- Choice: an exact line-and-suffix match at the same provider.
- Rejected options: treating `gpt-6-astra` as the successor of `gpt-5.5`.
- Consequences: `gpt-5.5` stays until an unsuffixed newer id exists.

## Accepted Drift
- Original plan/spec: 7 prunes, including `gpt-5.5`.
- Implemented reality: 6 prunes, plus a new deploy-removal assertion.
- Why accepted: rule consistency and a check that bites.

## Validation Evidence
- `settings-consistency` 6/6 (red first).
- `deploy-agent-workflow-smoke`: pass. It fails with the legacy additions reverted and passes with them.
- `workflow-docs-smoke`: pass.
- Catalogue check: 0 missing.
- `env -u TYPESAFE_API_KEY scripts/verify-agentic-infra core`: 22/22.
- Reviews, all same-family: the plan adversary returned BLOCK, then GO WITH NOTES after revision. The ledger records an erroneous early GO WITH NOTES row, followed by an explicit correction row. Code review GO; code adversary GO WITH NOTES.
- Event ledger `.workflow/roster-prune/events.jsonl`, validated with `--profile autonomous-completed`.

## Follow-up State
- Remaining risks: a machine whose default model is a pruned id keeps the default outside the cycling list (install mode does not keep legacy defaults); this machine uses `zai/glm-5.3`.
- Parking lot: none.
- Superseded docs/specs: none.
- Next links: `docs/plan/20260923-model-currency-sweep.md`.
