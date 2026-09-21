# Jev profile calibration — 2026-09-19

This directory contains the frozen, sanitized observations and recomputable
metrics from the live TypeSafe/Jev calibration of the original twelve semantic profiles.
It is evidence for profile-by-profile tuning, not a bundle promotion decision.
`campaign.json` binds every report and the summary to one immutable campaign
contract and preserves authoritative measured-or-reserved budget totals.
Each migrated report preserves the original checkpoint-backed
`collection_identity` and records the legacy CLI fingerprint as unavailable;
`recompute_identity` independently binds the current metric implementation.

## Campaign

- Model: `jev-1.13.0`
- Repetitions: 3 per semantic case
- Provider attempts: 459
- Input tokens: 331,506
- Output tokens: 76,418
- Measured input cost: `$0.013923252`
- Provider errors: 0
- Retries: 0
- Concurrency: 1

The run remained below the frozen limits of 600 attempts, 1,500,000 input
tokens, and 1,500 seconds of dispatch time. The runner reserved the documented
64k maximum request context before each call and persisted only sanitized state
fingerprints, typed answers, decisions, usage, and latency.

## Verdicts

| Profile | Verdict | Main failing gate(s) |
| --- | --- | --- |
| `task-state-fallback` | `passes_current_thresholds` | none |
| `skill-suggestion` | `needs_tuning` | final coverage, no-match accuracy, and safety |
| `claim-evidence` | `needs_tuning` | `material_claim` |
| `reviewer-finding` | `needs_tuning` | safety cases |
| `self-improvement-candidate` | `needs_tuning` | `bucket`, safety |
| `project-hunt-evidence` | `needs_tuning` | evidence kind, proposed commitment, counterevidence |
| `conversation-signal` | `needs_tuning` | scope, reversibility, verification, concise reporting |
| `knowledge-passage` | `needs_tuning` | usable evidence and premise contradiction |
| `linear-intake` | `needs_tuning` | behavior count and context sufficiency |
| `pr-qa-impact` | `needs_tuning` | risk, API, performance, concurrency |
| `no-progress-equivalence` | `needs_tuning` | safety cases |
| `goal-completeness` | `needs_tuning` | verifier, scope, stop rule, permission boundary |

`task-state-fallback` reached 91.7% case accuracy, 100% accepted accuracy,
83.3% accepted coverage, and 100% stability. Passing the frozen gates does not
change its advisory authority: promotion still requires an independent review
and fresh held-out evidence.

The skill stage-one `candidate` and `needs_skill` questions passed their frozen
gates, and shortlist recall reached 100%. Final selected-skill accuracy was
83.3% and stability 100%, but accepted coverage was only 33.3% and strict
no-match accuracy 66.7%. This separates stable candidate/selection ranking from
weak threshold acceptance and no-match behavior.

The additive `self-improvement-diagnosis` profile is not part of this historical
campaign. It is marked `pending_corpus` and is excluded from `--all`; no live
quality, safety, or activation claim exists for it.

On the 2026-09-20 checkout, corpus validation still passes for all twelve
historical profiles. Full report verification is stale at `skill-suggestion`
because its current catalog fingerprint no longer matches the collection-time
identity. Do not migrate that collection identity or present the reports as
current; refresh it only through a separately authorized calibration campaign.

## Reproduction and verification

```bash
scripts/jev-profile-calibrate validate --all
scripts/jev-profile-calibrate dry-run-budget --all --repetitions 3 --max-attempts 600 --max-input-tokens 1500000 --max-seconds 1500
scripts/jev-profile-calibrate verify-reports --all
```

Use `recompute-reports` to recalculate metrics from the stored observations
after metric-code changes. Do not tune thresholds against this same corpus;
freeze a new versioned holdout corpus before evaluating any candidate change.
