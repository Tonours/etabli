---
name: pr
description: Writes and opens a pull request in the What, Why, How to test body contract, in the owner's direct voice. Use when opening a PR or rewriting its description; not for PR review (review, pr-council-review).
---

# pr: open a pull request

The contract is `workflow/pr-body-contract.md` (repo copy, else
`~/.claude/workflow/` or `~/.pi/agent/workflow/`). It wins on conflict; this
skill is the procedure. The `pr-body` guard refuses a `gh pr create` or
`gh pr edit` body that misses the headings, carries AI attribution, has
non-ASCII prose, or names a non-Claude model in a work-org repo; it refuses a
`git commit` message on the same attribution and model-name rules.

## 1. Read the change

- Base: the default branch, or the parent branch of a stacked PR.
- `git log --oneline <base>..HEAD` and `git diff <base>...HEAD`. Write from
  the diff, not from the conversation.
- Ticket: `fixes PRD-123` on its own line when the branch or commits name one.
- Repo template: `pull_request_template.md` under `.github/`, the root or
  `docs/`, any case. Keep every section and checklist, leave checklists
  unchecked, put ours inside its free-form description section. When the
  template already asks what changed and how it was verified, fill its
  sections instead of adding ours.

## 2. Draft the body in a file

```markdown
<one line: the change, not the problem>

fixes PRD-123

## What
<smallest view that shows the change>

## Why
- <the need>
- <a choice a reviewer would question>

## How to test
- `<command you ran>`: <result>
```

- **What**: a table of touched files and the rules that changed, or a sketch
  when the shape is the point. Pick from `visuals.md`; one view is usually
  enough.
- **Why**: the need, then only the choices a reviewer would challenge. A merge
  that cannot be walked back gets one bullet: what is irreversible and how far
  it reaches.
- **How to test**: the commands that actually ran, with their result. A fix
  shows the test or output that failed before and passes after.
- Stacked PR: the first lines name the parent PR, the base branch, and that
  the parent merges first.

## 3. Voice

English, in the `write-direct` voice transposed: lead with the change, short
sentences with one idea each, concrete nouns, decisions owned ("we keep X"),
honest status ("draft, the route is not wired yet"). No preamble, no recap, no
defending a choice across a paragraph. Use the repo's domain terms
(`GLOSSARY.md`, `CONTEXT.md`) when it has them. Routes, payloads, commands and
security warnings stay literal.

## 4. Check, then open

- Under 40 lines outside the repo template; cut whole sections first.
- No `—`, `→`, curly quotes or `…` outside code, tables and quotes.
- Every command under How to test ran in this session or the run it reports.
- Title: conventional, lowercase imperative, like the commit subject
  (`workflow/git-contract.md`).
- Open: `gh pr create --title "<title>" --body-file <file>` (`--draft`,
  `--base <parent>` when stacked). Rewrite: `gh pr edit <N> --body-file <file>`.
- After publishing, run the contract's check:
  `gh pr view <N> --json body -q .body | LC_ALL=C grep -n '[^[:print:][:space:]]'`
  (empty means clean).

Before each later push, re-read the body against the final diff and fix every
stale claim (contract § Honest status).

Adapted from Matt Pocock's `pr` skill and Dex Horthy's `show-me`: `CREDITS.md`.
