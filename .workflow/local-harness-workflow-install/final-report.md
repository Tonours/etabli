# Final Report: Local harness workflow install

## Outcome
Completed. The hardened Etabli workflow is installed locally for Codex, Claude
Code, and Pi.

## Accepted Results
- Codex tracked files were relinked into `~/.codex` with 372 repo symlinks and
  no remaining copies, missing files, or divergent files.
- Claude Code workflow commands, hooks, hook settings fragment, skills, shared
  workflow docs, and templates are linked into `~/.claude`.
- Pi workflow guidance, templates, skills, extensions, themes, and settings
  resources are available under `~/.pi`.
- Live Pi settings preserve local non-managed packages while syncing managed
  Etabli and `@tintinweb` package entries.

## Rejected Results
- Did not run the full `scripts/install.sh`, because it also touches unrelated
  dev surfaces such as Ghostty, tmux, global tools, and Neovim.
- Did not merge into `~/.claude/settings.json`, because that file may contain
  secrets or local runtime state.

## Conflicts Resolved
- Replaced identical Codex live copies with symlinks via `--prefer-links`.
- Backed up Pi agent settings before managed package sync:
  `/Users/tonours/.pi/agent/settings.json.bak.20260703-090415`.
- Backed up the older local Claude commit command before linking the tracked
  command:
  `/Users/tonours/.claude/commands/commit.md.bak.20260703-090415`.

## Verification Evidence
- `scripts/deploy-agent-workflow --dry-run`: no `WOULD_*`, `CONFLICT`,
  `MISSING`, or `FAILED` entries after apply.
- `bash tests/deploy-agent-workflow-smoke.sh`: passed.
- `bash tests/workflow-docs-smoke.sh`: passed.
- `bash tests/codex-organization-smoke.sh`: passed.
- `bash tests/claude-hooks-smoke.sh`: passed.
- `bun test pi/extensions/__tests__/`: 165 passed, 0 failed.
- `RUN_REAL_AGENT_SCENARIOS=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh`:
  passed with Pi, Claude Code, and Codex CLI detected.

## Remaining Risks
- The deployer does not install or update external Pi npm packages; it only
  synchronizes local settings and links repo-managed files.
- Claude workflow hooks are linked as a settings fragment. Activation still
  depends on how the live Claude Code settings include that fragment.

## Reusable Follow-up
- Use `scripts/deploy-agent-workflow --dry-run` before local harness changes.
- Use `scripts/deploy-agent-workflow --apply` to re-apply the three-harness
  workflow without running the full dev environment installer.
