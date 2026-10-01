# Implemented: read-only workflow statistics and recurring patterns

## Metadata
- Archived: 2026-10-01
- Source plan: `PLAN.md` — Read-only workflow statistics and recurring patterns
- Source plan SHA-256: `ad58eec05223f5178909b279fa44dc7f41b7beca9eba3808689812b03af4c7b6`
- Status: IMPLEMENTED
- Commit / branch: local workspace changes; no commit or publication
- Workflow initiative: workflow-pattern-stats

## Outcome
- `scripts/workflow-ship-metrics` now provides a readable local report and compatible JSON enriched with stable issue identifiers, distinct project/initiative counts, observation dates and source-line evidence.
- An explicit JSON inventory enables reports across project roots. No project discovery, provider classification or automatic correction is performed.
- Pi and Claude no-comments fixtures use temporary working directories; historical guard journals remain byte-identical.
- Verified implementation, independent final review completed, simplify: clean.

## Context
- Context: The retired retrospective script no longer provided access to archive-derived patterns. The existing metrics reporter was the smallest maintained access point.
- Context: Current guard records lack reliable origin and initiative identifiers. They cannot establish trusted initiative recurrence.

## Decisions
### Reuse existing sources and retain coverage limits
- Context: Ledgers, journals and implemented archives have different provenance and identity precision.
- Choice: Stable fixed identifiers for recognized issues, exact fingerprints for other accepted findings/blockages, check-specific validation fingerprints and canonical project/slug deduplication. Cite paths, lines and timestamp basis.
- Rationale: Keep the report deterministic and read-only; do not infer real usage or delivery from sparse sources.
- Consequences: Missing metrics remain unmeasured. Guards stay separate and unattributed. Ambiguous archive identities and mixed positive/negative lines are conservatively excluded.

### Explicit project inventory
- Choice: `--projects <json-file>` replaces `--dir` for reporting. Reject invalid roots, canonical duplicate aliases and shared Herdr history.
- Rationale: Same initiative slugs in different projects remain distinct; absent sources are visible per project.

## Accepted Drift
- Original plan/spec: Readable reports with preserved JSON fields and test isolation.
- Implemented reality: Text additionally preserves existing checkpoint, CI, registry and Herdr counters. The existing core report check includes the isolation regression without changing check membership.
- Why accepted: Preserve existing observable metrics and continuously catch journal pollution.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: PASS 29/29 checks; `.workflow/workflow-pattern-stats/final-core.log` includes 444/444 Pi tests, 19/19 pattern tests, typecheck and reporter/isolation smoke.
- command: `scripts/workflow-context-budget`
  - result: PASS 8/8 surfaces; `git diff --check` also passed.
- command: `scripts/workflow-ship-metrics --dir .workflow report --since 2026-09-01 --until 2026-10-01 --json`
  - result: `.workflow/workflow-pattern-stats/live-report.json` and `live-report.txt`: largest issue group has 6 distinct initiatives; 25 guard observations remain unattributed; 3 archive/source diagnostics. Explicit single-root portfolio also ran successfully (`live-portfolio.json`). This is source coverage, not accepted-delivery evidence.
- Evidence: `.workflow/workflow-pattern-stats/journal-before-tests.json` SHA-256 comparison after final checks: unchanged 2 historical journal files.
- Evidence: Final F1 cumulative patch SHA-256 `f396bfb0b32ef068ad30a5af33b17aea9be4795f256b84c860d472eef0308c3c`; fresh Logic GO with complete deciding-code table, Spec no findings, parent Standards pass; cross-family Claude Opus 5.5 / firstParty GO WITH NOTES, session `cdb20320-0f17-4ee6-b737-5f0a9fbd2bb6`. Optional coverage extensions were not folded; see `.workflow/workflow-pattern-stats/reviews/F1-lead.json` and the event ledger.

## Follow-up State
- Remaining risks: Fixed phrases and exact fingerprints do not classify every paraphrase. Legacy July plan-adversary `accepted` / `finding` shapes are not classified; supported extraction reads `accepted_findings`. Qualified archive dates remain excluded with explicit diagnostics. Readable source availability does not imply exhaustive semantic coverage.
- Remaining risks: Cost, review-time, accepted-merge and revert receipts are absent locally; success rates and delivery quality remain unmeasured. Historical guard provenance remains unknown.
- Parking lot: HTML consumer of JSON; trustworthy guard origin/initiative metadata; broader legacy parser coverage with explicit fixtures.
- Next links: `docs/workflow-statistics.md` explains daily commands, archive grammar and explicit multi-project access.
- Archive state: implemented record written after final review; root `PLAN.md` is removed by the hash-checked cleanup command. No push, deployment or historical cleanup authorized.
