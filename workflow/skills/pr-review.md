# PR Review Contract

Shared contract for reviewing GitHub pull requests through `gh`.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the read-only default, human-in-the-loop posting rule, finding format,
verdict labels, deciding-code gate, or hunt/filter split.

## Purpose

Review a GitHub PR in three phases: understand, review, and optionally submit
after human validation. Use `gh`; do not use the GitHub MCP/app connector unless
the user explicitly overrides this.

## Repositories

Supported aliases:

- `frontend`: `ForestAdmin/forestadmin`
- `backend`: `ForestAdmin/forestadmin-server`
- `agent`: `ForestAdmin/agent-nodejs`
- `zendesk`: `ForestAdmin/forest-for-zendesk`

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

Parent pins `gh pr diff` once during Phase 1. Hunters receive that patch and
do not re-run `gh pr diff`. Then dispatch Logic hunter and Spec hunter per
`workflow/skills/review.md` (Pi child argv, Cursor Opus 5 high, isolation/GO).
Intent from the PR body; Spec uses PR intent and `PLAN.md` when present. If
the PR body is empty and there is no `PLAN.md`, Spec is `spec: n/a`.

### Domain practice

Load `code-quality` when exposed, otherwise the narrowest exposed domain or
project skill. If none is exposed, compare the diff directly with 1–3 local
sibling implementations. If neither a skill nor a relevant sibling exists,
report the convention lens as `not run`; never present it as clean (rubric §
Convention & pattern fit).

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
(mandatory on the Logic hunter). Every lens row needs a concrete opened
`file:line` or is `not run` (Convention may be `deferred: Standards hunter`).
One deciding-code row per runtime behavior touched.

`GO` is forbidden when any non-trivial runtime deciding-code row is empty or
`not run`, or when `isolation: none`. `GO WITH NOTES` is not a workaround for
those gates.

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
