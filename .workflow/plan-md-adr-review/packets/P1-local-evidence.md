# P1 Local Evidence Review

## Objective
Verify `PLAN.md` claims against local repo files.

## Files / Sources
- `PLAN.md`
- `claude/README.md`
- `claude/settings.workflow-hooks.json`
- `claude/hooks/*.mjs`
- `claude/skills/*/SKILL.md`
- `scripts/install.sh`
- `scripts/check-fix-symlinks.sh`

## Do
- Confirm deployment, hook, and skill claims.
- Identify local contradictions and missing tests.

## Do Not
- Modify `PLAN.md` or implementation files.

## Expected Output
- `.workflow/plan-md-adr-review/results/P1-local-evidence.md`

## Verification
- File/line-backed local observations only.
