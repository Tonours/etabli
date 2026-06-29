# Result: ADR helper hardening

## Outcome
The `/adr` skill now delegates deterministic ADR application to a bundled
helper:

`claude/skills/adr/scripts/apply-adr.mjs`

Claude still decides whether an ADR is warranted and drafts the title/body. The
helper owns numbering, slugging, file writes, limited supersession metadata,
`CLAUDE.md` index updates, pre/post validation, and rollback on post-write
failure.

The helper and `scripts/validate-adrs` now share validation logic through:

`claude/skills/adr/scripts/adr-validation.mjs`

## What changed
- Added deterministic helper `claude/skills/adr/scripts/apply-adr.mjs`.
- Added shared validation module `claude/skills/adr/scripts/adr-validation.mjs`.
- Refactored `scripts/validate-adrs` into a wrapper around the shared module.
- Added direct helper coverage in `tests/adr-helper-smoke.sh`.
- Updated `claude/skills/adr/SKILL.md` to call the helper instead of hand
  editing ADR files and indexes.
- Added the helper smoke test to `.github/workflows/agentic-infra.yml`.
- Fixed `/Users/tonours/.codex/skills/.system/skill-creator/scripts/quick_validate.py`
  so it works without PyYAML and accepts the local Claude skill frontmatter keys.

## Verification
Passed:
- `bash tests/adr-helper-smoke.sh`
- `bash tests/adr-validate-smoke.sh`
- `bash tests/adr-hook-smoke.sh`
- `bash tests/claude-skills-smoke.sh`
- `node scripts/validate-adrs`
- `node --check scripts/validate-adrs && node --check claude/hooks/detect-adr-signal.mjs && node --check claude/skills/adr/scripts/apply-adr.mjs`
- `bash -n tests/adr-helper-smoke.sh && bash -n tests/adr-skill-e2e.sh && bash -n tests/adr-skill-stress.sh`
- `bash tests/codex-organization-smoke.sh && bash tests/workflow-docs-smoke.sh && bash tests/workflow-scaffold-smoke.sh && bash tests/claude-hooks-smoke.sh && bash tests/workflow-cli-smoke.sh`
- `bash tests/adr-skill-e2e.sh`
- `bash tests/adr-skill-stress.sh`
- `git diff --check`
- `python3 /Users/tonours/.codex/skills/.system/skill-creator/scripts/quick_validate.py claude/skills/adr`
- `python3 /Users/tonours/.codex/skills/.system/skill-creator/scripts/quick_validate.py /Users/tonours/.codex/skills/goal-prompt-rewriter`
- `python3 -m py_compile /Users/tonours/.codex/skills/.system/skill-creator/scripts/quick_validate.py`

Claude `-p` evidence after helper update:
- Base E2E: 7/7, cost 2.400986 USD, Claude duration 607561 ms.
- Stress matrix: 7/7, cost 2.135669 USD, Claude duration 728575 ms.
- Latest persisted stress run:
  `.workflow/adr-helper-hardening/results/stress-run-20260626-214703`

Skipped by design:
- `bash tests/workflow-cli-smoke.sh` reports skipped unless
  `RUN_AGENT_CLI_SMOKE=1`.

## Residual risks
- A copied `scripts/validate-adrs` wrapper expects either a repository-local
  `claude/skills/adr/scripts/adr-validation.mjs` or the ADR skill installed at
  `~/.claude/skills/adr`. This is acceptable for the current Claude skill
  workflow, but it is not a standalone single-file validator anymore.
- Claude may still draft a poor ADR body. The helper deliberately does not solve
  judgment or prose quality; it only hardens application mechanics.
- Full `claude -p` stress remains manual because it is slow and costly.
