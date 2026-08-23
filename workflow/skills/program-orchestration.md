# Large Program Control-Plane Contract

> **FROZEN (2026-08-23):** no live program currently depends on this
> control plane's recovery semantics. Kept frozen; do not extend it. A
> recurring program with real recovery needs reopens it.

Use this contract only when a program has independently ownable units and the
active workflow authorizes sidecars. It strengthens restart and verification;
it does not authorize delegation, launch agents, or widen the user's mutation
permissions.

## Sources of truth

- One immutable manifest shaped by `workflow/program.schema.json`.
- One canonical `.workflow/<run>/events.jsonl` written only through
  `scripts/workflow-event` by the coordinator.
- Immutable worker result and verifier artifacts under the manifest's
  `artifact_root`.
- Read-only derived state from `scripts/program-state`.

Do not add a mutable status TSV, dashboard store, or worker-written ledger.
Workers return artifacts to the coordinator; the coordinator validates and
appends the typed event.

## Manifest rules

Schema v2 declares the goal, positive `max_in_flight`, one dependency-free
pilot unit, unit DAG, exact path scopes, tools, verification commands/evidence,
retry limits, worktree policy, independent verifier policy, and forbidden
external/destructive actions. Every unit also carries bounded context and
acceptance lists, a positive timebox, and a report artifact prefix. The
context and acceptance lists are limited to 12 items of 1,000 characters each. The
manifest has no arbitrary unit-count ceiling. Safety remains bounded by
concurrency, scope, retries, and explicit authorization. Schema v1 remains
readable for existing archived runs but does not satisfy a new live-program
brief.

Path scopes are project-relative paths or directory prefixes, not globs. This
keeps containment and active-writer overlap deterministic.

## Event and retry rules

Every `program_*` event binds a unique SHA-256-shaped `event_id`, program and
manifest identities, unit, attempt, and coordinator emitter. The canonical
writer serializes validation and terminal checks behind a five-second OS lock;
identical event IDs are idempotent and collisions fail closed.

Start a unit only after all dependencies pass independent verification for
their latest heads. Active workers and worktrees are unique, and active writer
scopes cannot overlap. Results bind worker, attempt, head, and a hashed artifact.
A head change invalidates the previous result and verdict. Retries must follow a
failed result/verdict and remain inside the unit limit.

For schema v2, only the declared pilot may start until its latest head passes
independent verification. A result artifact is JSON bound to unit, attempt,
head, status, changed paths, declared verification, and blockers. Passing
reports cannot carry blockers; failed reports must. `scripts/program-state`
derives the ready frontier and rejects a pilot bypass or a report that escapes
the exact scope reserved when its worker started. The frontier never advertises
more units than the remaining `max_in_flight` capacity. A unit head change fails
while a descendant is running and marks completed descendants stale; they must
start a new attempt after the changed dependency or pilot is reverified.

A result from an older attempt is a zombie. It cannot affect current state
until the coordinator emits `program_unit_reconciled` with `ignored` or
`accepted`; acceptance is allowed only before the scheduled retry starts.

## Completion and capability honesty

Replay is complete only when every unit has a passing independent verdict for
its latest head. `replay_valid` and `replay_complete` describe deterministic
control-plane state. They never prove live workers or model provenance.

`--live-git` can read declared worktree, branch, and HEAD, but the output remains
`runtime_confirmed:false` and `execution:proxy_supported` until a separate
runtime supplies independently observed worker/model provenance. Never promote
declared provenance into live confirmation.

Native `lockf` or `flock` releases when its owner dies. The dependency-free
`shlock` fallback reclaims a dead local PID only on the next acquisition. A
foreign-host owner record fails closed; a live lock is never stolen. Owner
metadata includes token, PID, hostname, timestamp, and backend, and cleanup
removes it only when the token still matches.
