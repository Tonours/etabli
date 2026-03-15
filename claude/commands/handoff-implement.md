---
description: Write or refresh a plan-aware implementation continuation handoff
argument-hint: [output path]
allowed-tools: [Read, Write, Glob, Grep, Bash, AskUserQuestion]
---

# Handoff Implement

Default output path: `./.pi/handoff-implement.md`
Template source of truth: `~/.claude/handoff-template.md`

## Your task

1. Inspect the current repository state and the active work context.
2. Read `~/.claude/handoff-template.md`.
3. Read `./PLAN.md`.
4. If `PLAN.md` is missing, stop and ask the user to create/review a plan first.
5. If `PLAN.md` is not `READY`, stop and ask the user to re-establish `READY` before writing an implementation continuation handoff.
6. Read the smallest set of relevant files needed to summarize the current implementation state.
7. Write or refresh the handoff document at:
   - first argument if provided
   - otherwise `./.pi/handoff-implement.md`
8. Keep it concise and continuation-focused.
9. Focus on:
   - the next bounded implementation steps from the current plan
   - validation already run / still needed
   - blockers, risks, and exact files/commands needed to resume
10. Do not implement new code while preparing the handoff.

If critical context is missing, ask only the narrowest blocking question.
