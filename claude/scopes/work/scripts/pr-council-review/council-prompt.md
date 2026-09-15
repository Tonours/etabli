/validator {{PR_NUMBER}} {{REPO}}

Run the Forest Validator pass exactly as the skill defines it. Every mandated
retrieval, every mandated delegation, every failure class. Nothing below
replaces a lens, weakens the skeptic gate, or changes the emit contract.

Two additions, and only these two.

## Extra candidate findings for step 6

Review passes already ran against this same PR head, in a scratch worktree
checked out at `{{HEAD_SHA}}`, over the diff `{{MERGE_BASE}}...{{HEAD_SHA}}`:

- `{{REPORT_QUALITY}}` — the `/code-review` skill's three axes (Correctness,
  Standards, Spec), each from its own sub-agent.
- `{{REPORT_THERMO}}` — the `/thermo-nuclear-code-quality-review` maintainability
  and abstraction-quality audit.
{{CODEX_SECTION}}

Read every one of those files. Treat every finding they contain as a
**candidate finding**, exactly like the ones your own lenses and your delegated
`pr-review-toolkit` agents produce. They enter step 6 with no privilege: verify
each against the codebase at `{{HEAD_SHA}}` with `git show {{HEAD_SHA}}:<path>`,
and discard on the skill's own criteria — intentional behaviour read as a
defect, exaggerated severity, a convention claim you cannot point to in a
retrieved file, anything without a `file:line` citation, anything whose
functional consequence you cannot state. None of these passes had access to the
Linear ticket, the Mintlify documentation, the conventions pack or the ADRs, so
they are the passes most likely to have called intentional behaviour a bug.
Drop when unsure.

A thermo-nuclear finding that is a pure restructuring proposal with no
functional consequence is `Preferential` at most, and only when you can state
what it costs the next reader. Ambition about code structure is the skill's
job, not the author's obligation.

Where a phase A finding and one of your own describe the same defect, emit one
finding, not two.

The target checkout stays read-only for this run, as the skill requires: the
scratch worktree already exists and is not yours to manage.

## Emit mode: {{POST_MODE}}

`post` — follow `references/emit.md` unchanged: one `event: "COMMENT"` review on
{{REPO}}#{{PR_NUMBER}}, findings routed inline or to the body by the precedence
rule, finding markers closing each one, run marker to stdout, then the terminal
report. No findings means no review.

`dry-run` — run every step including the skeptic gate, then **make no GitHub
write at all**. Instead emit, under a `WOULD SUBMIT` heading, the exact `gh api`
call and the exact JSON payload you would have posted: `body`, `event`, and the
full `comments` array with `path`, `line`, `side` and each comment's finished
text including its finding marker. Then the run marker and the terminal report.
State plainly in the terminal report that nothing was posted.

This runs headless: only your **final message** reaches the invoker's stdout,
and anything you write in an earlier turn is lost. So in `dry-run` the `WOULD
SUBMIT` block, the run marker and the terminal report must all be in that one
final message, in that order. A report that points at a payload the invoker
cannot see is worse than no dry-run — it reads as though the review was
inspectable when it never was.

The PR is {{PR_URL}}, base `{{BASE_REF}}`.
