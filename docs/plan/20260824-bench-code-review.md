# Implemented: local hors-repo code-review bench

## Metadata
- Archived: 2026-08-24
- Source plan: `PLAN.md` — bench-code-review local hors-repo
- Source plan SHA-256: `1ac94f6105ff3bc887da16f403ae0ca5c100b793868f1b582c2569b2b898ce0a`
- Status: IMPLEMENTED
- Commit / branch: satellite `/volumes/crucial/work/bench-code-review` `ad83c7b`

## Outcome
- Sibling bench at `/volumes/crucial/work/bench-code-review` with 60 tasks (20 injected + 10 clean + 30 human), `live`/`score` modes, 70/15/15 scorer, boolean outcomes for `skill-eval`.

## Context
- Gold must stay out of `etabli` git (SWE-Bench memorization / Goodhart).
- `skill-eval.mjs` only accepts `frozen_public|external_isolated` and boolean `passed`.
- Live LLM review is ~1 min/PR; implement gate is `--sample 10` + heuristic harness.

## Decisions
### Two run modes
- Context: `<45s` + determinism incompatible with fresh LLM reviews.
- Choice: `bench.sh live` (fresh) vs `bench.sh score` (cached, deterministic).
- Rejected options: single `replay` command mixing both.
- Consequences: autoresearch loops on `score` only.

### Default harness heuristic
- Context: `pi-review-hunter` needs `pi` + ~1 min/PR.
- Choice: default `heuristic` (detects injected precedence/countStatus flips); `--harness pi-review-hunter` for real reviews.
- Rejected options: 10 live LLM calls as implement-done.
- Consequences: heuristic recall=1 on synthetic; human gold still unlabeled.

## Accepted Drift
- Original plan/spec: 30 Forest+Etabli PRs with review-comment gold; judge `claude-haiku-4-5`.
- Implemented reality: 6 etabli merged PRs + 24 local `git show` diffs; human gold has empty `findings` (placeholder); judge default unused in heuristic path.
- Why accepted: Forest crawl not required for v1 structure; haiku not in `enabledModels`; unlabeled human rows still exercise ingest/split/score plumbing.

## Validation Evidence
- command: `node eval/inject.mjs && node eval/collect.mjs && node eval/rebuild-manifest.mjs`
  - result: 20+10+30=60, splits 40/10/10
- command: `./bench.sh live --sample 10 --json`
  - result: 10 outcomes
- command: `./bench.sh score --json` twice
  - result: identical; `METRIC recall=1` `precision_hard=1` on heuristic+synthetic
- command: `skill-eval fingerprint scorer/`
  - result: `2fe582ac032df2a079a708ad4c166f939a623a408dec6e5d26dd1a4c79baff9c`
- command: `skill-eval compare` self
  - result: `status: comparable` `verdict: rejected` `candidate_fingerprint_unchanged` (expected)
- command: `scripts/verify-agentic-infra core`
  - result: 16/16 passed

## Follow-up State
- Remaining risks: human gold unlabeled (vacuous pass); heuristic ≠ real reviewer; no Forest PRs; self-family judge if LLM path used.
- Parking lot: label human findings; first regular `live --harness pi-review-hunter` on 60; online acted-on tracker.
- Next links: `/volumes/crucial/work/bench-code-review/README.md`
