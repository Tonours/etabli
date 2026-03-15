---
description: Write or refresh .pi/handoff.md for session continuation
argument-hint: [output path]
allowed-tools: [Read, Write, Glob, Grep, Bash, AskUserQuestion]
---

# Handoff

Default output path: `./.pi/handoff.md`
Template source of truth: `~/.claude/handoff-template.md`

If you are pausing active implementation from an existing `READY` `PLAN.md`, use `/handoff-implement` instead.

## Your task

1. Inspect the current repository state and the active work context.
2. Read `~/.claude/handoff-template.md`.
3. Read the smallest set of relevant files needed to summarize the current work.
4. Write or refresh the handoff document at:
   - first argument if provided
   - otherwise `./.pi/handoff.md`
5. Keep it concise and continuation-focused.
6. Include exact file paths, commands, and artifacts needed to continue.
7. Do not implement new code while preparing the handoff.

If critical context is missing, ask only the narrowest blocking question.
