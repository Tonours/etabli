---
name: implement
description: Implement an existing READY PLAN.md without replanning. Use only when explicitly asked via /skill:implement; not for planning, design, or unplanned fixes.
disable-model-invocation: true
---
<!-- GENERATED:adapter-sync:start -->
skill: implement
harness: pi
canonical: pi/skills/implement/SKILL.md
name: implement
description: Implement an existing READY PLAN.md without replanning. Use only when explicitly asked via /skill:implement; not for planning, design, or unplanned fixes.
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
- The READY plan must cover the requested task; if the request names another
  task, run plan-loop first (implementation-loop.md steps 1–2).
- After focused checks, run implementation-loop 12b on this diff and record
  `simplify: clean` or `simplify: removed N`. Then run 12c (`code-quality` when
  exposed, else the narrowest domain skill or 1-3 local siblings) and append
  `quality_completed` (`status: pass`, or `status: unavailable` and stop
  before completion if no pass exists).
