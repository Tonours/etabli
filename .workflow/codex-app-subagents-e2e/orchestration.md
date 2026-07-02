# Orchestration: Codex App subagents e2e

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.
- Use real Codex subagents only when `multi_agent_v1` is exposed.
- Close spawned agents after integrating their result.
- If the runner is absent, simulate packets and label the runtime claim `blocked`.

## Branching Rules

- Runner exposed: spawn exactly one read-only verification subagent and document `confirmed` for this runtime.
- Runner absent: do not spawn; document fallback packets and stop with blocked evidence.
- Tests fail: fix the smallest related doc/contract mismatch, then rerun focused checks.
- Deployment: run `scripts/deploy-codex --dry-run` only if live deployment evidence is needed; do not apply unless necessary and safe.

## Packet Prompts

- `P1-codex-runtime-proof`: inspect Codex workflow files and report whether delegation is conditional on a supported runner, what fallback is prescribed, and whether Task* is Pi-only.
- `P2-contract-docs`: update Codex contracts, shared orchestration contract, README/Codex docs, and smoke assertions.
- `P3-validation-commit`: run checks, inspect staged diff, commit locally.

## Completion Audit

- `.workflow/codex-app-subagents-e2e` verifies with the workflow verifier.
- Real subagent result exists with agent id/nickname and close status.
- Docs/tests mention `multi_agent_v1.spawn_agent` and simulated packet fallback.
- No text claims Codex has Pi Task*.
- Worktree is clean after local commit.
