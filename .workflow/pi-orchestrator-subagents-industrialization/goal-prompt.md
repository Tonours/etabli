Goal:
/goal Industrialize the current Etabli workflow into equivalent Pi-native and Claude-native orchestration layers, verified by local tests, smoke fixtures, workflow artifacts, and evidence labels for every runtime claim. Preserve `workflow/spec.md` as the canonical contract while adding structured task-state handling for Pi, Claude parity through hooks/commands/shared contracts, capability checks for Pi/Claude/subagent primitives, bounded retry/error/fallback rules, acceptance evidence per step, focused tests, docs, and cleanup of clearly stale or duplicate workflow text. Use only local repo files and safe local commands; do not push, deploy, touch secrets, force-push, or revert unrelated existing changes. Between iterations, inspect the latest evidence, make the smallest defensible change, run the narrowest useful validation before broadening, and record any runtime-dependent claim as `confirmed`, `proxy_supported`, `blocked`, or `unknown`. If a 100% guarantee depends on a Pi or Claude primitive unavailable in this Codex shell, stop only for that slice with evidence, fallback behavior, remaining uncertainty, and the exact external check needed.

Why this is stronger:
- Outcome: Pi and Claude execute the same Etabli workflow contract where their runtimes support it.
- Evidence: focused Bun tests, Claude hook smoke tests, workflow smoke tests, `git diff --check`, and workflow artifact verification.
- Constraints: preserve current workflow semantics, existing user changes, branch isolation, and no external/destructive actions.
- Scope: `workflow/spec.md`, `workflow/skills/`, `pi/extensions/`, `pi/skills/`, `claude/commands/`, `claude/hooks/`, docs, tests, and `.workflow/pi-orchestrator-subagents-industrialization/`.
- Iteration: after each failed or incomplete check, inspect evidence, fix the smallest bounded slice, and rerun the narrowest relevant check.
- Stop condition: completion only when local evidence proves the contract, or a runtime guarantee is explicitly labeled with blocker, fallback, and next verification step.

Assumptions:
- Claude parity means equivalent workflow behavior via available Claude hooks/commands, not inventing a Claude Task* primitive if none exists locally.
- `100%` means 100% of locally verifiable guarantees, with runtime-dependent claims labeled honestly.

Missing inputs:
- None for local implementation. Live Pi/Claude runtime checks may require a separate manual/runtime session if binaries or primitives are unavailable here.
