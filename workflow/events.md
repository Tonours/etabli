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
On classic Pi, `route_decided` is router-owned: the extension records issuance; agents
must not hand-append it there. Other harnesses append it by hand via the CLI.
Agents must use the CLI: direct appends bypass type and detail validation and
fail `scripts/workflow-ledger-check`. Writer exceptions, locking, grandfathered <!-- etabli-only -->
history, corrupt-ledger recovery and retired types: `workflow/events-validator.md`.

Never edit earlier lines. Active-run selection (`activate`): `workflow/events-validator.md`.

Optional `export_id` provides exact replay: `workflow/durable-exports.md`.


## Event Types

| Type | Detail convention |
| --- | --- |
| `route_decided` | `{route, reason}` (at most once per route per run); legacy `contract_path`, `contract_sha256`, `provenance` stay valid |
| `plan_created` | `{path, status}` |
| `adversary_completed` | `{mode: plan | code_diff, verdict, accepted_findings, rejected_findings, model_provenance: {requested: {family, model, provider, route?}, effective: {family, model, provider}, runner, run_id}}`; appends need complete provenance, the mode's verdict canon, `accepted_findings: [{finding, blocking}]`; history stays valid |
| `review_completed` | `{status, evidence}` — v2 `status` ∈ `GO`, `GO WITH NOTES`, `BLOCK` (free text rejected; legacy/v1 history stays valid); optional pair `review_round` ∈ `T1`,`T2`,`D1`,`D2`,`FD`,`F1`,`F2` + `round_outcome` ∈ `clean`,`findings`,`widening` (see below) |
| `simplification_completed` | `{status, evidence}` |
| `quality_completed` | `{status, evidence}` — `status` ∈ `pass`, `unavailable` (12c producer proof; `unavailable` stops before completion) |
| `ship_completed` | `{cumulative_review, thermo_nuclear, pr_body_style, delta_rereview, deciding_code, escaped_defects_recorded, pr_url, ci_state}` — success form all-required (thermo ∈ clean/`findings:<n>-folded`/unavailable, cumulative `...HEAD @ ...` record, deciding ∈ complete/n/a, `ci_state=green`, non-null URL); arrêt form allows per-field `not-reached:<step>` + `-open`/`incomplete` (see ship.md; matrix jq-enforced) |
| `file_changed` | `{path, change}` |
| `validation_run` | `{command, exit}` |
| `validation_failed` | `{command, exit, failure}` |
| `retry_classified` | `{failure_class, next_action}` |
| `no_progress` | `{check_or_hypothesis, command, attempts, head_sha, eliminated}` |
| `handoff` | `{branch, sha, done, pending, next_action, do_not_redo}` |
| `human_checkpoint` | `{category, decision, target, consent_class?}` — v3: `consent_class` ∈ `permission_request`/`input_request` (permission prompt vs waiting-for-input) |
| `correction` | `{harness ∈ pi/claude, prompt_sha256, prompt_chars}` — user course-correction while the session's run is active (a later interactive prompt, steering included); never stores prompt text |
| `archive_written` | `{path}` |
| `plan_removed` | `{path:"PLAN.md"}` |
| `completed` | `{summary}` |
| `blocked` | `{reason, needed_input}` — v3: on append, `reason` must be one of `missing_input, consent_needed, ci_wait, usage_limit, review_requested, plan_gate, tool_failure, environment_failure, ledger_recovery, unknown`; free-text reasons stay valid in history |

Retired types (self-improvement, harness, project slices, program, runtime
receipts and attachments, multi-execution, outcome measurement and metrics,
dogfood) stay readable in history but are refused on append.

Review rounds: in a v2 `plan-implement` run, the first tagged `review_completed` activates `scripts/lib/review-rounds.jq` (append and validate). From then on every review is tagged v2 and follows `workflow/skills/review-rounds.md`; `clean` needs a non-`BLOCK` status and, per round, `code_diff` adversaries `GO`/`GO WITH NOTES` with `accepted_findings: []` (required for T and F rounds); no `code_diff` adversary after the closing clean F; `completed` needs a clean F1/F2. The filter also refuses, on every ledger, a non-canonical envelope (`schema_version` other than absent/`1`/`2`, `event` not exactly `[a-z_]+`).

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
`autonomous-completed` requires every command attempted after the last
`file_changed` through `validation_run` or `validation_failed` to have a latest
successful `validation_run`, and the latest review plus plan/code-diff
adversary verdicts to be non-blocking; validation, review, and code-diff
adversary evidence must follow the last `file_changed`, and a later failure or
blocking verdict invalidates an earlier success. `ship-completed` requires the
same fresh validation plus a success-form `ship_completed`; review evidence is
carried by the `ship_completed` records. Presence alone does not prove
completion.

Product completion fields and terminal revalidation: `workflow/product-verification.md`.
