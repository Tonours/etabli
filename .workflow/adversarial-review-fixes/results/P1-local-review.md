# P1 local review result

## Findings

- Accepted/fixed: adversarial code-review prompts were too close to the PLAN.md adversary route. A prompt such as `fais une code-review complete puis une code-review adversary` must stay on the read-only review route, not `/adversary`.
- Accepted/fixed: read-only READY plan wording must not route into implementation, even when the prompt says `ready`.
- Accepted/fixed: TaskList completion evidence was too text-driven for implementation routes. It now requires declared evidence plus filesystem evidence for a fresh `docs/plan/*.md` archive and deleted root `PLAN.md`.
- Accepted/fixed: workflow docs had stale wording around PLAN statuses and cleanup evidence.

## Files Reviewed

- `pi/extensions/lib/workflow-router-runtime.ts`
- `pi/extensions/workflow-router.ts`
- `claude/hooks/workflow-router-lib.mjs`
- `pi/extensions/lib/tasks-till-done-runtime.ts`
- `pi/extensions/tasks-till-done.ts`
- `scripts/check-fix-symlinks.sh`
- `tests/*workflow*smoke.sh`
- `docs/workflow-101.md`
- `docs/workflow-duplication-audit.md`

## Validation

- Focused runtime/extension tests passed.
- Focused autonomous plan-loop smoke passed.
- Symlink repair smoke passed.
- `git diff --check` passed.
