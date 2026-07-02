# P2 real e2e packet

## Objective

Prove that a real Pi `TaskExecute` call can spawn a tracked subagent and complete the Etabli archive/delete contract.

## Scenario

Run a temporary scaffolded workflow project. Restrict parent Pi to `TaskCreate`, `TaskList`, `TaskExecute`, `TaskOutput`, and `TaskGet`. Create one worker task. The worker writes a proof file, creates a plan archive, and deletes root `PLAN.md`.

## Acceptance

- Output includes `subagents:rpc:spawn`, `spawn:call`, or `spawn:ok`.
- `subagent-proof.txt` contains exactly `SUBAGENT_E2E_OK`.
- `docs/plan/20260702-pi-task-subagent-e2e.md` exists and contains `Status: implemented`.
- Root `PLAN.md` is gone.
