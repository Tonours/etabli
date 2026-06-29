# ADR golden fixtures and dry-run final report

## Outcome
Complete.

## Changed
- Validator output is now covered by golden fixtures with exact expected
  statuses and streams.
- `apply-adr.mjs --dry-run` exercises the same validation and planning path but
  does not write ADR files, mutate superseded ADRs, or update `CLAUDE.md`.
- Validation failures now include a `Fix:` action or a clearer helper boundary
  message.
- The validator wrapper has a short portability document and a better missing
  module error.

## Evidence
- `bash tests/adr-validation-golden.sh`
- `bash tests/adr-helper-smoke.sh`
- `bash tests/adr-validate-smoke.sh`
- `bash tests/adr-hook-smoke.sh`
- `bash tests/claude-skills-smoke.sh`
- `node scripts/validate-adrs`
- `node --check scripts/validate-adrs`
- `node --check claude/skills/adr/scripts/adr-validation.mjs`
- `node --check claude/skills/adr/scripts/apply-adr.mjs`
- `python3 /Users/tonours/.codex/skills/.system/skill-creator/scripts/quick_validate.py claude/skills/adr`
- `python3 /Users/tonours/.codex/skills/codex-dynamic-workflows/scripts/verify_workflow.py .workflow/adr-golden-dry-run`
- `git diff --check`

## Not run
`tests/adr-skill-e2e.sh` and `tests/adr-skill-stress.sh` were not run because
they call `claude -p`, are explicitly documented as manual/costly, and this pass
did not change `SKILL.md` or the observable agent procedure.
