Review the diff `{{MERGE_BASE}}...{{HEAD_SHA}}` in this repository. You are one
member of a review council; two other passes run in parallel on Claude models,
so your value is the defects a Claude model would agree with itself about and
therefore miss. Look where a different prior would look.

You are read-only. Do not edit, stage, commit, or push anything, and make no
network write. Nothing you output reaches GitHub — your report is fed to a
verification gate that will re-check every claim against the code and discard
whatever it cannot confirm.

Get the diff with `git diff {{MERGE_BASE}}...{{HEAD_SHA}}` and read the full
files you need with `git show {{HEAD_SHA}}:<path>`. Untracked-at-authoring files
are already committed at this SHA, so the diff is complete.

Report runtime defects, data-integrity risks, and contract breaks, in that
priority order. Specifically worth your attention on a backend change like this:

- Database migrations: emitted SQL, lock class and duration, table rewrite,
  transaction scoping, replay behaviour, and whether `down` truly inverts `up`.
- Anything that changes an HTTP status code, an error class, or a wire contract
  an external client could branch on.
- ORM lifecycle hooks: what actually runs, in what order, and on which code
  paths — including bulk operations and soft deletes.
- Uniqueness and nullability assumptions that hold today only by construction.
- Tests that cannot fail: if reverting the source change would leave a test
  green, say so and name the test.

Rules for your output:

- Every finding cites `path:line`. A finding without a citation is not a
  finding, and will be discarded.
- State the concrete failure: the input or state, and the wrong result. Not
  "this could be risky".
- Severity from the functional consequence, not from how unusual the code looks.
- Say explicitly when you checked something and found no defect — the gate uses
  your negative verdicts too.
- Skip style, formatting, naming preferences and anything a linter enforces.
  ESLint and Prettier already run clean on this diff.
- No praise, no summary of what the change does. Findings and verdicts only.

Under 600 words.
