# Implemented: thin adapters, Claude command trim, keep bff-ticket-loop

## Metadata
- Archived: 2026-08-19
- Source plan: `PLAN.md` — KonMari follow-up — thin adapters, Claude command trim, keep bff-ticket-loop
- Source plan SHA-256: `736207e93016f44f8b6887f3faebee18c0141a23c8e5c0266afe3086599ba280`
- Status: IMPLEMENTED
- Commit / branch: `refactor/skill-default-load` (uncommitted at archive)

## Outcome
Work `bug-check` / `pr-qa` / `sec-pr` are thin pointers. employer Dependabot extras live in `claude/scopes/work/skills/sec-pr/references/employer-dependabot.md`. Ten unused Claude slash commands are gone; `/plan` is no longer an alias of plan-create. `bff-ticket-loop` stays in work scope. Adapter Source resolution 5-path lists are replaced by a one-line home fallback (plan-loop keeps its embedded PLAN template).

## Context
- Follow-up of `docs/plan/20260819-skill-default-load.md`
- `bff-ticket-loop` is a employer BFF epic ticket factory, not Etabli kernel

## Decisions
### Keep bff-ticket-loop
- Context: parking lot said archive later; user asked what it is
- Choice: keep in `claude/scopes/work/skills/`
- Rejected options: delete from etabli
- Rationale: it is still the PRD-637-style employer BFF decomposer; work-scoped, not default-loaded
- Consequences: employer epic ticket loop remains available on work machines

### Trim ten Claude commands
- Context: duplicate names (`/plan` vs `/plan-loop`) and unused slash commands
- Choice: delete commit, cross-repo-audit, front-quality, plan-create, pr-feedback, pre-commit, recap, spec-verify, tests-iso, ui-debug
- Rejected options: keep `/plan` DRAFT-only
- Rationale: one name per step; kernel commands remain
- Consequences: leftover `~/.claude/commands/plan.md` is pruned on next install/deploy

## Validation Evidence
- command: `bash tests/claude-commands-smoke.sh`
  - result: ok
- command: `bash tests/claude-skills-smoke.sh`
  - result: ok
- command: `bash tests/workflow-docs-smoke.sh`
  - result: ok
- command: `bash tests/deploy-agent-workflow-smoke.sh`
  - result: ok
- command: `scripts/verify-agentic-infra core`
  - result: PASS

## Follow-up State
- Remaining risks: leftover home links for deleted commands until `scripts/install.sh` or `check-fix-symlinks --fix`
- Parking lot: none from this KonMari pass
- Next links: `claude/README.md`, `workflow/spec.md`

## Superseded
- 2026-08-19 (same day, later): user rejected KEEP. `bff-ticket-loop` was deleted from `claude/scopes/work/skills/`. The KEEP decision above is historical only.
