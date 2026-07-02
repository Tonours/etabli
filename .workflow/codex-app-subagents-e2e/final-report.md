# Final Report: Codex App subagents e2e

## Outcome

Completed. The current Codex App runtime exposes `multi_agent_v1`, and a real bounded read-only subagent packet completed and was closed. Contract, docs, and focused/broad smoke tests are aligned.

## Accepted Results

- Accepted `multi_agent_v1` as confirmed evidence for this Codex App runtime only.
- Accepted subagent `019f252a-d4bc-7b62-88df-f1728f5282a8` / `Wegener` as the real runtime proof packet.
- Accepted the subagent's finding that Codex delegation is conditional on runner availability and bounded packet ownership.
- Accepted the subagent's finding that no-runner fallback is simulated packet notes.
- Accepted the subagent's finding that Task* is documented as Pi-only, not Codex-native.

## Rejected Results

- Rejected treating Codex App subagents as Pi Task* tools.
- Rejected treating this runtime proof as a universal guarantee for all Codex surfaces.
- Rejected creating user-owned Codex threads for this setup.

## Conflicts Resolved

None so far.

## Verification Evidence

- `multi_agent_v1.spawn_agent` created agent `019f252a-d4bc-7b62-88df-f1728f5282a8` / `Wegener`.
- `multi_agent_v1.close_agent` returned the completed status for `Wegener`.
- Subagent result was checked against local files before integration.
- `bash tests/workflow-docs-smoke.sh` passed.
- `bash tests/codex-organization-smoke.sh` passed.
- `python3 /Users/tonours/.codex/skills/codex-dynamic-workflows/scripts/verify_workflow.py .workflow/codex-app-subagents-e2e` passed.
- `git diff --check` passed.
- `scripts/deploy-codex --dry-run` found conflicts in three existing live copy files, so `--apply` was not run. This is not blocking for the active Codex App rule because `~/.codex/AGENTS.md` is already a symlink to `codex/AGENTS.md` and contains the `multi_agent_v1` rules.
- `bash tests/workflow-scaffold-smoke.sh` passed.
- `bash tests/claude-hooks-smoke.sh` passed.
- `bun test pi/extensions/__tests__/` passed with 165 tests.
- `bash tests/workflow-autonomous-plan-loop-smoke.sh` passed.

## Remaining Risks

- Runtime proof is scoped to this active Codex App environment.
- Live `scripts/deploy-codex --apply` was intentionally skipped because the live dry-run is not clean. The active `~/.codex/AGENTS.md` symlink already carries the core Codex App runner rule, but three older live copy files still need an explicit force/merge decision if full live Codex home sync is desired later.

## Reusable Follow-up

- Use `docs/codex-app-subagents.md` as the future operator recipe.
- Resolve the three live Codex copy conflicts before any future `scripts/deploy-codex --apply`.
