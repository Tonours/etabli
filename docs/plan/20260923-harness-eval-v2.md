# Implemented: harness-eval v2 with a hashed grading contract and an unhashed runner

## Metadata
- Archived: 2026-09-23
- Source plan: `PLAN.md` — harness-eval v2 suite (evaluator `binary-final-state-v2`) whose frozen hash covers the grading contract only
- Source plan SHA-256: `40d93d765b5dd3390174c2926c21d5c2cced9c725ea745c5a58a73919100fd8c`
- Status: IMPLEMENTED
- Commit / branch: `main`
- Workflow initiative: `plan-c`

## Outcome
- New suite `scripts/etabli-harness-eval-v2` + `tests/fixtures/harness-v2/`, evaluator `binary-final-state-v2`. Its manifest pins the SHA-256 of `scripts/lib/etabli-harness-grade.sh` only.
- The hashed lib holds:
  - the single parser `harness_parse_review`;
  - the oracle DSL;
  - `harness_grade`, plus the HEAD and baseline checks;
  - the spawn-evidence producers and their check;
  - the fixture ignore list and the constant fabrication transcript.
- The unhashed runner lib `scripts/lib/etabli-harness-run-v2.sh` holds the models (`grok-4.7`, `zai/glm-5.3`), effort, timeout, scaffold, worktree preparation, `run`, baselines and report.
- The 8 oracles are 2–7 declarative lines each. None reads the transcript.
- Rows add `evaluator_id` and `task_sha` (task dir minus `synthetic/`). A non-offline row without a driver-held `BASELINE_EXPECTED` fails closed.
- v1 is byte-identical. All 3 evaluator-bundle fingerprints still match.
- ADR-0026 records the split, the non-comparability of v1 and v2 rows, and the two grading deltas.

## Context
- `jev-efficiency-manifest.json`, `manifests/core-v2.json` and `jev-plan-implement-manifest.json` fingerprint the v1 files. Re-pinning them would falsify frozen evidence, so v2 is new files only.
- v1 `harness_extract_verdict` skipped an unterminated final line (`while read` without the `|| [ -n "$line" ]` guard).

## Decisions
### Hash boundary = what a grade judges against
- Context: the plan adversary returned BLOCK. Spawn-log producers, the `.gitignore` written into fixtures, and the constant transcript all decide grades, yet sat in the runner.
- Choice: move them into the hashed lib, and stamp `task_sha` so fixture edits show in the rows.
- Rejected options:
  - `prepare_worktree` in the hashed lib: the brief wants perf edits free of a re-pin, and its output is covered by `task_sha` plus the HEAD pin.
  - A `runner_lib_sha` row field.
- Consequences: the hash protects the judgment, not the sandbox. Process-level runner edits (baseline timing, `runner_exit` pass-through, PATH for hidden spawns) stay reviewed code.
### Runner code copied, not shadowed
- Choice: v2 carries its own runner functions instead of sourcing v1 and overriding functions.
- Rationale: no hidden ordering dependency on a frozen file; retiring v1 cannot break v2.
### skill-eval fixture keeps `binary-final-state-v1`
- Rationale: it is a schema fixture with a placeholder sha, bound to neither harness lib.

## Accepted Drift
- Original plan: the grade lib excluded prepare logic.
- Implemented reality: `harness_ensure_ignore` (called by prepare) is hashed, because it decides what porcelain sees.
- Why accepted: code-adversary repro (`*` in `.gitignore` would hide `EXTRA.txt`).
- Two grading deltas vs v1, in ADR-0026:
  - an unterminated verdict line now parses (a loosening on the GO control);
  - every isolation claim requires `runner: pi-child`.

## Validation Evidence
- `bash tests/etabli-harness-eval-v2-smoke.sh`: ok (61 s in the full group).
  - 8 tasks pass/fail.
  - 17 transcript cells.
  - State and baseline cells.
  - `task_sha` properties.
  - Null floor = `plan-draft-no-mutate` only; constant floor ≤ 3.
  - print-argv `grok-4.7`.
  - No pi/grok invocation.
- Mutation test: 6/6 grade-lib mutations caught (deciding anywhere, act block, baseline rule, case-insensitive isolation, unterminated verdict, `task_sha` scope).
- `bash tests/etabli-harness-eval-smoke.sh` (v1): pass.
- `fingerprintEvaluatorBundle` ×3: true; `git diff --quiet HEAD` on the v1 frozen paths: clean.
- `bash tests/agentic-infra-manifest-smoke.sh`, `bash tests/workflow-docs-smoke.sh`, `scripts/validate-adrs`: ok.
- `env -u TYPESAFE_API_KEY scripts/verify-agentic-infra all`: 89/91. The reds are `program-state-smoke` and `autonomous-ledger-hygiene-smoke`: no `/usr/bin/lockf` on macOS 14, known.
- Reviews, all same-family (Claude, no cross-model runner on this machine):
  - plan adversary (fable): BLOCK, then folded;
  - Logic+Spec reviewer (sonnet): GO, deciding-code complete;
  - code adversary (fable): GO WITH NOTES, then folded;
  - on the final patch, both re-passes returned GO.

## Follow-up State
- Remaining risks: none known. `grok-4.7 --reasoning-effort xhigh` was verified live on 2026-09-23 (reply `OK`, exit 0). A bogus effort makes grok print `unknown effort level`, which `harness_model_mismatch_hit` catches.
- Parking lot:
  - a v2 self-improvement manifest and a v2 live row, when a campaign consumes v2;
  - porting the jev campaigns off v1.
- Superseded docs/specs: none (v1 stays).
- Next links: `docs/adr/0026-split-harness-eval-v2-into-a-hashed-grading-contract-and-an-unhashed-r.md`, `docs/harness-eval.md`.
