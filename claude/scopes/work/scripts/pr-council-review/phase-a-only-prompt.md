The validator already reviewed {{REPO}}#{{PR_NUMBER}} at `{{HEAD_SHA}}`, so it does not run again. Phase A is the review: verify its findings, then publish at most one review. Read-only on the checkout.

Phase A ran against `{{HEAD_SHA}}` over `{{MERGE_BASE}}...{{HEAD_SHA}}` in a scratch worktree:

- `{{REPORT_QUALITY}}` — the `/code-review` skill's three axes.
- `{{REPORT_THERMO}}` — the `/thermo-nuclear-code-quality-review` audit.
{{CODEX_SECTION}}
{{PHASE_A_GAPS}}

{{LINKED_SECTION}}

Read every file. Each finding is a candidate with no privilege. Verify it against the code with `git show {{HEAD_SHA}}:<path>` and keep it only if it has a `file:line`, a stated functional consequence, and you can reproduce or argue it from the code. Drop intentional behaviour read as a defect, exaggerated severity, convention claims you cannot point to, and pure restructuring proposals with no functional cost. Drop when unsure. Merge duplicates.

Also read the validator's review on this head (`gh api repos/{{REPO}}/pulls/{{PR_NUMBER}}/reviews`, then `.../reviews/<review_id>/comments`) and drop any finding it already made. One exception, only when a Linked pull requests section follows: a finding the validator posted without naming the linked PR that already makes its fix is kept once, its text limited to that PR and the merge order.

## Emit mode: {{POST_MODE}}

Write in English, short, one finding per inline comment, no model or vendor names (say "an independent pass" if you must), no AI attribution. Never submit `APPROVE` or `REQUEST_CHANGES`: approval belongs to the invoker.

- Findings kept, `post`: one review on {{REPO}}#{{PR_NUMBER}} with `event: "COMMENT"`, `commit_id: "{{HEAD_SHA}}"`, findings on lines the diff changed inline (`path`, `line`, `side: "RIGHT"`), every other finding in the body as `` `path:line`: text ``, after a one-line summary. Submit with `gh api repos/{{REPO}}/pulls/{{PR_NUMBER}}/reviews --input <file>` (write the payload to a temp file).
- No finding kept: no review.
- `dry-run`: no GitHub write. Print under `WOULD SUBMIT` the exact `gh api` call and JSON payload (`event`, `commit_id`, `body`, `comments`), or `WOULD SUBMIT: nothing` when no finding survives.

Only your final message reaches the invoker. It holds, in this order: the `WOULD SUBMIT` block in `dry-run`; this run marker on its own line, with `<kept>` the number of findings kept, whether or not the submission succeeded, and `<dropped>` the number of candidates dropped:

<!-- claudine:v1 {"kind":"run","run":"phase-a-only","sha":"{{HEAD_SHA}}","findings":<kept>,"floor":"should-fix","suppressed":<dropped>,"security":"clean","lenses":{"phase-a":"verified"}} -->

then a short report in French listing what each phase A pass found, how many candidates survived, what was posted (or would be), the review URL, and any submission error.
