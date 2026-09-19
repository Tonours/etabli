# Bounded Jev semantic profiles

Etabli exposes twelve optional TypeSafe/Jev judgment profiles through
`jev-judge`. They turn bounded natural-language state into typed `Choice`,
`Noul`, and `Score` answers. They do not generate artifacts and they do not own
permissions, mutations, calculations, dates, hashes, Git/CI facts, or stop
conditions.

The existing workflow route selector is separate and remains the only promoted,
enforced Jev path. Every profile here is `shadow` or `advisory`. Synthetic tests
prove the integration contract, not live model quality.

## Offline-first CLI

These commands never call the provider:

```bash
jev-judge health
jev-judge list
jev-judge show claim-evidence
```

Evaluation requires a regular, non-symlink JSON file and explicit `--live`:

```bash
jev-judge evaluate goal-completeness --state-file /tmp/goal.json --live
jev-judge evaluate-claim --claims-file report.md --claim-index 0 --live
jev-judge suggest-skill --prompt-file /tmp/request.txt --live
```

Omitting `--live` is an error. Library callers must likewise pass
`allowProviderEgress: true`; injecting or discovering a credential is not
consent. `TYPESAFE_API_KEY` is read only from the process environment. Private
evidence must not be submitted merely because a credential is present: the
invoking workflow must explicitly opt in to provider egress.
`--no-receipt` disables the local receipt; otherwise the CLI appends
`.workflow/semantic-profile-judgments.jsonl` under the current directory.

Receipts contain fingerprints, typed decisions, latency, usage, outcome, and an
error code. They contain neither input state nor raw provider payloads.
Secret-like or oversized state is rejected before network I/O. Provider errors,
malformed responses, and uncertain answers abstain without changing the
deterministic workflow.

## Profile matrix

| Profile | Authority | Egress | Deterministic owner and boundary |
| --- | --- | --- | --- |
| `skill-suggestion` | advisory | public or sanitized | `skill-surface.tsv`; two-stage shortlist/select, may return no match, never changes the catalog |
| `claim-evidence` | advisory | public or sanitized | `claim-evidence-check`; structural validation must pass first and cannot be upgraded by Jev |
| `reviewer-finding` | shadow | public or sanitized | review rubric and deciding code remain authoritative |
| `self-improvement-candidate` | shadow | private opt-in | self-improvement contract owns buckets, evidence, acceptance, and mutation |
| `project-hunt-evidence` | advisory | public or sanitized | project-hunt owns provenance, counter-search, scoring, arithmetic, and watchlist |
| `conversation-signal` | shadow | private opt-in | conversation retrospect owns source selection, privacy, aggregation, and durable writes |
| `knowledge-passage` | advisory | private opt-in | Obvault owns retrieval, citations, thresholds, feedback, and its existing explicit `--jev` sidecar |
| `linear-intake` | advisory | private opt-in | Linear contract owns hierarchy, one-behavior rule, questions, and creation permission |
| `pr-qa-impact` | advisory | public or sanitized | PR-QA owns evidence retrieval and executable test-plan generation |
| `no-progress-equivalence` | shadow | private opt-in | exact no-progress guard owns attempt counts and stop decisions |
| `goal-completeness` | advisory | private opt-in | goal rewriter owns the final measurable contract and clarification |
| `task-state-fallback` | advisory | private opt-in | structured Pi/Herdr events always win; text classification is fallback only |

The machine-readable source is
`workflow/runtime/semantic-profile-policy.json`. Each entry pins its state cap,
required state schema, questions, uncertainty thresholds, authority, egress
class, and deterministic owner. Do not reuse promoted workflow-route thresholds:
each profile needs its own frozen live corpus before any authority expansion.

## State contracts

State is a small JSON object containing only evidence needed for the named
questions. Use descriptive keys and remove credentials, unrelated logs, raw
transcripts, and private metadata.

- `claim-evidence` is available only through `evaluate-claim`. That command runs
  `scripts/claim-evidence-check --json`, selects a structurally valid claim by
  index, reads a bounded local evidence file, and only then constructs the Jev
  state. A URL pointer additionally requires `--evidence-file`; a caller-provided
  `structural_valid` boolean is never trusted.
- `task-state-fallback` requires `structured_state_available: false`. If a Pi or
  Herdr structured event exists, consume it directly.
- `no-progress-equivalence` supplies two attempts and their evidence, but its
  answer cannot trigger a stop by itself.
- `knowledge-passage` is a reusable contract for tests and explicit consumers.
  Normal retrieval continues through Obvault's existing explicit `--jev`
  option; Etabli does not duplicate or silently enable that sidecar.
- `skill-suggestion` is invoked only through `suggest-skill`. Stage one scores
  the bounded local catalog and retains at most three candidates; stage two
  examines only those candidates and can still return no match.

## Promotion rule

Never promote several profiles as one bundle. Freeze a representative corpus,
questions, model, runtime fingerprint, thresholds, privacy class, cost and
latency budget for one profile. Measure abstention, accepted accuracy, coverage,
stability, calibration, provider errors, and deterministic-boundary safety.
Until that evidence exists and is reviewed, keep the checked-in authority.

## Live calibration

The repository freezes one sanitized 12-case corpus per profile under
`tests/fixtures/jev-profiles/`. Calibration remains explicit and paid:

```bash
scripts/jev-profile-calibrate validate --all
scripts/jev-profile-calibrate dry-run-budget --all --repetitions 3 --max-attempts 600 --max-input-tokens 1500000 --max-seconds 1500
scripts/jev-profile-calibrate run --all --repetitions 3 --max-attempts 600 --max-input-tokens 1500000 --max-seconds 1500 --live
scripts/jev-profile-calibrate verify-reports --all
```

`run` and `resume` require `TYPESAFE_API_KEY` in the process environment and
explicit `--live`. The runner uses concurrency one, forces transport retries to
zero, reserves the documented 64k-token maximum context before every request,
and writes atomic mode-`0600` checkpoints without state or raw provider payload.
Choice, Noul, and Score metrics are computed per unique case after three
repetitions. Reports are independent per profile under
`workflow/runtime/jev-profile-calibration/`; `summary.json` has no bundle
promotion verdict.

The 2026-09-19 calibration used 459 provider attempts and 331,506 input tokens
for a measured input cost of `$0.013923252`. Only `task-state-fallback` passed
all frozen quality and safety gates. The other eleven profiles remain
`needs_tuning`; this result changes neither their checked-in authority nor their
uncertainty thresholds. See
`workflow/runtime/jev-profile-calibration/README.md` for the bounded findings.
