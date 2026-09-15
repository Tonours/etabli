# Reviewer evaluation corpus

This public corpus contains synthetic, reproducible cases only. Operational
evidence, source references and private narratives are retained in the approved
private knowledge base and are represented here by stable synthetic IDs.

## Public contract

Each case records a defect class, an expected reviewer action, and an aggregate
outcome. It must not contain credentials, private paths, provider identifiers,
repository identifiers, pull-request references, or raw logs.

| id | defect class | expected action | status |
| --- | --- | --- | --- |
| fixture-review-alpha | retrieval gap | open deciding code | held-out |
| fixture-review-beta | evidence gap | cite observable evidence | held-out |
| fixture-review-gamma | scope boundary | record no-op | held-out |

### fixture-review-alpha

Input: `{"decision":"pass","evidence":["summary"]}`
Expected defect: the decision has no decisive evidence.
Oracle: reject the pass and request a bounded evidence reference.

### fixture-review-beta

Input: `{"claim":"safe","proof":[]}`
Expected defect: the claim has an empty proof set.
Oracle: mark the result unmeasured and require one observable proof.

### fixture-review-gamma

Input: `{"change":"format-only","scope":"unknown"}`
Expected defect: the requested scope is not established.
Oracle: record no-op and do not mutate the workflow.

## Evaluation rules

1. Keep generators and held-out cases independent.
2. Record one aggregate row per evaluation run.
3. Treat missing evidence as unmeasured, never as a successful result.
4. Preserve the public/private boundary when adding future fixtures.

See `workflow/skills/reviewer-improvement-loop.md` for the reusable contract.
