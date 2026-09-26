# Workflow Events Validator Internals

Validator and writer internals for `.workflow/<slug>/events.jsonl`; the
agent-facing contract is `workflow/events.md`.

## Writer integrity

The writer validates the ledger and re-checks terminal state while the lock is
held.

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

## Retired types

Retired types stay readable in history: validation accepts their existing lines
without checking their detail, and `append` refuses them with `retired event
type`. The list lives in `RETIRED_EVENTS` (`scripts/workflow-event`),
`retired_events` (`scripts/lib/workflow-event-detail.jq`) and
`RETIRED_WORKFLOW_EVENTS` (`scripts/lib/workflow-events.mjs`); keep the three in <!-- etabli-only -->
sync.
