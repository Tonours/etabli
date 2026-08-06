---
description: Implement the existing READY PLAN.md without rerunning planning
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent]
---

# Implement

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/implementation-loop.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/plan-archive.md`
   - `workflow/skills/implementation-loop.md`
   - `workflow/skills/adversary.md`
2. If one of those files is missing in the current workspace, fall back to the Claude shared copies when this command is loaded through `~/.claude/commands`:
   - `../workflow/spec.md`
   - `../workflow/plan-archive.md`
   - `../workflow/skills/implementation-loop.md`
   - `../workflow/skills/adversary.md`
3. If those are unavailable, fall back to the Etabli repo copies when this command is loaded from the repo target path:
   - `../../workflow/spec.md`
   - `../../workflow/plan-archive.md`
   - `../../workflow/skills/implementation-loop.md`
   - `../../workflow/skills/adversary.md`
4. If any fallback files exist, read them and continue. Do not tell the user the workflow spec is missing.
5. If archive instructions are missing after all lookups, still implement only from `READY`; skip archiving with a warning instead of inventing an archive format.

Read the existing root `PLAN.md`, then follow
`workflow/skills/implementation-loop.md`.

Rules:

- Do not rerun full planning.
- Do not create `REVIEW.md`.
