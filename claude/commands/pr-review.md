---
description: Review a GitHub PR through gh CLI with human-in-the-loop posting
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# PR Review

User request: $ARGUMENTS

Use `gh` for GitHub. Do not use the GitHub MCP/app connector unless the user
explicitly overrides this.

Supported aliases: `frontend`, `backend`, `agent`, `zendesk`. Also accept
`owner/repo#123`, a PR URL, or current repository context.

If only a PR number is provided and repo cannot be inferred, ask one blocking
question.

Read:

```bash
gh auth status
gh pr view <PR_ID> --repo <OWNER/REPO> --json title,body,author,files,additions,deletions,baseRefName,headRefName,number,url,commits,reviewDecision,mergeStateStatus
gh pr diff <PR_ID> --repo <OWNER/REPO> --patch
gh pr checks <PR_ID> --repo <OWNER/REPO>
```

Review correctness, regressions, edge cases, performance, security/privacy,
tests, validation, and repo architecture fit.

Finding format:

```text
severity: high | medium | low
file:
line: or line_range:
issue:
impact:
review_comment:
suggested_fix:
```

If no actionable issue exists, output exactly `No findings.` as the only
finding. End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.

Default is read-only. Post comments or approve only after explicit user
approval. Inline comments must be one sentence, collegial, actionable, and
without emojis.
