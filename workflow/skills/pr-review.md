# PR Review Contract

Shared contract for reviewing GitHub pull requests through `gh`.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the read-only default, human-in-the-loop posting rule, finding format,
verdict labels, deciding-code gate, or two-pass order.

## Purpose

Review a GitHub PR in three phases: understand, review, and optionally submit
after human validation. Use `gh`; do not use the GitHub MCP/app connector unless
the user explicitly overrides this.

## Repositories

Supported aliases:

- `frontend`: `employer/employer`
- `backend`: `employer/employer-server`
- `agent`: `employer/agent-nodejs`
- `zendesk`: `employer/employer-for-zendesk`

Also accept `owner/repo#123`, a PR URL, or the current repository.

If only a PR number is provided and the repository cannot be inferred, ask one
blocking question.

## Phase 1: Understand

Use:

```bash
gh auth status
gh pr view <PR_ID> --repo <OWNER/REPO> --json title,body,author,files,additions,deletions,baseRefName,headRefName,number,url,commits,reviewDecision,mergeStateStatus
gh pr diff <PR_ID> --repo <OWNER/REPO> --patch
gh pr checks <PR_ID> --repo <OWNER/REPO>
```

If `gh` is unavailable or unauthenticated, stop with
`GITHUB_CLI_UNAVAILABLE` or `GITHUB_AUTH_REQUIRED`.

Present title, intent, author, branches, changed files, and perceived scope.

## Phase 2: Review

Use `workflow/review-rubric.md` when available. Same gates as
`workflow/skills/review.md` — the PR surface must not be weaker than local
review.

### Two passes

1. **Break-first** — do not treat the PR body or any plan as the authority for
   correctness. Hunt what breaks. Fill the lens table and deciding-code table.
2. **Plan-fit / intent-fit** — only after pass 1. Compare to PR intent (and
   `PLAN.md` if present on the branch). Scope, checks, drift against pass-1
   findings. No free second bug-hunt.

### Domain practice

Load `suite-router` / `code-quality` when the diff touches language, framework,
or UI surface so convention findings are anchored in project patterns (rubric
§ Convention & pattern fit).

### What to cover

- intent fit;
- correctness;
- regressions;
- edge cases;
- performance;
- security/privacy;
- tests and validation;
- architecture/pattern fit against sibling implementations.

Repository-specific checks:

- frontend: components must not own business logic or mutate global state;
  controllers only for query params; feature services delegate persistence.
- backend: no HTTP errors in business layer; dependency injection must be
  explicit; migrations pass transaction where relevant; prefer integration
  coverage for behavior.
- agent: avoid duplication, oversized functions, magic values, silent catches,
  and unclear boundaries.
- zendesk: strict TypeScript, no `any`, prefer Zendesk Garden components, no
  production `console.log`, sanitize HTML, no frontend API keys.

### Finding format

Report only actionable findings grounded in the diff. Each finding:

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
finding.

Then the **lens table** and **deciding-code table** from the rubric
(mandatory). Every lens row needs a concrete opened `file:line` or is
`not run`. One deciding-code row per runtime behavior touched.

`GO` is forbidden when any non-trivial runtime deciding-code row is empty or
`not run`. `GO WITH NOTES` is not a workaround for that gate.

End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.

## Phase 3: Submit

Default is read-only. Post comments or approve only when the user explicitly
asks to submit/post/approve.

Before posting each inline comment, present:

- file and line;
- code context;
- exact comment text.

Ask for confirmation or edits. Post only validated comments.

Use:

```bash
COMMIT_SHA="$(gh pr view <PR_ID> --repo <OWNER/REPO> --json commits --jq '.commits[-1].oid')"
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  -f body="<comment>" \
  -f commit_id="$COMMIT_SHA" \
  -f path="<file>" \
  -f line=<line> \
  -f side="RIGHT"
```

Use `gh pr review --approve` only after explicit approval and no blocking
findings.

## Comment Style

- One sentence max.
- Collegial: `We could...` or `What about...`.
- Actionable.
- No emojis.
- Positive comments should be very short.

## Rules

- Do not checkout, edit, commit, push, or merge.
- Do not post to GitHub without explicit user approval.
- Do not approve when tests are unverified unless that risk is explicit.
- Convention findings need a sibling pattern `file:line` or a named skill rule.
