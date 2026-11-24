# Implemented: own-only purge remembers PR authors across ticks

## Metadata
- Archived: 2026-11-24
- Source plan: `PLAN.md` — own-only purge remembers PR authors across ticks
- Source plan SHA-256: `ac7f14de9f4652f099a460200aac8573d63cc8a0f4f4ffc5888efa21c6255aa2`
- Status: IMPLEMENTED
- Tier: standard; review: single
- Commit / branch: fix/own-only-purge-settled
- Workflow initiative: none

## Outcome
- `purge_foreign` keeps PR authors in `$STATE_DIR/authors` across ticks. A known key costs no `gh pr view`, and the purge outcomes are unchanged.
- A failed author read is never stored. It is asked again on the next purge, and the purge still returns 3 (fail closed).

## Context
- `watch.sh` `purge_foreign`: the author cache was a per-call `mktemp`. The enumeration includes every `.status`, and the purge writes `skipped own-only` into it, so settled keys were asked again on every tick. On macbook-work that meant ~37 `gh pr view` per tick, ~40 s of a 60 s tick, before any request was served.
- `own-only.sh` `pr_author_login`: returns a lowercased login, and fails on an empty one.

## Decisions
### Remember authors, not outcomes
- Context: settled keys were re-read forever.
- Choice: persist successful author reads. The purge logic itself is untouched.
- Rejected options: skip keys whose status already reads `skipped own-only` / `skipped posting-off` / dryrun. That adds status rules, and it would leave a pre-switch foreign dryrun status unsettled.
- Rationale: a PR author does not change, so caching it changes nothing in the purge decisions. The watch-list loop benefits too.
- Consequences: one short line per PR ever seen, with no pruning.

## Accepted Drift
- None.

## Validation Evidence
- `bash tests/pr-review-own-only-smoke.sh`:
  - result: before the fix, the new case was red (the second purge re-read #26 and #27). After the fix, it is green, ending with `ok own-only: ...`.
- `bash tests/pr-review-flow-smoke.sh`:
  - result: exit 0, `PR review flow smoke test: ok`.
- mutation:
  - result: the probe was unavailable (no `sandbox-exec` on Linux). A manual mutant that caches failed reads was killed by the new case.
- review:
  - result: one fresh-context reviewer (Logic axis), GO WITH NOTES. Two low notes were not acted on: no pruning of the file, and a theoretical torn line.

## Follow-up State
- Remaining risks: if the owner's GitHub login is renamed, own keys read as foreign. They are then skipped, never posted. Deleting `authors` resets the cache.
- Parking lot: `pr-autoreview` (pre-push, Slack) and the own-only dry-run both review own PRs. This is duplicate spend, an owner decision.
- Superseded docs/specs: none.
- Next links: none.
