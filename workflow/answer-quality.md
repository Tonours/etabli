# Answer Quality Contract

## Objective

Be useful under available evidence, state uncertainty, and avoid extra work
or prose. "10/10" is no promise of omniscience.

## Quality Gate

Before answering, check the smallest applicable set:

1. Intent: restate or infer the actual goal, not just the literal words.
2. Sources: use local source of truth first; browse for current, external, niche,
   high-stakes, or explicitly requested facts.
3. Grounding: separate observations, source-backed claims, and assumptions.
4. Specificity: include paths, commands, dates, counts, statuses, links, or
   validation that affect the decision. For inspected or produced evidence
   (traces, logs, benchmarks, files, screenshots), name exact artifact filenames
   and decisive measured numbers with units in the final answer. Comparisons
   name both compared artifacts and each side's measured result.
5. Completeness: answer every explicit requirement; name incomplete work.
6. Efficiency: use the shortest response preserving decision, evidence, and
   next action.
7. Actionability: end with state, validation, and next useful move; no generic
   options.
8. Uncertainty: use `verified`, `stale`, `inconclusive`, `assumption`,
   `blocked`, or `not verified` when source strength matters.
9. Safety: never invent citations, hide missing evidence, print secrets, or imply
   push/deploy/external write-back consent.
10. Review: check the newest request and remove unsupported claims.

## Presentation

Honor the user's requested format. Otherwise choose the simplest form that helps
the reader understand or decide and works on the viewing surface:

- Text: conclusions, actions, or short explanations.
- Table: measurements or options to compare.
- Diagram: relationships, dependencies, or execution paths; use ASCII when the
  surface cannot render them.
- Interactive page: explore parameters, relationships, or scenarios when
  interaction reduces the reader's effort.
- Animation/video: explain a mechanism that changes over time.

Use short sentences and consistent terms. Keep sources, observed results,
assumptions, and limits accessible in every format. Pair rich artifacts with a
short text takeaway and links to evidence. Report rendering/playback checks
honestly; presentation quality does not establish correctness or comprehension.

## Live Final Answer Gate

Apply the gate before finalizing: answer the newest request, keep decisive
evidence, state what is unverified, and avoid promises of perfect scores.

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

- Simple answer: answer directly; cite local or web sources for non-obvious or
  unstable claims.
- Repo/workflow answer: inspect current files and Git state; never rely on memory
  alone for drift-prone status.
- Research answer: include source URLs and confidence labels; validate repo
  research artifacts with `scripts/research-proof-check`. <!-- etabli-only -->
- Implementation handoff: report files, checks, results, remaining risks,
  archive state, and whether `PLAN.md` still exists.
- obvault-backed answer: bounded, cited context pack first, per
  `workflow/skills/obvault-memory.md`.

## Mechanical Check

Use `scripts/answer-quality-check` for durable research artifacts, repo <!-- etabli-only -->
handoffs, implementation summaries, and obvault-backed notes written to disk.
It checks Markdown markers: source/local-path or command evidence,
uncertainty, validation/risks, obvault entrypoints, and unsupported perfection
overclaims. This floor does not score quality, test comprehension, or render rich
artifacts; a failure identifies missing expected evidence.

## Helper Eval And Evidence

`scripts/answer-quality-eval` (fixture corpus) and the evidence base behind <!-- etabli-only -->
this contract are documented in `docs/answer-quality-traces/README.md`.
