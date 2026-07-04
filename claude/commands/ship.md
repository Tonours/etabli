---
description: Deliver one task A to Z - plan, implement, review, commit, push, PR, CI green
argument-hint: [task description]
allowed-tools: [Read, Glob, Grep, Bash, Edit, MultiEdit, Write, AskUserQuestion, Task]
---

# Ship

User request: $ARGUMENTS

Follow the shared contract in `workflow/skills/ship.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/skills/ship.md`
   - `workflow/skills/implementation-loop.md`
   - `workflow/skills/ci-fix.md`
   - `workflow/spec.md`
2. If missing, fall back to the Claude shared copies when this command is loaded through `~/.claude/commands`:
   - `../workflow/skills/ship.md`
   - `../workflow/skills/implementation-loop.md`
   - `../workflow/skills/ci-fix.md`
   - `../workflow/spec.md`
3. If those are unavailable, fall back to the Etabli repo copies when this command is loaded from the repo target path:
   - `../../workflow/skills/ship.md`
   - `../../workflow/skills/implementation-loop.md`
   - `../../workflow/skills/ci-fix.md`
   - `../../workflow/spec.md`
4. If any fallback files exist, read them and continue. Do not tell the user the contract is missing.

Claude specifics:

- The autonomous chain phases are described in `/plan-implement`; reuse them
  verbatim, including the non-interactive Codex adversary pass and the
  fresh-context reviewer subagent.
- Use `gh` for push status, PR creation, and CI checks.
- Explicit invocation of `/ship` is consent for the feature-branch push and PR
  creation only; every other human-checkpoint category still stops the run.
