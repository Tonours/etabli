---
description: Session or day recap from git/gh evidence - standup or team-message format
argument-hint: "[standup | slack | <free period, e.g. today or this week>]"
allowed-tools: [Read, Glob, Grep, Bash, Skill]
---

# Recap

User request: $ARGUMENTS

Produce a recap grounded in evidence, not in conversation memory.

## Steps

1. Collect the period's evidence (default: today):
   - `git log` on the current repo (and obvious sibling worktrees when the
     session touched them);
   - `gh pr list --author @me` and `gh pr status` for opened/updated/merged PRs;
   - CI state of the PRs touched.
2. Write the recap in the user's direct tone — use the `write-direct` skill
   contract when available: French, tutoiement, concrete, zero filler.
3. Format by argument:
   - `standup`: 3 bullets max — done / in progress / blocked;
   - `slack`: short team message, ready to paste, links included;
   - default: standup.

## Rules

- Every claim maps to a commit, PR, or command output collected in step 1.
- No self-congratulation, no adjectives, no AI attribution.
- Unverified or in-flight work is labeled as such.
