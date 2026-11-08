# Implemented: learn from recovered run incidents

## Metadata
- Archived: 2026-11-07
- Source plan: `PLAN.md` - evidence-led run learning
- Source plan SHA-256: `da428cfc380aa520c9a65989005920720aaf1934d3d08ca31f75b033a5c685ed`
- Status: IMPLEMENTED
- Commit / branch: `feat/trace-learning`, based on `9ad2d584`
- Workflow initiative: run-learning

## Outcome
- A material recovered or unresolved failure opens the existing investigation
  contract at the next stable checkpoint. No per-tool judge, retry allowance,
  collector, service, scheduler or automatic rule rewrite is introduced.
- The existing record template separates one mechanism header (current decision,
  owner, review point and lifecycle) from per-task incident evidence. Escaped
  defects remain separate; independently curated existing replay pairs stay valid.
- Recurrence uses trusted task identities within the same subject project and
  source-supported mechanism. Counts are derived; partial coverage is a lower
  bound, unavailable/mismatched vaults are unknown. Severe supported mechanical
  incidents can open the existing type/lint/test/CI ladder without waiting.
- Capture preserves route/user authority, subject/session vault boundaries and
  approved inference routes. Untrusted trace instructions authorize no effects.
  Automated memory work remains capture/shadow only, grouped at promotion.
- Missing historical context/evidence stays explicit. Wrong instructions can be
  corrected; ignored correct rules are not restated, and one non-severe missing
  rule is no-op/pending. Correct guard refusals are not tool failures.
- Evaluation reuses the existing comparison contract, separates outcome/process/
  constraints/evidence and requires human calibration before relying on judges.
  The sourced research note is included as rationale, not operational evidence.

## Decisions
- Reuse existing contracts/templates and automatic scaffold discovery; preserve
  ADR-0034 retirement of unused evaluation/ledger tooling. No deployment mapping,
  schema, validator, model, effort, hunter template or executable source changed.
- Keep mutable lesson state at mechanism level; task observations do not copy
  aggregate decisions or stale counters. Retaining/narrowing/retiring requires
  existing authority and follow-up evidence.
- Source delivery is a PR only. Fleet reporting stays owned by its separate
  task; no remote operation, merge or deployment is part of this delivery.

## Validation Evidence
- Existing contract coverage and scaffold smoke checks pass on final source;
  direct temporary deployment copies the record template byte-for-byte.
- Entry-chain check: 401/405 lines, unchanged. No additional entry-chain file.
- Complete infra group on source v3: 46/46. Closing reference/coverage annotations
  pass focused checks and final-source protocol verification. The full delivery
  group runs again after this archive, before push.
- Final-source blind synthetic exercise: 27/27 frozen required case criteria,
  complete native activity, zero tool calls/effects, matching source/prompt/oracle
  hashes. Includes expected red tests, empty search, changed-state rechecks,
  wrong/ignored/missing instructions, truncated evidence, unresolved checks,
  project-scoped counts, task-identity spoofing, vault mismatch, read-only capture,
  raw/curated replay cases, lifecycle and authority controls.
- Controls are known regression diagnostics, not held-out quality or production
  calibration. Three semantic candidates and a final same-control source rebind
  are retained privately. Initial 16/17 score remains unchanged; an independent
  reviewer approved an encoding-only unknown/null correction, separately rescored
  17/17. No original artifact was silently replaced; sample counts are not gains.
- `simplify: removed 1` duplicated comparison block; recurrence has one resolver.
  `quality: none` for pure Markdown; parent document-convention pass used existing
  record/cold-contract siblings. `mutation: n/a` (no executable source changed).
- Plan P1/P2 challenged, P3 READY. Cumulative T1/T2 then bounded D1/D2 reviews
  ran fresh Claude Opus5.5/Anthropic via native T3, independent of the OpenAI
  source-author family, with inline hunter templates and complete closing reports.
  Closing Logic GO; lead GO WITH NOTES. Spec privacy concern was refuted against
  the existing aggregate-only template and actual vault policy, confirmed by
  the other closing axes. No hunter replay trigger or council invocation.
- Final source patch SHA-256:
  `fa8ef7593d5781afa212d0674bd223da203214c99cc3ad0abce5bbdf33e68e3e`.

## Follow-up State
- Production judgment calibration, false alarms/misses and net workload/token
  benefit remain unmeasured. Severity grading remains a judgment requiring
  independent impact evidence; no mechanical enforcement guarantee is claimed.
- Final native controls are synthetic, do not prove arbitrary injection
  resistance and must never be presented as an independent held-out corpus.
- Current reviewer defaults and existing effect authority remain unchanged.
  Activation in installed/project copies follows an approved merge/deployment.
- Original checkout/research note preserved. Dedicated worktree retained for PR
  inspection. Root plan removed through the archive hash gate.
