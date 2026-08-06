---
description: Front-end quality chain - diff review, React best practices, react-doctor
argument-hint: [path or package to check — defaults to the current diff's packages]
allowed-tools: [Read, Glob, Grep, Bash, Edit, Skill]
---

# Front Quality

User request: $ARGUMENTS

Run the three-pass front-end quality chain the user otherwise types manually.

## Passes

1. **Review** — review the current diff with `workflow/review-rubric.md` when
   available, focused on React/frontend correctness (hooks rules, state
   ownership, render loops, effect dependencies).
2. **Best practices** — apply the `vercel-react-best-practices` skill to the
   changed files when the skill is available; otherwise check the diff against
   React performance basics (memoization only where measured, stable deps,
   no derived-state duplication).
3. **Doctor** — run `npx react-doctor@latest` on the target package; triage its
   output against the diff.

## Rules

- Fix mechanical findings directly; report behavioral ones.
- Only the requested path/packages; do not audit the whole repo.
- Re-run the failing pass after fixes until no blocking finding remains or a
  finding needs a user decision.

End with one line per pass: `review | best-practices | doctor: <clean | n findings>`.
