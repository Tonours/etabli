---
status: accepted
date: 2026-09-29
tags: [workflow, one-writer, lease, multihost, agents]
affected_components: [scripts/workflow-lease, workflow/spec.md, workflow/agent-quick-card.md, workflow/contract-details.md]
---

# Define write authority as a single integrator plus a per-worktree lease

## Context

The one-writer rule was a protocol: "the parent or one worker per step". Two
hosts (laptop and Mac mini) hold distinct checkouts, agents run each command
in a fresh bash process so no process holds a lock descriptor for a whole
session, and the workflow-event append lock only protects single-ledger
appends. Phase 0 of the agent-fleet roadmap (obvault) requires a mechanical
write-authority mechanism before any parallelism.

## Decision

1. The Mac mini is the single integrator for shared branches. Workers write
   in their own worktrees; integration (build + combined checks + promotion
   of the exact validated SHA) happens on the mini. Push authority stays a
   separate explicit consent.
2. `scripts/workflow-lease` provides a per-(repo, worktree) lease with TTL,
   reusing the workflow-event lock family (lockf/flock/shlock auto backend,
   5-second budget) and a lease-specific owner record (schema_version 2:
   scope, identity, owner, hostname, pid, token, backend, acquired_at,
   heartbeat_at, expires_at, expires_epoch). Scope keys hash canonicalized
   (realpath) repo and worktree paths; the full identity is stored and
   compared, so a hash collision or a moved checkout fails closed.
3. Bounded guarantee: the lease arbitrates acquisitions. Operations that
   change or free a lease (renew, release) must present the holder token and
   are compared under the lock; a stale-generation token is refused. A writer
   that bypasses the lease gets no protection beyond acquisition arbitration.
4. Two topologies, distinct claims. Local checkouts (the default): the lease
   is local and gitignored; no exclusion between independent checkouts is
   claimed — cross-checkout authority comes from the single integrator plus
   `git push --force-with-lease`. A genuinely shared directory: an expired
   lease may be taken over from another host with a logged reason (the TTL is
   the guard), but the workflow-event append owner still refuses cross-host
   recovery; that residual refusal is documented behavior, not a defect to
   fix here.
5. Crash safety: a lease disappears via TTL expiry, not via a held
descriptor. `recover <reason>` (any host) and `acquire` (takeover) are
allowed only after expiry and append a line to the scope history journal.

## Consequences

- The quick-card and spec wording "(protocol, not an OS lock)" becomes
  mechanism-backed: one writer per (repo, worktree) enforced by the lease;
  the protocol sentence stays for the parent-only default profile.
- The workflow-event fd-9 integrity proof is intentionally not replicated:
  the lease has no native-internal-execution invariant to prove; it uses the
  same backend family and budget with a re-exec mutation body.
- Lease files live under `.workflow/leases/` (local, gitignored); deleting
  the directory is a complete rollback.
- Operational adoption is procedural until Phase 3 parallelism wires workers
  to acquire before writing; the mechanism and its tests land now (Gate 0:
  lease proven by tests).
