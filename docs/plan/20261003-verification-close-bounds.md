# Implemented: Bound verification closure and retain incomplete cleanup

## Metadata
- Archived: 2026-10-03
- Source plan: `PLAN.md` — Bound verification process closure and publish the repaired workflow
- Source plan SHA-256: `a30b54b8e6d430c479eb9564c3cb394fa437443a4f89fc7bb4f710811d59cf9a`
- Status: IMPLEMENTED
- Commit / branch: `fix/verification-close-bounds-20261003`; reviewed cumulative publication against `caa55b3390f5b722568737c77f1d098710fcee4f`
- Workflow initiative: `verification-close-bounds-20261003`

## Outcome
Verification command and service completion is bounded independently of the OS close event. Detached children holding inherited pipes now produce failed execution and retained incomplete cleanup instead of preventing the runner finally path. A forced receipt cannot pass either normal or owned-shutdown checks.

## Context
- The previous integration F2 reproduced an actual exited leader with a detached inherited-pipe child, an unresolved done promise and unreachable cleanup. Its source and blocked ledger stay frozen at `18e6a6a5ac87d1b4ed1e953a61bdd1469b177920`.
- The existing portable project-verification workflow and execution-quality changes are part of the cumulative publication; previous implemented archives remain immutable.
- Starter fixes are already published at `f098be14aca92bd48efada1b206897f73de23760`. CI run37106667140 failed the external braces advisory GHSA-vfj7-8cjw-p6xm; this repair does not suppress that audit.

## Decisions
### Separate completion from proof of reaping
- Arm timeout/interruption closure grace and the cleanup deadline before awaiting done. Release only parent-owned pipe endpoints when completion is forced.
- Latch `completion_forced` before release, keep ok/reaped false and reject forced receipts even with otherwise-passing real exit fields. Preserve missing legacy markers.
- Capture original leader birth only while live. A newborn miss stays pending, including after actual exit; an empty sample cannot prove reaping. Handoff requires that live birth, freezes member identities once, and uses fresh positive-PID birth checks. Member ESRCH cannot skip a live sibling. Retired groups cannot be reacquired.
- Keep sampled ps/signal race limits explicit. Unknown detached children are neither signaled nor claimed reaped.

## Accepted Drift
None. The new plan covers the distinct close/reaping defect and retains prior blocked round counters. T1 accepted the independently confirmed missing-birth cleanup finding; it rejected the incorrect last-nonempty ledger-selector finding using an independent sample and deployed lifecycle evidence.

## Validation Evidence
- Before/after: the actual runner detached-pipe case previously needed its watchdog rescue; the corrected runner reaches cleanup, retains a failed pack and declares processes_reaped=false. An actual owned exit0 service produces a forced receipt rejected on both otherwise-passing checker paths.
- Missing-birth actual exit: both empty and replacement observations failed before the correction; the corrected state stays pending, signals nothing and returns reaped=false.
- Focused Node verification suite: 190/190 passed, no skipped tests.
- Complete infrastructure group: 90/90 passed.
- Deployed CLI and actual Chromium: four expected positive/negative outcomes; passing flows archive/complete and negative zero-exit result commands remain rejected.
- Cumulative native xai/grok-4.7 Logic, Spec and cross-family code adversary: T2 rejected the independently refuted high handoff/zombie interpretations and accepted a documentation qualifier; D1 reviewed that narrow delta. Final F1 review must supply complete runtime deciding-code coverage; exact final review and remote/CI evidence are retained in the initiative ledger.
- Original checkout preservation: 61 initial file hashes preserved with current checkout baselines.

## Follow-up State
- Main publication is pending at archive creation; only observed push/SHA/terminal-CI results may be recorded as delivered in the initiative ledger.
- No global workflow installation or credential mutation. Recipe execution and actual observations remain distinct from optional agent-engine exit status.
- Controlled process-identity projections are guard coverage, not proof of real PID reuse or an atomic kernel identity lease.
- Historical blocked initiative: `.workflow/publication-integration-20261003/events.jsonl`; active publication evidence: `.workflow/verification-close-bounds-20261003/events.jsonl`.
