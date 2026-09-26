# Recurring Run Contract

Shared contract for one bounded execution of recurring audits, reports,
maintenance, monitors, checkpoints, or collection jobs. A scheduler may trigger
the run, but this contract owns only the run itself.

## Required Inputs

Resolve before acting:

- objective and source of truth;
- cadence and stable run key;
- scope and allowed side effects;
- previous-run memory or explicit `unavailable` state;
- current-state evidence and validation command;
- attempt/action cap and stop conditions.

Do not infer success from a missing, stale, or unreadable previous-run record.
Classify it as `unknown` and continue only when a safe current baseline can be
collected.

## Run Sequence

1. Read the run's memory first when it exists. Treat it as a hint until current
   evidence confirms it.
2. Collect the current source-of-truth snapshot inside the declared scope.
3. Compare current and previous fingerprints. Compute a delta before choosing
   any action.
4. If the relevant state did not change, validate that conclusion and finish as
   `no_op`; do not repeat prior writes or manufacture findings.
5. If state changed, execute each authorized action at most once for this run
   key. Keep retries inside the declared cap and record failed hypotheses.
6. Run the named verifier against the final state. A completed command is not a
   successful outcome without verifier evidence.
7. Update recurring-run memory only after validation and before the final
   report. Store aggregates, fingerprints, decisions, and next checks—not raw
   secrets, conversations, credentials, or volatile logs.

## Idempotence Contract

- Use a stable run key such as `<routine>:<period-or-source-version>`.
- Derive planned actions from the current delta, not from elapsed time alone.
- Before a write, prove the same action was not already applied for this run
  key or current source version.
- Re-running against the same verified state must yield the same result and no
  additional side effect.
- Partial or failed runs must name which actions are safe to retry and which
  must not be repeated.

## Permissions

Recurring does not mean pre-authorized. Commit, push, deploy, merge, post,
delete, spend, production mutation, secret access, and external writes require
the same explicit authority as an interactive run. Never widen permissions to
make an unattended run finish.

## Result

Return a compact result with:

- `status`: `completed`, `no_op`, `partial`, `blocked`, or `unknown`;
- `run_key` and evidence window;
- previous and current fingerprints, or why either is unavailable;
- delta and actions attempted exactly once;
- validation evidence;
- memory update status;
- blocker, uncertainty, next check, and do-not-redo items.

Stop after success, a verified no-op, the action cap, repeated no-progress, a
permission/safety boundary, or required user input.
