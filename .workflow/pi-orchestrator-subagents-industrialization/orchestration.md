# Orchestration: Pi orchestrator subagents industrialization

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.

## Branching Rules

- If structured task data is available and valid, use it as the source of truth.
- If structured task data is unavailable but TaskList text is parseable, continue with `proxy_supported` confidence and report the fallback.
- If neither structured nor text task evidence is parseable after a Task* call, continue once to recover context, then stop as `blocked` or `unknown` based on evidence.
- If subagent capability is not explicitly detected, keep orchestration local and do not call TaskExecute.
- If Claude lacks an equivalent Task* or subagent primitive, enforce the same workflow through hooks, commands, `/goal` guidance, fixtures, and explicit fallback labels.
- If a subagent run fails, retry only for classified retryable failures and only within the bounded retry limit.
- If validation evidence is absent, create or continue validation work before final completion.
- If `workflow/spec.md` and implementation behavior conflict, `workflow/spec.md` wins unless the plan is refreshed.

## Packet Prompts

### P1-task-state

Objective: inspect and harden `pi/extensions/lib/tasks-till-done-runtime.ts` plus focused tests so orchestration can prefer structured task state over `TaskList` text when available.

Expected output: changed runtime/tests, accepted/rejected assumptions, validation commands.

### P2-capability

Objective: verify local package/runtime evidence for `@tintinweb/pi-tasks`, `pi-subagents`, Claude hooks/commands, repo settings, and unavailable live runtime binaries; translate that into deterministic capability status behavior.

Expected output: evidence map with labels `confirmed`, `proxy_supported`, `blocked`, `unknown`, and implementation recommendations.

### P3-claude-parity

Objective: implement the same orchestration semantics for Claude surfaces using `claude/commands/`, `claude/hooks/`, shared contracts, and smoke fixtures without inventing runtime features that Claude does not expose.

Expected output: changed Claude hook/command/shared-contract files, parity notes, and smoke-test evidence.

### P4-tests-docs

Objective: align docs and smoke tests with the new orchestration behavior without broad rewrites.

Expected output: focused doc/test updates and stale-text cleanup candidates.

### P5-review

Objective: review the integrated diff for regressions, overclaiming, unbounded automation, and workflow-spec drift.

Expected output: findings first, then pass/fail recommendation.

## Completion Audit

- Check branch is still `feature/pi-orchestrator-subagents-industrialization`.
- Check no unrelated user changes were reverted.
- Check all touched behavior is covered by focused tests.
- Check docs avoid claiming a live Pi/Claude/subagent guarantee that was not executed.
- Check final report lists confirmed, proxy-supported, blocked, and unknown evidence.
