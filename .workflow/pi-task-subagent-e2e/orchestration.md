# Orchestration: Pi Task subagent e2e

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.
- Distinguish package-managed Pi extension loading from explicit `--extension` fallback to avoid duplicate tool registration.

## Branching Rules

- Stay on `feature/pi-orchestrator-subagents-industrialization`.
- Preserve unrelated existing worktree changes.
- Do not commit or push unless explicitly requested.

## Packet Prompts

- `P1-runtime-config`: inspect tracked and live Pi settings, identify the exact provider needed by `@tintinweb/pi-tasks`, and patch tracked settings plus installer sync.
- `P2-real-e2e`: run a temporary project where parent Pi is restricted to Task* tools, create one worker task, execute it, block for output, then verify archive/delete/proof files on disk.
- `P3-docs-evidence`: update README, Pi cheatsheet, and workflow reports with the current evidence and remaining caveats.

## Completion Audit

- `TaskExecute` evidence must include `subagents:rpc:spawn`, `spawn:ok`, or `spawn:call`.
- `subagent-proof.txt` must contain exactly `SUBAGENT_E2E_OK`.
- `docs/plan/20260702-pi-task-subagent-e2e.md` must exist and contain `Status: implemented`.
- Root `PLAN.md` must be absent in the temporary project after the run.
- Full real scenario suite must pass with both Pi and Claude enabled.
