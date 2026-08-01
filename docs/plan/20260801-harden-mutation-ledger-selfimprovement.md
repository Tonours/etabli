# Implemented: Harden Etabli mutation authority, ledger evidence, and self-improvement loop

- Source plan: `PLAN.md` — Harden Etabli mutation authority, ledger evidence, and self-improvement loop
- Source plan SHA-256: `286b0d37b1f767ceaad4040f2a8cd46bc07d09e7cc727c7c49e68eb3d38bd2eb`
- Status: IMPLEMENTED
- Archived: 2026-08-01
- Commit / branch: not committed; local working-tree changes only

## Outcome

Implemented the locally enforceable P0/P1/P2 harness hardening identified by the
adversarial audit: fail-closed mutation authority with a structural read-only
allowlist, strict active-ledger integrity with lossless recovery and deterministic
active-run selection, a narrow validated plan-cleanup path, non-cryptographic
runtime receipts that bind evidence to observable state, a frozen-public
self-improvement manifest with a provenance/grader-immutability validator, and a
rejected-candidate supersession guard. Existing READY / check-freeze / ops-stop /
no-auto-apply invariants are retained or strengthened.

## What changed

### Slice 1 — Fail-closed mutation policy and archive cleanup

- `claude/hooks/workflow-router-lib.mjs`: replaced the allow-by-omission
  `MUTATING_BASH_PATTERN` with a structural classifier (`isReadOnlyBashCommand`).
  A command is mutating unless every pipeline/logical-operator segment resolves to
  an allowlisted read-only executable (`rg`, `cat`, `ls`, read-only `git`
  subcommands, `node --check`, `bash -n`, etc.). `&&` and `||` join read-only
  segments; mixed `safe && dangerous` stays fail-closed. `node -e`, `python3 -c`,
  `git apply`, and `install` are no longer auto-allowed under DRAFT/no_progress —
  they classify as mutating. A quoted read-only search whose query contains
  mutation words (`rg -n 'rm|mv' docs`) is no longer overblocked.
- `scripts/lib/plan-cleanup-command.mjs` + `scripts/plan-cleanup`: the only
  validated, non-bypass path to remove a completed root `PLAN.md`. Confines the
  archive to `docs/plan/<name>.md`, requires an `# Implemented:` title, a
  `Source plan: \`PLAN.md\`` line, `Status: IMPLEMENTED`, and an exact source-plan
  SHA-256 match before`rm`.
- `scripts/lib/no-progress-guard.mjs`: the no_progress escape hatch now also
  admits the narrow `scripts/plan-cleanup` command, so recovery/cleanup cannot be
  bricked.

### Slice 2 — Strict active-ledger integrity and selection

- `scripts/lib/ledger-integrity.mjs` (new): inspects `events.jsonl` without
  silently dropping malformed data. Schema-v2 events must bind to their directory
  slug, carry ordered UTC-second timestamps, and keep any terminal final. Authority
  detail shapes (terminal, no_progress, validation_failed, file_changed) are
  checked so a malformed v2 event cannot reopen a stopped run.
- `selectActiveLedger` is deterministic: an explicit `.workflow/.active-run.json`
  pointer (schema 1) selects the active run; otherwise exactly one non-terminal
  ledger must exist. Malformed, misbound, post-terminal, stale-pointer, or
  ambiguous states fail closed.
- `scripts/workflow-event`: adds `activate <slug>` (sets the pointer, refuses
  terminal/invalid ledgers) and `recover <slug> <reason-code>` (preserves the raw
  invalid ledger as `events.invalid-*.jsonl` and writes a blocked replacement —
  never deletes history). Terminal append clears a matching pointer.
- `loadLedgerEvents`/`isTerminalLedger`/`findActiveLedgers` now delegate to the
  integrity inspector; `parseLedgerEvents` is retained as a legacy reporting-only
  parser and documented as non-authoritative.

### Slice 3 — Host-observed receipts and strict completion profiles

- `scripts/lib/workflow-receipts.mjs` (new): builds non-cryptographic, parent-process
  receipts. The subject (path or command) is SHA-256 hashed in-process and never
  persisted; only `subject_sha256`, optional `exit`, `worktree_sha256`,
  `artifact_sha256`, `observed_by:"parent-process"`, `cryptographic:false` survive.
- `runtime_receipt` event added to the schema and allowed lists.
- `scripts/lib/ledger-auto-emit.mjs` + `pi/extensions/workflow-router.ts`: the Pi
  `tool_result` handler now emits a `validation` receipt for observed successful
  Bash validations into the uniquely selected active ledger (deduped per command
  after the last `file_changed`); failures still append `validation_failed`.
- `autonomous-completed-strict` profile: requires a `runtime_receipt` of each kind
  (validation/review/archive/completion) and, when a comparative
  `harness_validation_completed` is present, requires `candidate_fingerprint` and
  `evaluator_manifest_sha256`. Legacy `autonomous-completed` stays structural and
  readable.

### Slice 4 — Candidate provenance, frozen-public evaluation, promotion gate

- `workflow/self-improvement/manifests/core-v1.json` (new): declares
  `visibility: frozen_public`, the registered population
  (`etabli--initial-v1`) with corpus hashes, the evaluator
  (`scripts/-suite`) hash, a minimum sample per split, and
  `external_isolated_evaluator: blocked`.
- `scripts/workflow-self-improvement-integrity` (new): rejects arbitrary
  population IDs, totals below the manifest minimum, missing candidate
  fingerprints, and evaluator-manifest hash drift (grader immutability). Legacy
  ledgers without comparative validation pass cleanly.
- `harness_validation_completed` gained additive optional
  `candidate_fingerprint` / `evaluator_manifest_sha256` / `revision` fields
  (enforced only by the strict path and the integrity validator).

### Slice 5 — Delegation honesty, classified telemetry, and learning loop (bounded)

- `scripts/workflow-supersession-check` (new): a `harness_proposal` whose
  `candidate` matches a prior `harness_candidate_rejected.candidate` must list it
  in `supersedes`, preventing reward-hacking over an already-rejected change.
  `harness_proposal` and `self_improvement_candidate` gained an additive optional
  `supersedes` field.
- The runtime-capability matrix is kept honest: `supports_subagents`,
  `supports_taskexecute_tracking`, and `supports_goal_state` stay `unknown`, and
  portfolio roles remain blocked on the unguarded Task RPC surface, so an unknown
  capability cannot silently admit a portfolio run.

## Decisions

- Treat all local P0/P1/P2 improvements as one ambitious project with ordered
  vertical slices; never simulate an OS sandbox, cryptographic identity, or an
  isolated external evaluator.
- Receipts are parent-process observations with hashed/allowlisted metadata, not
  cryptographic attestations; `cryptographic:false` and `observed_by:"parent-process"`
  make that explicit.
- A stricter contract always uses a new explicit profile or protocol version, so
  historical ledgers remain readable but cannot be misrepresented as promotion
  evidence. Local manifest v1 records `visibility: frozen_public`; any request for
  `isolated`/`sealed` promotion returns a named external-evaluator blocker.

## Accepted Drift

- Original plan/spec: full Slice 5 including telemetry classification beyond Bash,
  a local canary/rollback rollout policy, and agent/skill candidate evaluation
  fixtures.
- Implemented reality: Slice 5 is bounded to the supersession guard and capability
  honesty. Non-Bash failure classification, canary/rollback policy, and live
  agent/skill evaluation are documented as remaining, not implemented.
- Why accepted: the P0 truth boundary (mutation, ledger, receipts, provenance) is
  the integrity-critical foundation and is fully delivered; the remaining Slice 5
  items are P2 and diffuse, and the self-improvement contract requires
  READY-gated, evidence-backed, narrow changes rather than a broad P2 sweep.

## Validation Evidence

- `scripts/verify-agentic-infra core` — exit 0.
- `scripts/verify-agentic-infra full` — exit 0 (manifest smoke updated for the new
  core `plan-cleanup-smoke` and full `workflow-receipts-smoke` /
  `workflow-supersession-smoke` entries).
- `cd pi && bun test ./extensions/__tests__/` — 226 pass, 0 fail (includes a new
  runtime-receipt emission test and hardened DRAFT guard cases).
- Focused smokes: `plan-cleanup`, `no-progress-mutate-deny` (corrupt/post-terminal/
  misbound/ambiguous fail-closed + active pointer), `workflow-receipts` (strict
  profile + integrity validator), `workflow-supersession`, `action-graph`
  (`&&`/`||` read-only with fail-closed on mixed commands), `-suite`,
  `ledger-auto-emit`, `workflow-event` (activate/recover), `project-autonomy`,
  `runtime-capabilities`, `dual-runtime-guard-matrix`, `plan-check-freeze`,
  `claude-hooks`.
- `lens_diagnostics` mode=all — no blocking errors across edited files.

## Follow-up State

- Remaining risks / known partial acceptance criteria: (1) non-Bash validation
  failures are not yet classified and recorded without risking a false no_progress;
  (2) agent/skill candidate evaluation and a local opt-in canary/rollback policy
  have no deterministic fixture coverage yet.
- Parking lot (explicitly blocked external capabilities): OS/process sandbox,
  cryptographic identity outside the parent process, a genuinely secret/isolated
  evaluator, remote evaluator service, production rollout, billing, and live paid
  multi-model evaluation. These remain named blocked boundaries; they are not
  simulated and must not be described as implemented.
- Next links: `workflow/self-improvement/manifests/core-v1.json`,
  `scripts/workflow-self-improvement-integrity`, `scripts/workflow-supersession-check`,
  `scripts/lib/workflow-receipts.mjs`, `scripts/lib/ledger-integrity.mjs`,
  `scripts/plan-cleanup`.
