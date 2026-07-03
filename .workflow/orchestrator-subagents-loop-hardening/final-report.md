# Final Report: orchestrator subagents loop hardening

## Outcome

Completed. The open live Codex finding was resolved with backups and safe
tracked-file sync, then the workflow was hardened with source-backed rules for
subagent delegation, retry loops, and completion evidence.

## Accepted Results

- Live Codex dry-run conflicts are resolved.
- Added source-backed hardening notes in `docs/agentic-workflow-hardening.md`.
- Strengthened shared orchestration rules for sandbox/approval context,
  evidence-consuming retries, and runtime-backed completion evidence.
- Strengthened Codex App subagent docs and Codex dynamic workflow trigger recipe.
- Added smoke assertions for the new durable rules.

## Rejected Results

- Rejected a new external orchestrator.
- Rejected universal subagent guarantees across Codex, Claude, and Pi.
- Rejected generic hardening prose without source or validation coverage.

## Conflicts Resolved

- `scripts/deploy-codex --dry-run` conflicts for three stale live Codex files.
- Follow-up conflict after editing `codex/workflow/dynamic-workflow-triggers.md`.

## Verification Evidence

- `scripts/deploy-codex --dry-run` -> exit 0, `SUMMARY dry-run complete`.
- `bash tests/workflow-docs-smoke.sh` -> ok.
- `bash tests/codex-organization-smoke.sh` -> ok.
- `bash tests/workflow-scaffold-smoke.sh` -> ok.
- `bash tests/claude-hooks-smoke.sh` -> ok.
- `bun test pi/extensions/__tests__/` -> 165 pass, 0 fail.
- `git diff --check` -> clean.
- `RUN_REAL_AGENT_SCENARIOS=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh` -> ok with Pi 0.80.2, Claude Code 2.1.196, Codex CLI 0.142.5.
- Workflow verifier for this run -> passed.

## Remaining Risks

- Future Codex, Claude, or Pi releases can change runtime surfaces; keep
  capability labels and real scenarios as regression gates.
- Real agent scenarios still depend on model/provider availability.

## Reusable Follow-up

- Before changing subagent or loop behavior, rerun the real scenario suite.
- Keep `docs/agentic-workflow-hardening.md` aligned with source-backed rules in
  `workflow/skills/orchestration.md`.
