# claude-code-manual-smoke

Realistic smoke test of the Etabli Claude Code workflow (2026-07-03).

## Verdict: GO

Real native subagents used (Agent tool exposed). Both required scripts green.
See `INTEGRATION.md` for full accepted/rejected/conflicts/decisions/risks.

## Run at a glance
- Delegation: NATIVE (general-purpose x2, opus + sonnet), concurrent with local cmds.
- `scripts/deploy-agent-workflow --dry-run` -> exit 0 (454 OK).
- `tests/claude-hooks-smoke.sh` -> exit 0 (functional route assertions).
- Docs: DOCS_CONSISTENT. Install: INSTALL_PARTIAL.

## Key follow-up (does not block smoke verdict)
Managed workflow hooks are deployed but NOT wired into active `~/.claude/settings.json`.
They are dormant in this session. Needs a user decision to merge the fragment.

## Files
- `INTEGRATION.md` — full report + verdict.
- `subagent-A-docs.md` / `subagent-B-install.md` — verbatim subagent findings.
- `evidence/run.env`, `evidence/deploy-dry-run.log`, `evidence/hooks-smoke.log`.
