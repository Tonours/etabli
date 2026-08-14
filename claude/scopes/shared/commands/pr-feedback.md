---
description: Fetch, triage, and resolve review feedback on your own PR (bots and humans)
argument-hint: [PR number or URL — defaults to the current branch's PR]
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion]
---

# PR Feedback

User request: $ARGUMENTS

Handle review feedback on the user's own PR. Use `gh`, not the GitHub MCP,
unless explicitly overridden.

## Target Resolution

1. Resolve the PR: explicit argument, else `gh pr view --json number,url,headRefName`
   for the current branch. Stop with `NO_PR_FOUND` if neither resolves.
2. Fetch unresolved review threads through the GraphQL API
   (`reviewThreads` with `isResolved: false`), plus standalone PR comments and
   pending change requests.
3. Separate bot feedback (macroscope, coderabbit, copilot, dependabot) from
   human feedback. Human feedback is triaged first.

## Triage

For each unresolved item classify:

- `apply`: valid, fix it;
- `contest`: wrong or not worth it — draft a factual reply, no fix;
- `out-of-scope`: valid but unrelated to this PR — draft a reply saying so.

Present the triage as one compact table (author, file:line, summary, verdict)
and wait for user confirmation before writing anything. The user can override
any verdict.

## Escaped defects

When a **bot or human** finding is accepted (`apply`) and an internal review had
already returned `GO` / `GO WITH NOTES` on the same commit (or an ancestor that
contained the defect), treat it as an escaped defect:

1. Fill `workflow/templates/escaped-defect.md` (one record per defect).
2. Append or update the PR row in `workflow/self-improvement/review-metrics.md`
   (`escaped_later`, `buckets`).
3. Storage: personal → obvault; work → brain; reusable → also
   `workflow/self-improvement/reviewer-eval-corpus.md`.

Do this before or with the fix. Skipping the record closes the miss without
learning from it.

## Apply

1. Group accepted fixes by concern; one atomic conventional commit per group.
2. Never touch code outside the commented scope.
3. Reply to every thread in English — short, factual, referencing the fix
   commit when one exists — then resolve it through GraphQL
   (`resolveReviewThread`). Contested threads get the reply, stay unresolved
   for the author, and are listed in the final report.
4. Push to the PR branch. Never force-push. No AI attribution anywhere.
5. Re-check CI once pushed; if a bot re-posts on the new commits, loop once.

## Stop Condition

Every thread is fixed-and-resolved or answered, CI is green or its failure is
diagnosed and reported. End with:

```text
Feedback: <n> applied, <n> contested, <n> out-of-scope | escaped recorded: <n> | CI: <state>
```
