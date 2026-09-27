# Answer Quality Contract

Shared contract for high-signal answers, research summaries, implementation
handoffs, and obvault-backed memory answers.

## Objective

A "10/10" answer is not a promise of omniscience. It is an answer that maximizes
usefulness under the available evidence, states uncertainty honestly, and avoids
extra work or prose that does not move the user's goal forward.

## Quality Gate

Before answering, check the smallest applicable set:

1. Intent: restate or infer the actual user goal, not just the literal words.
2. Sources: use local source of truth first; browse when facts are current,
   external, niche, high-stakes, or explicitly requested.
3. Grounding: separate observed facts, source-backed claims, and assumptions.
4. Specificity: include concrete paths, commands, dates, counts, statuses,
   links, or validation output when they affect the decision. When the answer
   rests on artifacts you inspected or produced — traces, logs, benchmark
   outputs, compared files, screenshots — name those artifacts by their exact
   filename and quote the decisive measured numbers (with units) in the final
   answer itself. A decision that cites its evidence by name is checkable; one
   that paraphrases it away is not. Apply the same rule to comparisons: name
   both compared artifacts and each side's measured result.
5. Completeness: answer every explicit requirement; name what remains
   incomplete instead of implying it is done.
6. Efficiency: prefer the shortest response that preserves the decision,
   evidence, and next action.
7. Actionability: end with the state, the validation, and the next useful move;
   do not add generic options.
8. Uncertainty: use `verified`, `stale`, `inconclusive`, `assumption`,
   `blocked`, or `not verified` when source strength matters.
9. Safety: do not invent citations, hide missing evidence, print secrets, or
   imply push/deploy/external write-back consent.
10. Review: before finalizing, compare the answer against the user's newest
    request and remove unsupported claims.

## Live Final Answer Gate

For live chat answers, apply the quality gate just before the final response:
answer the newest user request, keep only evidence that changes the decision,
state what is unverified, and avoid promising a perfect numeric score. This is
a last-pass discipline, not a new artifact or subjective scoring step.

Emit the matching reply shape in the last message:

- Diagnosis: question, artifact filename, quoted numbers, verdict label, next
  action. Performance adds the frozen command, sample count, and an honest
  p95/median ceiling — never a single-run p95.
- Compare: both artifact names (keep user-named paths such as
  `docs/compare-a.md` even when blinding authors), both measured results,
  verdict.
- Hillclimb: frozen command, budget, ≥3 measured rows, stop reason, next lever.
  If the metric command hangs or a serve/coverage check fails twice, abort it
  and answer with the rows you have — being killed is not a progression.
- Implementation: files, checks `N/N`, `simplify: clean|removed N`.

## Route Rules

- Simple answer: answer directly, but cite local files or web sources when the
  claim is not obvious or stable.
- Repo/workflow answer: inspect current files and Git state first; never rely on
  memory alone for drift-prone status.
- Research answer: include source URLs and confidence labels; validate repo
  research artifacts with `scripts/research-proof-check`. <!-- etabli-only -->
- Implementation handoff: report files changed, checks run, results, remaining
  risks, archive state, and whether `PLAN.md` still exists.
- obvault-backed answer: bounded, cited context pack first, per
  `workflow/skills/obvault-memory.md`.

## Mechanical Check

Use `scripts/answer-quality-check` for durable research artifacts, repo <!-- etabli-only -->
handoffs, implementation summaries, and obvault-backed notes that are written to
disk. The helper validates objective markers: source evidence, local-path or
command evidence, uncertainty labels, validation/risk markers, obvault
entrypoints, and unsupported perfection overclaims.

This helper is a quality floor, not a score. Passing it does not prove an
answer is "10/10"; failing it means the artifact is missing evidence expected
by this contract.

## Helper Eval And Evidence

`scripts/answer-quality-eval` (fixture corpus) and the evidence base behind <!-- etabli-only -->
this contract are documented in `docs/answer-quality-traces/README.md`.
