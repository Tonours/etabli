---
description: Implement the existing READY PLAN.md without rerunning planning. Use only when explicitly invoked; not for planning or unplanned fixes.
disable-model-invocation: true
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent]
---
<!-- GENERATED:adapter-sync:start -->
skill: implement
harness: claude
canonical: pi/skills/implement/SKILL.md
description: Implement the existing READY PLAN.md without rerunning planning. Use only when explicitly invoked; not for planning or unplanned fixes.
pointer: Adapter for the `implement` skill. Read and follow the shared contract in `pi/skills/implement/SKILL.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Implement

Follow the shared contract in `workflow/skills/implementation-loop.md`. The
routing map `workflow/spec.md` wins on conflict; open it only when the route or
a gate is in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:

- Do not rerun full planning.
- Do not create `REVIEW.md`.
- After focused checks, run implementation-loop 12b on this diff and record
  `simplify: clean` or `simplify: removed N`. Then run 12c (`code-quality` when
  exposed, else the narrowest domain skill or 1-3 local siblings). Record
  `quality: unavailable` and stop before completion if neither exists.
