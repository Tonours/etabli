# TypeSafe architecture review

`scripts/typesafe-architecture-review` is a read-only semantic gate for an
architecture `PLAN.md`. A reviewer invokes it explicitly. It never changes the
plan, grants write permission, approves spending, or replaces deterministic
tests.

The command sends one bounded request to TypeSafe System One:

- `Noul` judges four independent risks: duplicated policy, unsupported
  assumptions, hidden behavior changes, and missing validation.
- `Choice` selects `pass`, `revise`, or `block` for the supplied plan and
  evidence.
- `Score` rates abstraction depth, implementation specificity, validation
  strength, and scope discipline.

The versioned composition table lives in
`scripts/lib/typesafe-architecture-review.mjs`. Uncertain answers produce
`revise`; a blocking risk outranks the aggregate score. A `pass` only passes
this semantic review. The normal `READY` guard and all repository checks still
apply.

Only root `PLAN.md` and explicitly named, repository-contained evidence are
eligible. Evidence other than root `PLAN.md` must be tracked. External symlink
targets, session exports, and likely secret files are refused before a request
is built.

Live mode requires `TYPESAFE_API_KEY`. The endpoint, timeout, request and
response ceilings, redirect policy, model, rubrics, and thresholds are fixed in
the implementation. Reports contain input hashes, raw typed answers, model
usage, and `provenance: live`.

`--fixture-response` tests request/response composition without credentials.
Its report says `provenance: fixture` and `semantic_review: not_run`; it is not
evidence that TypeSafe reviewed the current plan.

```bash
scripts/typesafe-architecture-review --preview --evidence workflow/spec.md
scripts/typesafe-architecture-review --json --evidence workflow/spec.md
```

Live network evaluation requires `--live`; without it, use `--preview` or
`--fixture-response`. Preview exposes hashes and byte counts only. Secret-like
content is rejected before egress. The shared no-store transport keeps the
architecture-specific 20-second timeout and response-size bound, with no retries.
