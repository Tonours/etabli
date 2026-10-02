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

Backend selection prefers `lockf`, then `flock`, then `shlock`, and fails
if none is available; `WORKFLOW_EVENT_LOCK_BACKEND` can select a backend.
For lockf/flock, admission checks the actual trusted system executable,
parent name/arguments, a descriptor and a separate contention probe.
`lockf` requires `-t 5 /dev/fd/9` and the canonical run directory;
`flock` requires `-w 5 <absolute events.lock path>`, without a cwd check.
Descriptor proof accepts any parent FD 0–9 under `/proc`, checking the open
file with `-ef`; the fallback matches a pathname reported by `lsof` with `-ef`.
The fallback does not attest the old open inode after pathname replacement.
The probe treats acquisition failure as lock evidence, including other errors.
Name and arguments can use inherited `WORKFLOW_PARENT_COMMAND` when
`WORKFLOW_PARENT_PID` matches; other probes use fixed system binaries
and available `/proc` or `lsof`, not caller-controlled `PATH` helpers.
The native admission proof is cached for the commit pass; no continuous
descriptor, inode or contention recheck occurs before append.
`shlock` runs in the writer process and checks its own PID-file at admission
and again at commit; it has no native-parent or descriptor proof.
Descriptor number alone gives no authority; native checks work together.
This is a cooperative integrity boundary, not protection against a same-UID
actor mutating files or processes between admission and append.
