# Bounded Project Autonomy Envelope

Status: experimental and explicit opt-in; outside the core validation profile.

`workflow/templates/project-autonomy-envelope.json` declares the authority for
one explicitly authorized local project run. It is a restartable contract, not
an agent executor: `scripts/project-autonomy` only reads the envelope and run <!-- etabli-only -->
ledger, delegates typed-ledger validation to the existing read-only
`scripts/workflow-event validate` contract, then reports the next evidence
obligation. It never launches agents, runs an envelope verifier, edits a
project, applies a proposal, or writes externally.

## Required declaration

The versioned schema requires:

- one project ID and measurable goal;
- one bounded `run_id` that must match every typed v2 ledger event;
- explicit bounded allowed files and tools, plus forbidden actions (bare `**`
  is rejected);
- maximum iterations, duration, and at most eight improvement candidates;
- named checkpoints before a slice where human confirmation is required;
- fixed no-progress thresholds: two failures of one hypothesis or three red
  checks without a new diff;
- a named evaluation runner, final-state grader, frozen held-out surface, and
  `sealed_held_out: true`;
- ordered small slices, each with its own allowed files/tools and an inspectable
  verification command/evidence pair.

The envelope cannot grant permission outside the active workflow and runtime
guards. Its `forbidden_actions` should include any prohibited external writes,
pushes, pull requests, deploys, production or billing actions, secret access,
and obvault writes for the run.

## Controller transitions

Run the read-only controller with the exact ledger path:

```bash
scripts/project-autonomy --envelope path/to/envelope.json --events .workflow/run/events.jsonl
```

It reports only one transition:

- `plan_slice` when the next bounded slice has not been recorded as planned;
- `execute_slice` when that planned slice has a verifier contract but no
  completion evidence;
- `await_checkpoint` when the slice’s named checkpoint lacks an exact,
  authorized `human_checkpoint` event;
- `await_verification` when all slices are complete but the named final-state
  runner or successful grader metric is absent;
- `completion_ready` only after successful evaluation-run and final-state
  outcome evidence, with the sealed held-out surface still bound in the
  envelope;
- `stop` for a terminal event, `no_progress`, a cap, a denied checkpoint,
  unknown slice, failed final-state grade, or invalid declaration.

The normal READY-gated implementation workflow performs the reported work and
appends the typed `project_slice_*`, `human_checkpoint`, `validation_run`,
`outcome_metric`, `no_progress`, and terminal events. A final-state driver that
merely finishes is never enough for `completion_ready`.

## Evidence-first self-improvement

Use `scripts/workflow-retrospect --json` on independent ledger evidence. It is
read-only and can classify confirmed recurrence only as `recommendation`,
`router_fixture`, `contract_patch`, or `mechanical_check`. Every candidate stays
a proposal: implementation, if justified, begins through a new reviewed
`PLAN.md`, preserves the frozen graders and sealed held-out surface, and must
pass the ordinary validation path. Neither this controller nor the retrospect
can auto-apply a patch.

## Resume and stop

Resumption reads typed v2 `.workflow/<run_id>/events.jsonl` for the envelope’s
exact `run_id`, never chat history. Every `file_changed` event must occur while
one declared slice is active; global scope never authorizes an unowned mutation.
Preserve the failed-check or failed-hypothesis evidence after every attempt. When the two/three
no-progress threshold is reached, the controller returns `stop` with the
required `no_progress` detail; append that existing typed event with eliminated
hypotheses and stop `blocked`. Do not search for a ninth candidate or retry
without a new diff.

The `no-progress-equivalence` Jev profile may be used only as an explicitly
approved shadow comparison of two bounded attempts. It cannot increment an
attempt counter, append `no_progress`, or trigger this stop; exact ledger rules
remain authoritative.
