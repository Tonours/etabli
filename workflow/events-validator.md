# Workflow Events Validator Internals

Validator and writer internals for `.workflow/<slug>/events.jsonl`; the
agent-facing contract is `workflow/events.md`.

## Writer integrity

The writer validates the ledger and re-checks terminal state while the lock is
held.
After structural validation, optional `detail.export_id` is checked under
that lock against the existing event/run/detail. One identical export returns
the original success before terminal/round checks; a different payload is a
collision. The batch validator also rejects duplicate v2 export identities.
Native Durable coordination acknowledges an export only after this operation.
Writer timestamps are excluded from equality. Identity does not reset rounds
or authorize rewriting history; it reconciles append-before-acknowledgement
crashes. Native standalone reviews use `contract_path: "pi/durable"` with the
existing T/D/F limits.

Native internal append execution proves that its actual `lockf`/`flock` parent
is the trusted system executable and was invoked on the fixed descriptor `9`
from the canonical run directory. That descriptor must resolve to the current
canonical `events.lock` inode, which is then separately proven locked.
Executable, directory, arguments, descriptor, and lock state are read only
through fixed system binaries plus `/proc` on Linux or `lsof` on macOS;
caller-controlled `PATH` helpers are not authoritative. Descriptor locking
keeps the lock file and preserves kernel lock ordering. Merely opening the
canonical file on another descriptor, replacing its pathname, placing
`_append-locked` beneath an unrelated lock process, or minting a caller-owned
JSON marker confers no authority; missing process proof fails closed. The
writer rechecks contention and FD-to-inode identity immediately before the
append syscall. This is a cooperative-writer integrity boundary, not a security
boundary against a same-UID actor that can mutate files or processes inside
that final syscall interval.

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
