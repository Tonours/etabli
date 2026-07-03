# Final Report: Adversarial review fixes

## Outcome

Completed. The working-tree diff received a local code review, an independent complete review, and an independent adversarial review. Every confirmed actionable finding was fixed and covered by focused tests or smoke checks.

## Accepted Results

- Router safety: adversarial code review no longer routes to PLAN.md adversary.
- Router safety: read-only READY plan prompts stay read-only.
- Router safety: read-only adversarial PLAN.md review stays read-only review.
- READY gate: direct implementation requires actual root `PLAN.md` READY evidence, not prompt wording.
- Task loop: implementation completion requires declared task evidence plus runtime filesystem evidence.
- Task loop: stale `docs/plan` archives are rejected for current completion evidence.
- Symlink repair: `adversary` is included in Pi and Codex-visible skill repair.
- Docs: stale workflow status and verification wording was corrected.

## Rejected Results

None.

## Conflicts Resolved

- Review/adversary ambiguity was resolved by reserving `/adversary` for PLAN.md/plan-hardening context.
- Prompt wording versus file evidence was resolved by treating actual root `PLAN.md` status as authoritative.
- Text TaskList evidence versus runtime state was resolved by requiring filesystem evidence for archive/delete completion.

## Verification Evidence

- `bun test pi/extensions/__tests__/` passed with 165 tests.
- `bash tests/workflow-autonomous-plan-loop-smoke.sh` passed.
- `bash tests/workflow-docs-smoke.sh` passed.
- `bash tests/workflow-scaffold-smoke.sh` passed.
- `bash tests/claude-hooks-smoke.sh` passed.
- `bash tests/codex-organization-smoke.sh` passed.
- `bash tests/fix-links-smoke.sh` passed.
- `bash tests/install-smoke.sh` passed.
- `node --check claude/hooks/workflow-router-lib.mjs` passed.
- `node --check claude/hooks/workflow-router.mjs` passed.
- `node --check claude/hooks/plan-ready-guard.mjs` passed.
- `git diff --check` passed.
- `.workflow/adversarial-review-fixes` verification passed.
- `.workflow/pi-orchestrator-subagents-industrialization` verification passed.
- `.workflow/pi-task-subagent-e2e` verification passed.
- `RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh` passed with real Pi `0.80.2` and Claude Code `2.1.196` invocations on temporary workflow projects, including Pi `TaskExecute` subagent archive/delete e2e.

## Remaining Risks

- Live Pi and Claude workflow routing is covered by real CLI scenarios. Pi Task* plus subagent execution plus archive/delete completion is now covered by the same real scenario suite.
- Broad working-tree changes predated this review. They were preserved rather than rewritten.

## Reusable Follow-up

- Keep `RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh` as the regression check before changing Task* or subagent packages.
