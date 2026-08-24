# Autoresearch: workflow-event append performance

## Objective

Reduce the wall-clock cost of a single `scripts/workflow-event append`
invocation. Baseline (external SSD): **~424 ms median** for one non-program
append. Every autonomous route pays this at least twice (route + completion),
and the smoke suite runs hundreds of appends (program-state-smoke alone does
128 in a loop ≈ 16 s of pure spawn overhead).

An append currently spawns: bash + `detail_valid` (1 jq) + `append_with_lock`
(hostname, od, backend probes) + the **native lock re-invoking the script
itself** (`_append-locked` = second full bash startup + detail_valid again)
+ inside: `verify_native_canonical_lock` (ps, lsof/readlink, ps again) +
`owner_host_compatible` (2 jq) + owner write (1 jq + date) + `tail|jq` for
terminal + `event_line` build (1 jq + date) + `verify_native_commit_lock`
(ps, flock probe) + release (1 jq) ≈ **2 bash + ~12 jq + ~6 util spawns**.

## Metrics

- **Primary**: `append_ms` (ms, lower is better) — median of 15 sequential
  non-program appends into a fresh ledger, measured by `.auto/measure.sh`.
- **Secondary**: `validate_ms` (cost of `validate` on the produced ledger),
  `append_safety_smokes_s` (the 4 smokes that pin append semantics).

## How to Run

`.auto/measure.sh` — outputs `METRIC append_ms=...`, `METRIC validate_ms=...`,
`METRIC append_count=N`.

## Files in Scope

- `scripts/workflow-event` — the entire command (parsing, locking, append body)
- `.auto/measure.sh`, `.auto/checks.sh` — measurement/validations only

## Off Limits

- `scripts/lib/workflow-event-detail.jq` (schema is contract-pinned)
- The on-disk formats: `events.jsonl` line schema, `events.lock.owner.json`
  fields, `events.integrity.json` fields, `.active-run.json` — smokes and
  program-state parse them; format changes break the contract.
- Lock semantics: canonical-native-lock verification (parent identity,
  descriptor, held-lock probe) must stay — the CI Linux fix (file-mode flock)
  and the fd-9 lockf contract are load-bearing. Optimizing *how* they run is
  fine; removing a verification is not.
- Everything else in the repo.

## Constraints

- `.auto/checks.sh` must pass: the four append-pinning smokes
  (workflow-event, program-state, workflow-receipts, autonomous-ledger-hygiene,
  workflow-supersession) — these encode collision, terminal, cross-host,
  lock-steal, and crash-recovery semantics.
- No new dependencies. bash 3.2 + jq + native lock tools only.
- Behavior-identical: same stdout/stderr, same exit codes, same files written
  (same bytes), same refusal messages.

## What's Been Tried

(Updated as experiments accumulate.)

### Results (2026-08-24 session)

Baseline 125 ms → **~98 ms median (−22%)**, all append smokes green after every step.

- **Kept**: single-pass jq owner validation + cached hostname via env (125→123);
  prevalidation handshake outer→inner skipping the duplicate detail_valid under
  the lock (123→115); single `date -u` for owner+event line (neutral, kept for
  simplicity); **proof memoization** — verify_native_commit_lock accepts the
  in-process canonical proof (same PPID+lock+backend) instead of re-running
  lsof/ps probes (115→97). Total: 5 spawns eliminated.
- **Tried and reverted**: grep-F instead of jq in release_append_owner —
  REGRESSED +4ms (fork+path lookup beats jq on a short file). Do not retry.
- **Refuted, do not try**: ps replacing lsof for fd proof (ps cannot prove an
  open descriptor); restructuring the native-lock double-bash startup (bash
  startup is 2ms; the win is noise vs the risk).
- **Remaining cost is structural**: 2 bash startups + lockf re-exec + ~7 jq
  spawns + lsof (macOS-only path). Next lever would be a C-free daemon or
  batching jq into one mega-program — both break the "no new deps / simple
  bash" constraint. Diminishing returns; stopped here.

### Ideas ranked by expected payoff

1. **Single-pass jq owner/terminal/event-line build**: `owner_host_compatible`
   reads owner_file with 2 jq calls; merge into one jq that also emits the
   terminal event of the ledger tail and builds the event_line — 3-4 spawns
   become 1.
2. **Skip the second detail_valid in `_append-locked`**: the outer `append`
   already validated event+detail before taking the lock; the inner path
   re-validates identically. Guard with an env handshake (e.g.
   `WORKFLOW_EVENT_VALIDATED=1` set by the outer process, checked+unset by
   the inner) so manual `_append-locked` calls still validate.
3. **Cache hostname** (`current_host` computed twice: outer + inner) and
   **date once** (owner write and event_line both call `date -u`).
4. **Fast-path non-program appends past the integrity revalidation**: current
   code calls full `validate` when cache misses; for non-program events the
   only pre-condition needed is "no terminal event" — the tail read already
   provides it. Keep full validation for program events.
5. **Replace `ps`/`lsof` parent verification reads with a single `/proc`
   read when available** (macOS: one `ps -o command= -p` instead of
   comm + args + lsof triple pass).
6. **Combine `od | tr` token generation with shell builtins** — minor.
