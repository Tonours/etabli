# 2026-07-04 — AI OS recurring-work commands and PLAN commit guard

## What

Closed the two biggest unformalized gaps found by the 2026-07-04 usage audit
(11 322 prompts, ~25 session transcripts): six manual-only Claude commands and
one guard hook.

- `claude/commands/pr-feedback.md` — fetch/triage/resolve review feedback on
  own PRs (bots + humans), HITL triage table, atomic fix commits, GraphQL
  thread resolution.
- `claude/commands/pre-commit.md` — final pass before commit: rubric review,
  sweep (dead code, comments, console.log, hardcoded values), PLAN staging
  check, targeted tests, commit message proposal.
- `claude/commands/tests-iso.md` — tests indistinguishable from neighbors;
  conventions extracted from 2-3 sibling test files before writing.
- `claude/commands/front-quality.md` — review → vercel-react-best-practices →
  `npx react-doctor@latest` chain.
- `claude/commands/ui-debug.md` — repro-first UI debugging; one hypothesis =
  one measurement; hard stop after two failed fixes.
- `claude/commands/recap.md` — evidence-based standup/Slack recap via git/gh.
- `claude/hooks/plan-commit-guard.mjs` — PreToolUse Bash deny when a
  `git add`/`git commit` names or has staged a root `PLAN*.md`; wired into
  `claude/settings.workflow-hooks.json` and the user's live settings.

## Decisions

- Manual-only commands, no router-lib changes: smallest diff; ambient routing
  can be added later if usage shows the need.
- No `workflow/skills/` contracts: single-harness (Claude) behavior per the
  spec.md rule "add a shared contract only when two harnesses must preserve
  the same behavior".
- Guard hook self-contained (not in `workflow-router-lib.mjs`): orthogonal
  concern. Gotcha fixed during validation: an
  `argv[1] === import.meta.url.pathname` main-module check fails through
  `~/.claude` symlinks because Node realpaths ESM entries — the hook now runs
  its main block unconditionally, like `plan-ready-guard.mjs`.
- Known ceiling: `git add -A && git commit` in one call with an untracked,
  non-ignored PLAN.md escapes the staged check; the deny message documents the
  manual-git bypass as the deliberate escape hatch.

## Validation

- `bash tests/claude-hooks-smoke.sh` → ok (includes five new plan-commit-guard
  cases: staged deny, named-file deny, clean commit pass, docs/plan archive
  pass, non-git pass).
- `bash tests/workflow-docs-smoke.sh` → ok.
- `bash tests/workflow-contract-coverage-smoke.sh` → ok.
- Live check: the activated guard denied the session's own test command that
  contained `git add PLAN.md`, proving in-session enforcement.

## Follow-ups (not in this change)

- Merge the three Playwright/qa surfaces into one source.
- Arbitrate the review/commit command duplicates (etabli vs caveman plugin).
- Purge the Postgres connection string from `~/.claude/history.jsonl` and the
  pasted JWTs from two transcripts (hygiene, outside this repo).
