# pi-manual-smoke

Manual smoke test of the Pi **TaskExecute / subagents** workflow on a realistic
scenario grounded in the `etabli/` project.

## Scope (read-only on product)

- Exercise `TaskCreate` + `TaskExecute` to run two subagents in parallel.
- **Task A** — verify `etabli/pi/AGENTS.md`, `etabli/workflow/skills/orchestration.md`,
  `etabli/docs/agentic-workflow-hardening.md` describe the Pi `Task*` / subagents logic.
- **Task B** — verify `scripts/deploy-agent-workflow --dry-run` is replayable and that
  `~/.pi/agent/settings.json` declares `npm:@tintinweb/pi-tasks` and
  `npm:@tintinweb/pi-subagents`.
- Local (orchestrator) execution of the same dry-run + jq, in parallel with the subagents.

## Hard constraints

- No push. No secret / env-var access. No edits outside this directory.
- All write activity confined to `etabli/.workflow/pi-manual-smoke/`.

## Outputs

- `REPORT.md` — integrated findings + GO/NO-GO verdict.
- `local-dry-run.log` — captured `deploy-agent-workflow --dry-run` output.
- `subagent-a.md`, `subagent-b.md` — verbatim subagent returns.
