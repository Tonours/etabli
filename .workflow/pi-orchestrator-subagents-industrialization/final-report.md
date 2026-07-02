# Final Report: Pi orchestrator subagents industrialization

## Outcome

Implemented the orchestration hardening as guarded Pi/Claude workflow parity, with a real local Pi `TaskExecute` subagent e2e now covering the previous runtime gap.

The reusable goal prompt now asks for equivalent Pi-native and Claude-native orchestration, while forcing every runtime claim into `confirmed`, `proxy_supported`, `blocked`, or `unknown`. Pi gets structured Task* state handling where available. Claude gets equivalent workflow guidance through hooks, commands, and `/goal`, with Task* explicitly marked Pi-only.

## Accepted Results

- Pi `tasks-till-done` now prefers structured task details over `TaskList` text and labels text parsing as fallback evidence.
- Pi runtime capability failures such as unavailable `TaskExecute` tracking stop visibly instead of looping; when `@tintinweb/pi-subagents@0.13.0` is installed, the real `taskexecute-subagent-workflow` scenario confirms tracked subagent execution locally.
- Claude route context now carries plan-chain, runtime-loop, capability-label, and completion-evidence guidance aligned with the shared workflow contract.
- Shared orchestration guidance was added under `workflow/skills/orchestration.md` and deployed through the workflow scaffold path.
- The goal prompt in `.workflow/pi-orchestrator-subagents-industrialization/goal-prompt.md` now targets Pi and Claude parity explicitly.
- Final review finding accepted: generic cleanup no longer satisfies root `PLAN.md` cleanup evidence.

## Rejected Results

- Rejected a universal "100%" guarantee for Pi-native subagents. Accepted the narrower proven claim: `TaskExecute` works on this local Pi `0.80.2` runtime with `@tintinweb/pi-subagents@0.13.0` and the real e2e passing.
- Rejected treating the Codex subagent runner as proof of Pi or Claude native subagent stability.
- Rejected inventing a Claude Task* state primitive. Claude parity is documented as `proxy_supported` through `/goal`, commands, and hooks.

## Conflicts Resolved

- The user's requested "100%" guarantee conflicts with current runtime evidence. The implemented resolution is deterministic capability gating plus explicit status labels.
- Pi and Claude now share the same workflow semantics, but use different runtime adapters because their exposed primitives differ.

## Verification Evidence

- `bun test pi/extensions/__tests__/` -> 154 pass, 0 fail.
- `bash tests/workflow-autonomous-plan-loop-smoke.sh` -> ok.
- `bash tests/workflow-docs-smoke.sh` -> ok.
- `bash tests/workflow-scaffold-smoke.sh` -> ok.
- `bash tests/claude-hooks-smoke.sh` -> ok.
- `bash tests/codex-organization-smoke.sh` -> ok.
- `node --check claude/hooks/workflow-router-lib.mjs && node --check claude/hooks/workflow-router.mjs && node --check claude/hooks/plan-ready-guard.mjs` -> ok.
- `git diff --check` -> clean.
- `python3 /Users/tonours/.codex/skills/codex-dynamic-workflows/scripts/verify_workflow.py .workflow/pi-orchestrator-subagents-industrialization` -> passed.
- `RUN_REAL_AGENT_SCENARIOS=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh` -> passed with real Pi `0.80.2`, Claude Code `2.1.196`, and `taskexecute-subagent-workflow`.

## Remaining Risks

- `TaskExecute` tracked subagent execution is confirmed only for this local runtime and package set; machines without `@tintinweb/pi-subagents` still take the blocked capability path.
- Repo tests prove Claude hook behavior, but not live user activation in `~/.claude/settings.json`.
- The worktree contains pre-existing changes outside this iteration; they were preserved and not reverted.

## Reusable Follow-up

- Keep `RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh` as the regression gate before changing Task* or subagent packages.
- If Claude activation is the next target, verify command symlinks and merged workflow hooks under the live `~/.claude` config.
