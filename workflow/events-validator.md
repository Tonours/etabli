# Workflow Events Validator Internals

Validator and writer internals for `.workflow/<slug>/events.jsonl`; the
agent-facing contract is `workflow/events.md`.

## Writer integrity

The writer validates the ledger and re-checks terminal state while the lock is
held.
Durable export identity, reserved enrichment metadata and native lock proof:
`workflow/durable-exports.md`.

For a schema-v2 run that has ever declared the `plan-implement` route,
`completed` is also preflighted while holding that lock: the writer validates
an exact temporary candidate with `--profile autonomous-completed` before it
appends the same terminal line. Missing evidence therefore leaves the canonical
ledger and active-run pointer untouched. Schema-v1 and non-`plan-implement`
ledgers retain structural completion compatibility.

`--expected-ledger-sha256 HASH` on `append` compares the current ledger bytes
under the same writer lock before appending. An existing matching `export_id`
is reconciled first, so a crash between append and acknowledgement remains
recoverable. A pending terminal intent cannot borrow evidence added later.
`check-completion <slug> <json-detail>` checks an autonomous completion
candidate without appending it; the actual append still repeats the locked
preflight. This allows a native mission to wait for missing evidence without
creating a terminal intent bound to incomplete prerequisites.

## Writers and recovery

Before a run relies on active-run selection, select it with
`scripts/workflow-event activate <slug>`; the runtime then inspects only that <!-- etabli-only -->
ledger. Without a pointer, the compatibility fallback considers only valid
non-terminal ledgers; an invalid historical record that already contains a
terminal event is not an active run, while an invalid non-terminal candidate
still fails closed. Terminal append clears the matching pointer.

The Pi/Codex harness extensions are the single named exception to CLI-only
appends: their synchronous hot paths append schema_version 2 envelopes
directly (same shape the CLI would accept); a shared serialized writer is a
parked follow-up. Every line, whatever the writer, must validate. New appends
are serialized behind a five-second `lockf`, `flock`, or `shlock` lock.
Tightening strict validation flips terminal history that predates the rule:
inventory such ledgers in `workflow/runtime/ledger-drift-grandfathered.json`
instead of rewriting them. A corrupt ledger goes through
`scripts/workflow-event recover <slug> <reason-code>`: it preserves the <!-- etabli-only -->
original as `events.invalid-*.jsonl` and writes a blocked replacement instead
of deleting history; without that script (scaffolded project), one equivalent
validated append is acceptable.

## Retired types

Retired types stay readable in history: validation accepts their existing lines
without checking their detail, and `append` refuses them with `retired event
type`. The list lives in `RETIRED_EVENTS` (`scripts/workflow-event`),
`retired_events` (`scripts/lib/workflow-event-detail.jq`) and
`RETIRED_WORKFLOW_EVENTS` (`scripts/lib/workflow-events.mjs`); keep the three in <!-- etabli-only -->
sync.
