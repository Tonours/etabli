# P4 fix integration result

## Accepted And Fixed

- Adversarial code review stays read-only review, not PLAN.md adversary.
- Read-only READY plan prompts stay answer/read-only.
- Read-only adversarial PLAN.md review stays read-only review.
- READY plan implementation now requires actual root `PLAN.md` status evidence before direct `implement`.
- Implementation route metadata now requires adversary evidence, validation, review evidence, `docs/plan` archive, root `PLAN.md` deletion, and final handoff.
- Task loop completion evidence now requires adversary, validation, review, archive, cleanup task evidence plus runtime filesystem evidence.
- Runtime filesystem evidence now rejects stale implemented-plan archives by comparing archive mtime with the current task-loop start.
- Symlink repair now includes `pi/skills/adversary` for both Pi and Codex-visible skill surfaces.
- Workflow docs were corrected where stale statuses or stale verification claims could mislead future work.

## Rejected

- None.

## Blocked

- None for repo-local behavior. Live Pi/Claude runtime claims outside this shell remain external validation, not blockers for these code fixes.

## Regression Tests Added Or Updated

- Router runtime, extension, golden fixtures, and Pi/Claude alignment tests.
- Claude hooks smoke fixtures for READY read-only, adversarial code review, adversarial PLAN.md review, and read-only adversarial PLAN.md review.
- Task loop runtime and extension tests for structured TaskList details, completion evidence, weak evidence, stale archives, and TaskExecute blocked capability.
- Autonomous plan-loop smoke.
- Symlink repair smoke assertions for `adversary`.
