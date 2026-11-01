# Implemented: faster review launches and validated council state

## Metadata
- Archived: 2026-11-01
- Source plan: `PLAN.md` - review detection and speed
- Source plan SHA-256: `3ff655b65829f104b0800cde41295cd886a655d83fa80e6bc3ab1ce51528acfb`
- Status: IMPLEMENTED
- Commit / branch: `feat/review-detection-speed`, stacked on `cdb77923`
- Workflow initiative: review-detection-speed

## Outcome
- Watcher source defaults: settle600 ->120 seconds; new launchd installs poll300 ->60 seconds. Explicit overrides, concurrency2 and global daily20 caps remain.
- Existing usage log and stderr gain per-Claude/Codex subprocess wall seconds and process exit. Timeout is recorded when control returns; signal-terminated samples remain incomplete. No report-protocol or semantic-exit change.
- Pending/ticketed/invalid councils cannot establish completed state, even when findings were posted. The phase-A override uses the same gate. Stored council reports are revalidated by full SHA before verify or approval retry; missing/inconsistent state gets a full council under normal caps. Invalid pending approval removes status/body and queues the next tick instead of running a model synchronously.
- Whole marker objects, both existing prefixes, exactly one phase-B header, one JSON value per marker and unique keys are checked. Every matching marker must be complete; maximum finding count preserves the native override without letting a later clean copy hide a pending or positive result. Parser diagnostics persist headlessly.
- Temporal-trace prompt candidate rejected after frozen diagnostic; Logic template restored exactly to cdb77923. No model, effort or pass default changed.

## Context
- `watch.sh:19` and `install.sh:7` supplied600/300 defaults; earlier tests bypassed settling with0.
- `lib.sh` logged native usage without wall duration. Existing pass functions and usage log were reused.
- A real-decision/fake-service probe reproduced5 pending lifecycle failures, including later-push approval despite unresolved state. Legacy/inline/scalar attacks reproduced6 failures; fenced/header/field-order/duplicate/multivalue attacks reproduced14 failures. Green regressions exercise the same decision code with valid neighbors.
- Work is isolated: no linked checkout update, LaunchAgent load, remote write, merge, push or deployment. The original main worktree's unrelated untracked plan was preserved.

## Decisions
- Keep the existing parallel council. Do not add agents, passes, metrics services, quotas or a new dependency. Reuse jq streaming to reject duplicate keys before ordinary JSON normalization.
- Preserve HTML and legacy terminal prefixes; closing decoration remains optional for compatibility. Full JSON and eligibility govern approval, not punctuation. Malformed control lines conservatively refuse the report even before their kind/SHA can be established.
- Security must be a nonempty string; ticketed is refused case-insensitively, other vendor statuses remain compatible. Lenses must be nonempty string-valued arrays/objects, with pending for unresolved work. Real external vocabulary remains unverified.
- Refresh an inconsistent clean/report tuple once rather than reuse a possibly stale pending-approval body. Consistent completed reports regain cheap verify; this recovery is tested. Reports expire after30 days and can require another full review each retention interval.
- A pending model run with unposted findings stops at rc4 instead of retryable rc1. New push starts a full council until resolved. Noncanonical integer text such as0.0 may conservatively withhold approval.

## Frozen detection and effort diagnostic
Command: `python3 experiment.py` (private throwaway driver); exact CLI argv, templates, patches and content hashes are frozen in `frozen-experiment.json`, SHA-256 `346df67f382df8e5fb3e91974fa7d6cc9722694f6d04883f51c21158d6f1763f`.
Direct Claude2.1.316, requested/effective Sonnet5.5, Read/Grep/Glob only, requested medium/high effort, one run per arm/case, two calls concurrently at most,30-minute per-call deadline. Oracles/earlier reviews withheld. All9 calls complete without denials/retries; input hashes verified before and after. This diagnostic runner omits the live agent's Bash/Skill tools and is not the full production chain.

| Arm | Target mechanisms | H7 control findings | Median wall (s), n=3 |
| --- | --- | --- | --- |
| Baseline medium |0/2 |0 |30.234 |
| Candidate medium |0/2 |0 |23.750 |
| Candidate high |0/2 |0 |54.780 |

| Arm | Median input | Cache creation | Cache read | Output |
| --- | --- | --- | --- | --- |
| Baseline medium |8 |27207 |61788 |3120 |
| Candidate medium |6 |25975 |34082 |2956 |
| Candidate high |20 |46135 |266404 |5545 |

Categories are independent native medians, not price or savings estimates. Baseline had2 non-target findings (one true, one indeterminate); each candidate had1 true non-target finding. Each arm had1 unresolved question, counted separately. No adjudicated false finding is not population precision. Human correction time was not measured.
H3/T5 are known reconstructed cases and H7 a known control; T5 was development, none held-out. Historical content hashes mismatch: **replay: unavailable (historical tree-hash mismatch)**; these newly frozen paired inputs are not old replay scores. No detection, production speed or effort gain established. No post-result tuning; candidate discarded. Durable aggregates here; raw private source, oracles, manifests, receipts and `diagnostic-results.json` remain outside Git.

## Validation Evidence
- `scripts/verify-agentic-infra core`:13/13, final log `etabli-review-speed-d2-core.log`.
- `scripts/verify-agentic-infra shell-docs`:38/38, final log `etabli-review-speed-d2-shell.log`; flow730/730 assertions, gates83/83. Includes real decision functions with fake GitHub/provider boundaries and local Git fixtures, not hosted CI or live delivery.
- `git diff --check`: clean. Logic template diff against cdb77923: empty.
- Final source review base `50c9e4bf26c2526faaff9fc2b1687f9a4d199347`; cumulative source patch SHA-256 `db76e70d4d3fdf13fb07d825084198738543c668f1badd08132123adfad29f11` (before this archive).
- T1/T2/D1 findings folded under refreshed READY contracts; final D2 full cumulative review: Logic GO with complete deciding-code rows; Spec low optional-ending note disposed explicitly; Threat GO WITH NOTES with all six tables; cross-family adversary GO WITH NOTES, no remaining concrete bug or unmet AC. All four requested/effective Opus5.5, direct isolated read-only Claude2.1.316, complete/no denials; author OpenAI. Parent lead GO WITH NOTES. Native receipts verified, not inferred from requested model.
- Mutation: final parser/timing probe1 survived of12 scored,1 justified (15 generated/12 sampled). Reuses gates plus the unchanged timing case extracted from existing flow fixture definitions; exact command in private `mutation-command.txt`, driver `mutation-driver.py`, base cdb77923. Unchanged cache-guard probe1/2 survived,1 justified. **mutation:2 survived of14,2 justified**; supplementary pending-branch probe2/2 killed. macOS write sandbox; cache allow-write is required because existing fixtures create unique directories there. No denied/invalid/timeout scored results.
- Justifications: timing `|| :` -> `&& :` is equivalent because colon has no side effect and the following group overwrites status. Cache early-read conjunction differs only for a partial I/O read that emits a complete valid SHA before failing; native regular-file fault injection is unavailable here, so that side effect remains untested and the original fail-closed guard is retained. No whole-system mutation score claim.
- **simplify: clean**. **quality: pass**, parent sibling comparison of existing usage/JSON validation/canonical-report code. No new subsystem or dependency.

## Accepted Drift
The initial speed slice uncovered inherited approval-state and ambiguous-marker escapes in the preceding unshipped change. Scope expanded to close those concrete cases, preserving the previous immutable archive. The frozen prompt experiment failed adoption; its template change was removed rather than promoted. Producer vocabulary was unavailable, so safety validation is deliberately stricter and activation remains outside this source-only task.

## Follow-up State
- **REVIEW-1 (local follow-up, no external issue): native validator write policy.** `run.sh` already grants the model a broad GitHub reviews command prefix; COMMENT-only events are prompt policy, not proven tool enforcement. This pre-existing path is outside the invoker metadata fix and remains unproven in the absent native validator integration. Before activation, inspect/enforce its review-event boundary with a genuine native permission test, keeping COMMENT working. Human checkpoint required; no claim this task secures every model-side write path.
- **REVIEW-2 (local follow-up): real producer preflight.** Before any merge into the linked checkout or activation, inspect a genuine validator report and run the new parser read-only on it. Confirm marker framing, lenses/security vocabulary and ordinary completed nonzero findings; verify actual write permissions with REVIEW-1. If nonconforming, retain old deployment until producer alignment. No log-only fallback is allowed to restore the known pending approval bypass.
- Availability risks: about5x snapshot invocation frequency, push churn/global-cap exhaustion, one full refresh of legacy/missing reports and conservative malformed-control refusals. Defaults and rollback are documented in `claude/README.md`; live launch latency, API load, escaped-defect rates and human benefit remain unmeasured.
- Next detection experiment needs genuinely held-out inputs and repetitions, not another tuning pass on these known cases.
