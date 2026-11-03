---
status: accepted
date: 2026-11-03
tags: [workflow, github, hooks, skills]
affected_components: [skills/shared/pr/SKILL.md, workflow/pr-body-contract.md, workflow/runtime/pr-body-guard.mjs, claude/hooks/pr-body-guard.mjs, claude/settings.workflow-hooks.json, pi/extensions/pr-body.ts, workflow/agent-rules.md]
---

# Open every PR through the `pr` skill and a body guard

The PR body contract was text only. Of the owner's last 60 PRs (2026-11-03), 44 had `## What`, `## Why` and `## How to test`; 16 did not: fleet worker PRs with `## What changed` and `## Validation`, empty bodies, `## Summary`. The owner wants every PR to open in our template, in the direct voice.

The `pr` skill (shared, both runtimes) is the procedure: read the diff, draft the body in a file, check it, open with `gh pr create --body-file`. It adapts Matt Pocock's `pr` skill: our What, Why, How to test shape replaces its Summary, Evidence and Merge Danger template; its visuals menu (from Dex Horthy's `show-me`) feeds `## What`, its before/after evidence becomes a How to test rule, and Merge Danger becomes one Why bullet for merges that cannot be walked back. Credits in `skills/shared/pr/CREDITS.md`.

A guard makes the checkable rules hold without relying on the model reading the skill: a Claude `PreToolUse` hook on `Bash` and a Pi `tool_call` extension share `workflow/runtime/pr-body-guard.mjs`. It denies a `gh pr create` without a body, and a create or edit body that misses our three headings or the repo template's headings, carries AI attribution, or has non-ASCII prose. A repo template that already asks what changed and how it was verified stands in for our headings, so a foreign template stays law. This adds a fourth Claude hook to the three ADR-0035 kept.

## Consequences

- `gh api` POSTs to `/pulls` and PRs opened by scripts outside a tool call are not seen.
- A body passed as `--body "$(cat file)"` is invisible to the guard and refused; `--body-file` is the supported path.
- The guard fails open on a crash: it protects a convention, not a boundary.
- Review date: 2027-02-03. Recount the owner's PRs opened after this ADR, with the query of the 44-of-60 count: the guard stays if every one carries the three headings or a covering repo template, and is fixed or deleted otherwise.
