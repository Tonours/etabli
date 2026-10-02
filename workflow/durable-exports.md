# Durable workflow exports

On-demand identity and lock contract for the canonical workflow event writer;
agent-facing event types remain in `workflow/events.md`.

Native `pi/durable` issues routes via CLI; its standalone review uses canonical T/D/F.

After structural validation, optional `detail.export_id` is checked under
that lock against the exact original request. When product enrichment changes
an exported detail, the CLI alone retains `export_source_detail`; the stored
top-level product evidence remains authoritative. Callers cannot supply this
reserved marker, including internal/prevalidated lock entrypoints. Its schema
binds the ID and all non-product fields, validates the original event payload
and refuses redundant, nested or malformed markers. Legacy receipts retain
exact detail comparison. Repeat admission precedes re-evaluation of the plan
and hash precondition, so an already committed request can recover its ACK.
The original request is private ledger evidence and never a mobile projection.

The existing event/run and exact original detail are compared under the lock.
One identical export returns
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
