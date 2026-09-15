# Implemented: safe search output and double-sample measurement

## Metadata
- Archived: 2026-08-26
- Source plan: the measured subset of the workflow efficiency proposals
- Status: IMPLEMENTED
- Commit / branch: local working tree at archive time

## Outcome
- Native search commands no longer pass through the unsafe output rewriter.
- The optimized proxy remains available for commands with a tested output shape.
- The review metrics table gained an `adversary_unique` column.
- Historical rows keep an explicit `n/a` value rather than an invented result.
- The stable tool-precedence note is separate from generated instructions.
- The rejected efficiency proposals remain documented with their rationale.

## Context

The rewriter parsed delimiter-bearing search output as structured fields.
That turned a valid match into an invented file and line, and a count query
returned a listing. A review based on that output could not be reproduced.

The same implementation handled two commonly used search commands, so fixing
only one name would have left the defect reachable through its twin.

The efficiency discussion also confused topic overlap with duplicated bytes.
The measured duplicate was small, while the correctness risk was not small.

## Decisions

### Fix the tool, not the review contract

- Exclude both equivalent search commands from rewriting.
- Keep the shared review passes and delegation rules unchanged.
- Do not prune a user preference catalog to buy unmeasured context.
- Treat the native command as ground truth for evidence-producing output.

### Instrument rather than cut

- Keep the double-sample adversary until a measured series supports a change.
- Record whether the second sample found a unique actionable defect.
- Keep missing historical values unmeasured; do not backfill by inference.

### Separate portable and local concerns

- Put machine-specific hook settings in a machine-owned note.
- Keep the repository contract portable across compatible harnesses.
- Describe interfaces and tests publicly; keep operational case data private.

## Validation evidence

- A delimiter-bearing fixture is compared byte-for-byte through both paths.
- A count query is checked independently from a normal match query.
- The two command names produce equivalent native output after the exclusion.
- The metrics definitions and log header have identical column order.
- The repository validation suite remains green after the change.

## Rejected options

The standard double-sample was not removed because the samples read different
evidence. Delegation was not removed because it absorbs implementation churn.
The instruction chain was not deduplicated without a byte-level measurement.
The tool catalog was not pruned because preference is not a defect.

## Accepted drift

The initial proposal mentioned editing a generated instruction in place. The
implemented note lives beside that generated file so regeneration cannot erase
the rule. The initial exclusion named one command; the equivalent command was
added after the implementation path was checked.

## Consequences

- Evidence-producing search output is trustworthy.
- Claimed compression is forfeited until equivalence is demonstrated.
- The marginal-yield column makes future relaxation measurable.
- The conservative gate remains in force while that column is empty.
- Order-sensitive stacked rewriters remain a parked follow-up.

## Follow-up

Collect independent rows, verify a regeneration cycle, and revisit the gate only
after the result is reproducible. Static character counts must stay separate
from provider-billed tokens; no billing claim follows from this archive alone.

## Reproduction guidance

Run the fixture with the native command first and save its bytes.
Compare the optimized path only after the native output is known.
If the outputs differ, stop the optimization and retain the native result.
Record the command, fixture, and comparison result in the ledger.
Do not convert a successful local probe into a general performance claim.
The archive is complete only when those evidence fields are present.

## Public/private boundary

This archive keeps the reusable invariant, fixture shape, and acceptance rule.
It intentionally omits customer names, local paths, account references, model
labels, and raw transcripts. Those belong in the approved private store for
the relevant context and are referenced only by an opaque migration receipt.
