Incremental review of {{REPO}}#{{PR_NUMBER}} ({{PR_URL}}).

The pull request was already reviewed in full at `{{SINCE_SHA}}`. This pass covers
only what the author pushed since: the commits `{{SINCE_SHA}}..{{HEAD_SHA}}`. They
are staged in this worktree (`git diff --cached`); the working tree is the PR head.

1. Run the `/code-review {{REVIEW_LEVEL}}` skill on that staged diff. Report only
   defects introduced or left by these commits, each with a `file:line` on the head.
   Do not re-review code outside the staged diff.
2. Post the findings you kept as **one** review on the pull request, never more:

   ```
   gh api repos/{{REPO}}/pulls/{{PR_NUMBER}}/reviews --input <payload.json>
   ```

   with `event: "COMMENT"`, `commit_id: "{{HEAD_SHA}}"`, a one-line `body`
   (`Incremental review of {{SINCE_SHORT}}..{{HEAD_SHORT}}: <n> findings.`) and a
   `comments` array of `{path, line, side: "RIGHT", body}`, one per finding, each
   on a line the staged diff adds or changes. A finding that cannot be anchored to
   such a line goes in `body` instead. Never approve, never request changes.
3. No finding: post nothing.

This runs headless: only your final message reaches the invoker. End with one line
per posted finding (`path:line — summary`) and the review URL, or `no findings,
nothing posted`. Then judge, as this pull request's reviewer, whether these commits
leave it in a state you would approve: confident only if the delta adds no risk you can
name and nothing in it makes you hesitate to merge. Any doubt means not confident.

End with exactly these two lines, nothing after them:
DELTA_FINDINGS <n posted>
DELTA_CONFIDENT value=<true|false>
