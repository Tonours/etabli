---
description: Generate a QA impact analysis and test plan for a GitHub PR
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# PR QA

User request: $ARGUMENTS

Use `gh` for GitHub. Generate a read-only QA plan; do not comment, approve,
edit, checkout, or merge.

Supported aliases: `frontend`, `backend`, `agent`, `zendesk`. Also accept
`owner/repo#123`, a PR URL, or current repository context.

If only a PR number is provided and repo cannot be inferred, ask one blocking
question.

Use:

```bash
gh auth status
gh pr view <PR_ID> --repo <OWNER/REPO> --json title,body,author,files,additions,deletions,baseRefName,headRefName,number,url,commits,labels,comments,reviews
gh pr diff <PR_ID> --repo <OWNER/REPO>
```

Return:

```md
## QA Plan - PR #<ID>

### Summary
- Feature:
- Type:
- Risk:
- Estimated time:

### Prerequisites

### Happy Path

### Edge Cases

### Non-Regression
```

Every test must be executable and have a measurable expected result.
