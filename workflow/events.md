# Workflow Events

Long-running Etabli runs may record durable progress in
`.workflow/<slug>/events.jsonl`. The run directory is local and gitignored.

The file is append-only: one JSON object per line, never rewritten. Event
shape:

```json
{"schema_version":2,"ts":"2026-07-03T12:00:00Z","event":"route_decided","run":"slug","detail":{"route":"plan-loop","reason":"broad task"}}
```

Resume by replaying `events.jsonl`; derived summaries are disposable, not a
second source of truth. A schema-v2 `completed`, `blocked`, or
`ship_completed` event must be final — with none, the run is in progress;
the single exception is the ship-stopped order `ship_completed` THEN final
`blocked`. Legacy ledgers remain readable but are not authoritative for new
strict profiles.

Write events with `scripts/workflow-event append <slug> <type> [json-detail]`.
On Pi, `route_decided` is router-owned: the extension records issuance (with
contract evidence when the route maps to a skill); agents must not hand-append
it there. Other harnesses append it by hand via the CLI.
Agents must use the CLI: direct appends bypass type and detail validation and
fail `scripts/workflow-ledger-check`. The Pi/Codex harness extensions are the <!-- etabli-only -->
single named exception: their synchronous hot paths append schema_version 2
envelopes directly (same shape the CLI would accept); a shared serialized
writer is a parked follow-up. Every line, whatever the writer, must validate.
Tightening strict validation flips terminal history that predates the rule:
inventory such ledgers in `workflow/runtime/ledger-drift-grandfathered.json`
instead of rewriting them.
New appends are serialized behind a five-second `lockf`, `flock`, or `shlock`
lock. Writer integrity proofs, validator semantics, measurement recovery and
the program event family are documented in `workflow/events-validator.md`.

Before a run relies on runtime receipts or mutation/no-progress authority, select
it with `scripts/workflow-event activate <slug>`; the runtime then inspects only
that ledger. Without a pointer, the compatibility fallback considers only valid
non-terminal ledgers; an invalid historical record that already contains a
terminal event is not an active run, while an invalid non-terminal candidate
still fails closed. Terminal append clears the matching pointer.
If a ledger is corrupt, use `scripts/workflow-event recover <slug> <reason-code>`:
it preserves the original as `events.invalid-*.jsonl` and writes a blocked
replacement instead of deleting history. When that script is unavailable in a
scaffolded project, an equivalent single validated append is acceptable. Do not
edit earlier lines.


## Event Types

| Type | Detail convention |
| --- | --- |
| `route_decided` | `{route, reason}` + optional `contract_path`, `contract_sha256`, `provenance` (router issuance proof; at most once per route+sha per run) |
| `plan_created` | `{path, status}` |
| `adversary_completed` | `{mode: plan | code_diff, verdict, accepted_findings, rejected_findings}` + optional `model_provenance: {requested: {family, model, provider, route?}, effective: {family, model, provider}, runner, run_id}` (complete when present; effective values copied from the harness record) |
| `review_completed` | `{status, evidence}` — v2 `status` ∈ `GO`, `GO WITH NOTES`, `BLOCK` (free text rejected; legacy/v1 history stays valid) |
| `simplification_completed` | `{status, evidence}` |
| `quality_completed` | `{status, evidence}` — `status` ∈ `pass`, `unavailable` (12c producer proof; `unavailable` stops before completion) |
| `ship_completed` | `{cumulative_review, thermo_nuclear, pr_body_style, delta_rereview, deciding_code, escaped_defects_recorded, pr_url, ci_state}` — success form all-required (thermo ∈ clean/`findings:<n>-folded`/unavailable, cumulative `...HEAD @ ...` record, deciding ∈ complete/n/a, `ci_state=green`, non-null URL); arrêt form allows per-field `not-reached:<step>` + `-open`/`incomplete` (see ship.md; matrix jq-enforced) |
| `file_changed` | `{path, change}` |
| `validation_run` | `{command, exit}` |
| `validation_failed` | `{command, exit, failure}` |
| `dogfood_matrix_created` | `{path, flows, scenarios}` |
| `dogfood_scenario_run` | `{scenario, surface, status, artifacts}` |
| `dogfood_fix_applied` | `{scenario, fix, evidence}` |
| `dogfood_blocked` | `{scenario, reason, needed_input}` |
| `self_improvement_candidate` | `{source, category, outcome, confidence, evidence, held_in?, held_out?, supersedes?}` |
| `harness_failure_pattern` | `{terminal_cause, causal_status, mechanism, verifier, traces}` |
| `harness_proposal` | `{candidate, editable_surfaces, preserve, held_in, held_out, supersedes?}` (supersession rule: `workflow/events-validator.md`) |
| `harness_validation_completed` | `{candidate, verdict:accepted | rejected, reason, objective?, measurement?, held_in, held_out, checks, evidence, baseline_fingerprint?, candidate_fingerprint?, evaluator_manifest_sha256?, evaluator_bundle_sha256?, comparison_path?, comparison_sha256?}` (strict provenance, comparator-chain and shape/count rules: `workflow/events-validator.md`) |
| `harness_candidate_rejected` | `{candidate, reason, regressions, evidence}` |
| `project_slice_planned` | `{slice, owner, validation, dependencies}` |
| `project_slice_completed` | `{slice, validation, evidence, remaining}` |
| `program_*` | program event family (`program_initialized` … `program_unit_reconciled`): `workflow/events-validator.md` |
| `runtime_run_attached` | `{adapter:"pi-workflow", run_id, workflow, state_path:".pi/workflows/<run-id>", status, usage_measured}` |
| `runtime_receipt` | `{receipt_for, source, kind:file_change\|validation\|review\|archive\|completion, subject_sha256, exit?, worktree_sha256?, artifact_sha256?, observed_by:"parent-process", cryptographic:false}` (semantics: `workflow/events-validator.md`) |
| `multi_execution_completed` | `{participants:[{id,model,family}], independent_first_passes, disagreement, adjudicator, verdict, usage, fallback_status}` (enums and protocol v2: `workflow/events-validator.md`) |
| `outcome_measurement_population` | `{population_id, manifest_sha256, terminal_runs, targets:[...]}` (target fingerprints: `workflow/events-validator.md`) |
| `outcome_measurement_imported` | field list and semantics: `workflow/events-validator.md` |
| `outcome_metric` | measured: `{outcome, success, measured:true, input_tokens, output_tokens, total_tokens, tool_calls, elapsed_ms}`; unavailable: `{outcome, success, measured:false, reason}`; additive optional fields and producers: `workflow/events-validator.md` |
| `retry_classified` | `{failure_class, next_action}` |
| `no_progress` | `{check_or_hypothesis, command, attempts, head_sha, eliminated}` |
| `handoff` | `{branch, sha, done, pending, next_action, do_not_redo}` |
| `human_checkpoint` | `{category, decision, target}` |
| `archive_written` | `{path}` |
| `plan_removed` | `{path:"PLAN.md"}` |
| `completed` | `{summary}` |
| `blocked` | `{reason, needed_input}` |

Quality passes (12c) are recorded via `quality_completed`, never via `review_completed` (rejected by the status enum).

Ship outcomes are recorded via `ship_completed` (one per ship run, emitted at report; success and arrêt forms per the table above), never via ad-hoc types (`ship_complete`, `pushed`, `ci_green` stay unvocabularized drift — extinct, 0 specimens).

| Type | Detail | Emitter | Moment | Consumer |
| --- | --- | --- | --- | --- |
| ship_completed | 5 records + escaped count + URL + CI state (8 detail fields) | ship runner (step 14) | report (success or arrêt) | ship profiles (`ship-completed`/`ship-stopped`), report audit, metrics registry join |

New events use envelope `schema_version:2` enforced by
`scripts/lib/workflow-event-detail.jq`; version 1 and legacy envelopes stay
readable via the bounded post-terminal compatibility path.

New autonomous ledgers use `validate --profile autonomous-completed`; missing
ledgers fail unless explicit `--allow-missing` legacy compatibility is selected.
Both completion profiles require every command attempted after the last
`file_changed` through `validation_run` or `validation_failed` to have a latest
successful `validation_run`, and
the latest review plus plan/code-diff adversary verdicts to be non-blocking.
Validation, review, and code-diff adversary evidence must also follow the last
`file_changed`; a later failure or blocking verdict invalidates an earlier
success. Presence alone does not prove completion. The
`autonomous-completed-strict` profile additionally runs the strict
self-improvement integrity validator against the repository's pinned public
manifest; field presence alone is not a comparator receipt.
Generic workflow scaffolds without that manifest and validator reject
comparative strict events until a project-specific public evaluator bundle is
installed; they do not fall back to legacy acceptance.
Unavailable telemetry is recorded with `measured:false` and a non-empty
`reason`, never as zero. Measured events require non-negative integer token and
tool counts, elapsed time, and a total at least as large as input plus output.
A quality-only event may carry `measured:true` without usage fields, but it is
not usage coverage; partial or malformed usage is reported as invalid and
native coverage requires a complete valid usage tuple (tokens, tool calls and
elapsed time). Use
`success: true` or an `outcome` such as `success`, `passed`, or `completed` for
successful outcomes; historical ledgers remain readable as `legacy_unmeasured`.

Runtime usage from `multi_execution_completed` is reported independently and
never counts as a successful outcome without an `outcome_metric`.

Recurrence counts independent ledger initiatives, not raw occurrences. A terminal `-vN`, `-retryN`, `-attemptN`, or `-rerunN`
suffix is treated as another execution of the same initiative. Plan archives
remain visible as supporting evidence; when ledger evidence exists for a
finding, an archive cannot increase its recurrence count.
For legacy archives without initiative metadata, a unique ledger
`archive_written` path supplies the initiative; ambiguous or unmatched archives
remain distinct by file path.
Its telemetry validates imported measurements against their population and
target-ledger fingerprints, reports invalid imports, and deduplicates only
validated target runs; native usage and imported coverage stay separate.
