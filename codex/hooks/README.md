# Codex Hooks

`hooks.json` tracks the hook events used by this setup. Commands use `$HOME`
instead of a machine-specific absolute path so the file can be deployed by
`scripts/deploy-codex`.

The hook target script itself, `~/.codex/herdr-agent-state.sh`, stays local.
It is small but executable local state, not a repo-managed Codex convention.
