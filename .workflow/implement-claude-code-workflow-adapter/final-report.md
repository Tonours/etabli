# Final Report: Implement Claude Code workflow adapter

## Outcome
Implemented the Claude Code adapter for the shared Etabli workflow loop using
Claude-native commands, optional hooks, a settings fragment, docs, installer
coverage, symlink checks, fixtures, and smoke tests.

## Accepted Results
- `claude/commands/*` now align with the shared `workflow/spec.md` contract.
- Added `claude/commands/verify-workflow.md` instead of shadowing native
  `/verify`.
- Added `claude/hooks/workflow-router-lib.mjs`,
  `claude/hooks/workflow-router.mjs`, and
  `claude/hooks/plan-ready-guard.mjs`.
- Added `claude/settings.workflow-hooks.json` as an opt-in fragment.
- Updated install, symlink, README, Claude docs, workflow spec, scaffold docs,
  and tests.

## Rejected Results
- Did not mutate live `~/.claude/settings.json`.
- Did not add a `/verify` Claude command.
- Did not copy Pi's extension implementation into Claude.

## Conflicts Resolved
- Claude native `/verify` conflict resolved by naming the Etabli verifier
  `/verify-workflow`.
- Settings-secret risk resolved by linking a fragment rather than editing live
  settings.
- READY guard escape via nested `PLAN.md` resolved by allowing edits only to the
  workspace root `PLAN.md`.

## Verification Evidence
- `bash tests/claude-hooks-smoke.sh` passed.
- `bash tests/workflow-docs-smoke.sh` passed.
- `bash tests/fix-links-smoke.sh` passed.
- `bash tests/install-smoke.sh` passed.
- `bash tests/workflow-scaffold-smoke.sh` passed.
- `RUN_AGENT_CLI_SMOKE_SELF_TEST=1 bash tests/workflow-cli-smoke.sh` passed.
- `RUN_AGENT_CLI_SMOKE=1 bash tests/workflow-cli-smoke.sh` passed.
- `RUN_AGENT_CLI_SMOKE=1 RUN_CLAUDE_PRINT_SMOKE=1 bash tests/workflow-cli-smoke.sh` passed.
- `bun test pi/extensions/__tests__/` passed: 108 tests.
- `bash scripts/check-fix-symlinks.sh --verbose` passed after applying the new
  links with `--fix`.
- `claude --version` returned `2.1.177 (Claude Code)`.
- `git diff --check` passed.
- Terminology search found `harness` only in external source titles or legacy
  cleanup lines, not in the new Claude adapter surface.

## Remaining Risks
- Hooks are installed as linked files plus a settings fragment. Claude Code will
  only enforce them when that fragment is activated by the user's settings
  strategy.
- Router keywords are deterministic and inspectable, but they remain keyword
  heuristics rather than full semantic intent detection.

## Reusable Follow-up
- Use this adapter pattern for other agent surfaces: shared `workflow/spec.md`,
  native commands, optional deterministic hooks, fixture-backed tests, and no
  live secret settings rewrite.
