# Etabli

Personal dev environment for AI-assisted workflows across Codex, Neovim,
Claude Code, Pi Coding Agent, Ghostty, and tmux. The repo is the source of
truth for tracked config; `scripts/install.sh` links or bootstraps local
files into the expected tool locations.

The installer uses an existing Node.js runtime (prefers `asdf`; it does not install `nvm`). Pi comes from `@earendil-works/pi-coding-agent`, Hunk from
`hunkdiff` (https://www.hunk.dev/).

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

## Repo map

- `nvim/` - Neovim config (`nvim/README.md`)
- `ghostty/`, `tmux.conf` - terminal config
- `codex/` - Codex organization surface (`docs/codex-organization.md`)
- `pi/` - Pi config, extensions, skills, themes (`docs/pi-cheatsheet.md`)
- `claude/` - Claude Code commands, hooks, skills (`claude/README.md`)
- `workflow/` - canonical workflow contract (`workflow/spec.md`)
- `docs/adr/` - Architecture Decision Records (`node scripts/validate-adrs .`)
- `docs/plan/` - implemented plan archives
- `scripts/` - installer, deploy, and maintenance scripts
- `tests/` - smoke tests

## Workflow

Canonical contract: `workflow/spec.md` — routing table, statuses, autonomous
loop rules, and the full command list live there, not here. `PLAN.md` is the
only execution artifact; implement only from `Status: READY`.

Adapters expose the same routes: Pi as `/skill:*`
(`/skill:plan-loop`, `/skill:plan-implement`, `/skill:adversary`,
`/skill:implement`, `/skill:review`, `/skill:verify`, `/skill:bug-check`,
`/skill:linear-ticket-create`, `/skill:linear-work`, `/skill:pr-review`,
`/skill:pr-qa`, `/skill:sec-pr`, `/skill:ci-fix`), Claude as slash commands
(`/plan-loop`, `/plan-implement`, `/ship`, `/adversary`, `/implement`,
`/review`, `/verify-workflow`, `/bug-check`, `/linear-ticket-create`,
`/linear-work`, `/pr-review`, `/pr-qa`, `/sec-pr`, `/ci-fix`).

Neovim review runs through Hunk (`:ReviewInbox`, `:ReviewClaudeReview`,
`:ReviewPiReview`), opening
`hunk diff --watch --mode auto --theme custom --no-wrap --line-numbers --agent-notes --no-transparent-bg`.

## Deployment

```bash
scripts/deploy-codex --dry-run          # tracked Codex files into ~/.codex
scripts/deploy-agent-workflow --apply   # Three-harness workflow deployment
scaffold-project ~/code/my-project --new
deploy-workflow . --check               # OK / DRIFT / MISSING report
```

`deploy-codex` deploys `config.managed.toml` (never the live `config.toml`,
which can hold secrets). `deploy-agent-workflow` links Claude/Pi/Codex
workflow surfaces and syncs only managed Pi package resources in
`~/.pi/agent/settings.json`. `scaffold-project` wraps `deploy-workflow` to
install the workflow scaffold (`workflow-scaffold/templates/` plus live
`workflow/` files) into a project; existing files are never overwritten by
default.

## Validation

```bash
node scripts/validate-adrs .
tests/codex-organization-smoke.sh
tests/workflow-scaffold-smoke.sh
tests/workflow-contract-coverage-smoke.sh
tests/workflow-efficiency-report-smoke.sh
tests/workflow-monitor-smoke.sh
tests/workflow-metrics-smoke.sh
tests/workflow-dossier-smoke.sh
tests/router-eval-smoke.sh
tests/research-proof-check-smoke.sh
tests/lean-ctx-check-smoke.sh
tests/workflow-docs-smoke.sh
tests/claude-hooks-smoke.sh
tests/agent-scenarios-smoke.sh
tests/fix-links-smoke.sh
tests/install-smoke.sh
tests/deploy-agent-workflow-smoke.sh
tests/workflow-event-smoke.sh
tests/runtime-capabilities-smoke.sh
tests/nvim-smoke.sh
RUN_AGENT_CLI_SMOKE_SELF_TEST=1 tests/workflow-cli-smoke.sh
RUN_AGENT_CLI_SMOKE=1 tests/workflow-cli-smoke.sh
RUN_AGENT_CLI_SMOKE=1 RUN_CLAUDE_PRINT_SMOKE=1 tests/workflow-cli-smoke.sh
RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh
```

The CLI smoke runs real Pi prompts in a temporary project and verifies the
Claude binary with `claude --version`; `--print` stays behind
`RUN_CLAUDE_PRINT_SMOKE=1`. Codex App subagent orchestration rules:
`docs/codex-app-subagents.md`.

Workflow feedback-loop helpers are read-only: `workflow-monitor` reports stale,
blocked, failing, and active ledgers; `workflow-metrics` aggregates optional
`outcome_metric` events into tokens per successful outcome; `workflow-dossier`
emits sanitized replay/debug context for one run; `router-eval` scores Pi/Claude
router decisions from `tests/router-evals/`; `research-proof-check` rejects
unsourced research artifacts; `lean-ctx-check` verifies the optional lean-ctx
fallback contract without installing anything.

## Config notes

- `pi/agent/settings.json` is a tracked bootstrap; the live copy stays local.
  `@tintinweb/pi-tasks` is paired with `@tintinweb/pi-subagents`
  (`TaskExecute` needs the `subagents:rpc:*` protocol).
- Secrets and auth files stay local and untracked.

Projects scaffolded with `workflow/spec.md` activate the Etabli workflow
ambiently. Users can write ordinary prompts such as "corrige le bug et valide";
explicit workflow wording is only for heavier orchestration.
