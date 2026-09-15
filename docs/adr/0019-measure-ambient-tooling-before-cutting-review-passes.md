---
status: accepted
date: 2026-08-26
tags: [tooling, hooks, review, metrics, token-efficiency]
affected_components: [workflow/self-improvement/review-metrics.md, workflow/skills/adversary.md, workflow/skills/ship.md]
---

# Measure ambient tooling before cutting review passes

## Context

An efficiency review proposed reducing review passes and instruction layers.
The proposal mixed portable workflow rules with machine-local tooling.
Before changing either layer, the review separated correctness from cost.

The first filter was a fresh reasoning pass. It found that two review samples
read different evidence, so the samples are not identical even when the model
family is the same. It also found that delegated work can protect the parent
from context exhaustion. Neither observation justified a contract change.

The second filter measured the alleged duplication. The repeated text was only
a small fraction of the resident chain; topic overlap was not recoverable text.
Removing a preference-driven tool catalog would also have changed user intent.
Those options were rejected because their benefit was not demonstrated.

The final filter exposed a correctness defect in an output-rewriting hook. A
colon-bearing match was parsed as a different file and line, and a count query
returned a listing. Evidence built through that path could not be trusted.

## Decision

1. Native search commands are excluded from the output rewriter. The portable
   hook configuration documents the exclusion for both equivalent commands.
   The optimized proxy remains available for commands whose output is safe.
2. Machine-local constraints receive machine-local fixes. Shared workflow
   contracts are not weakened to compensate for one workstation's limits.
3. The second review sample remains required and gains a marginal-yield field.
   A measured series is required before proposing to relax the requirement.
4. Tool precedence is documented in a stable sibling instruction. The generated
   instruction remains owned by its generator and is not edited in place.
5. No token-reduction proposal is actionable without a measured quantity,
   reproducible command, baseline, and an explicit uncertainty statement.

## Consequences

- Search evidence is trustworthy again, which protects every downstream review.
- The double-sample debate has a data field instead of competing intuitions.
- Some claimed compression is forfeited until its output is shown correct.
- Historical rows without the new measurement remain explicitly unmeasured.
- The stacked rewriters still have order-sensitive precedence; no incorrect
  output was observed in scope, so that follow-up remains parked.
- A lower-level instruction can still appear in a generated chain; precedence
  subordinates it rather than pretending that it does not exist.

## Validation contract

Every future change records the native command, the optimized command, and the
expected equivalence relation. A fixture must include a delimiter-bearing line,
a count query, and a normal match. The test compares bytes, not presentation.

The measurement report keeps resident characters separate from billed tokens.
Provider receipts are not inferred from static character counts. Unmeasured
values remain unmeasured in the ledger and cannot be promoted by prose.

## Operational boundary

The public record describes reusable controls and their acceptance criteria.
It does not carry private case identifiers, machine paths, or raw transcripts.
Those details belong in the approved private knowledge store for their context.

The public replacement keeps the reason a control exists, the safe interface,
and the test shape. It omits who ran a case, which customer was involved, and
which local installation produced the observation.

The distinction is part of the decision, not a later editorial preference.
Reviewers can reproduce the invariant with synthetic fixtures and local tools.
They cannot infer an individual's history from the published document.

## Review method

The reasoning pass checks intent and information asymmetry.
The measurement pass checks byte counts and compares like-for-like surfaces.
The empirical pass checks a real fixture through native and optimized paths.
Each pass records its input, output, and unresolved uncertainty.

A pass that reports only a green status is insufficient evidence.
The ledger must identify the command, scope, and artifact hash.
Missing receipts stay marked missing until a real run supplies them.

## Reuse guidance

Use the native command whenever output parsing is part of the evidence.
Use an optimization only when its equivalence is tested for that output shape.
Keep generated files under generator ownership and document stable overrides.
Never trade a small context saving for an unbounded correctness risk.

This record is intentionally portable: it applies to any compatible harness,
without naming a vendor, account, workstation, or deployment environment.

## Follow-up

The next review should collect enough independent rows to estimate marginal
defect yield. It should also verify that generated instructions survive a
regeneration cycle. Until both checks are complete, the conservative gate is
the accepted contract.
The archive remains valid only while those measurements and boundaries hold.
