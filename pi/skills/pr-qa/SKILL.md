---
name: pr-qa
description: Generate a QA impact analysis and executable test plan for a GitHub PR through the gh CLI. Use when the user asks how to test a PR, asks for PR QA, impact analysis, happy path, edge cases, or a manual QA plan.
---

# PR QA

Generate a test plan for a GitHub PR. Use `gh` for GitHub. Do not post comments
or edit the PR.

## Repositories

Supported aliases:

- `frontend`: `employer/employer`
- `backend`: `employer/employer-server`
- `agent`: `employer/agent-nodejs`
- `zendesk`: `employer/employer-for-zendesk`

Also accept `owner/repo#123`, a PR URL, or the current repository.

If only a PR number is provided and the repository cannot be inferred, ask one
blocking question.

## Data

Use:

```bash
gh auth status
gh pr view <PR_ID> --repo <OWNER/REPO> --json title,body,author,files,additions,deletions,baseRefName,headRefName,number,url,commits,labels,comments,reviews
gh pr diff <PR_ID> --repo <OWNER/REPO>
```

If `gh` is unavailable or unauthenticated, stop with `GITHUB_CLI_UNAVAILABLE` or
`GITHUB_AUTH_REQUIRED`.

## Phases

1. Understand:
   - title, body, author, branches
   - files changed and stats
   - functional change from a user perspective
   - type: fix, feature, refactor, performance, security, chore
2. Analyze impact:
   - direct functionality changed
   - indirect dependents
   - lateral workflows in the same domain
   - system impact: performance, auth, permissions, data, queues, API contracts
   - affected user roles
3. Generate test plan:
   - prerequisites
   - happy paths
   - edge cases
   - non-regression tests
   - estimated test time and risk level

## Edge Case Checklist

- Data: null, empty, large, malformed, special characters
- Concurrency: simultaneous users or repeated actions
- Permissions: missing rights, different roles, tenant boundaries
- State: already deleted, already processed, stale cache, lifecycle transitions
- Network: timeout, retry, offline, partial failure
- Limits: pagination, quotas, payload size, rate limits

## Output

```md
## QA Plan - PR #<ID>

### Summary
- Feature:
- Type:
- Risk:
- Estimated time:

### Prerequisites
- [ ]

### Happy Path
#### Scenario: <name>
Context:
Actions:
1.
Expected:

### Edge Cases
#### Edge Case: <name>
Condition:
Expected:

### Non-Regression
- [ ]
```

Rules:

- Every test must be executable without hidden context.
- Prioritize by risk: happy path first, then edge cases, then adjacent
  non-regression.
- Do not approve, comment, merge, edit, or checkout the PR.
