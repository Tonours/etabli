# Etabli

Personal dev environment for AI-assisted workflows across Codex, Neovim, Claude Code, Pi Coding Agent, Ghostty, and tmux.

The repo is the source of truth for tracked config. `scripts/install.sh` links or bootstraps local files into the expected tool locations.

The installer uses an existing Node.js runtime, preferring `asdf` when available. It does not install `nvm`; Pi is installed from the official `@earendil-works/pi-coding-agent` package, and Hunk is installed from the official `hunkdiff` package documented at https://www.hunk.dev/.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

## Repo map

- `nvim/` - Neovim config
- `ghostty/` - Ghostty terminal config
- `tmux.conf` - tmux config
- `codex/` - Codex global instructions, workflow, prompts, automations, hooks, and personal skills
- `pi/` - Pi config, extensions, skills, themes
- `claude/` - Claude Code commands and local instructions
- `workflow/` - canonical workflow contract and templates
- `docs/` - focused user docs
- `scripts/` - installer and maintenance scripts

## Workflow

Canonical contract: `workflow/spec.md`. New here? Start with `docs/workflow-101.md` for the guided introduction.

Default loop:

```text
learn -> plan -> implement -> review -> validate
```

Use `PLAN.md` as the only execution artifact. Implement only from `Status: READY`.
Implemented and validated plans are archived as memory records in `docs/plan/`.

## Useful commands

```bash
fix-links check
fix-links
hunk diff --watch --mode auto --theme custom --no-wrap --line-numbers --agent-notes --no-transparent-bg
bash tests/codex-organization-smoke.sh
bun test pi/extensions/__tests__/
```

Neovim review:

```text
:ReviewInbox          # opens or reloads Hunk for the current repo
:ReviewCurrentHunk    # focuses the current line in the live Hunk session
:ReviewClaudeReview   # launches an interactive Claude Hunk review prompt
:ReviewPiReview       # launches an interactive Pi Hunk review prompt
:ReviewHunkSync       # manual checkpoint for Hunk note persistence/rehydration
:ReviewHunkNextComment
:ReviewHunkPrevComment
```

Legacy local review commands are hidden by default. Set `vim.g.etabli_review_legacy_commands = 1` only if you need the old local status inbox while Hunk persistence gaps remain.

Pi:

```text
/skill:plan-loop <task>
/skill:plan-implement <task>
/skill:adversary
/skill:implement
/skill:review
/skill:verify
/skill:bug-check
/skill:linear-ticket-create
/skill:linear-work
/skill:pr-review
/skill:pr-qa
/skill:sec-pr
/skill:ci-fix
/skill:github-pr-review
```

Claude:

```text
/plan
/plan-loop
/plan-implement
/adversary
/implement
/review
/verify-workflow
/bug-check
/linear-ticket-create
/linear-work
/pr-review
/pr-qa
/sec-pr
/ci-fix
/github-pr-review
```

Codex:

```bash
scripts/audit-codex-organization
scripts/deploy-codex --dry-run
scripts/deploy-codex --apply
```

`scripts/deploy-codex` links tracked Codex files into `~/.codex`. It deploys
`config.managed.toml` instead of replacing the live `config.toml`, because the
live file can contain local trust state, provider configuration, and secrets.

## Project workflow scaffold

Deploy the Etabli workflow scaffold into a new or existing project:

```bash
scaffold-project ~/code/my-project --new
scaffold-project . --convert --dry-run
deploy-workflow . --dry-run
```

The workflow scaffold installs:

- `AGENTS.md`
- `CLAUDE.md`
- `workflow/memory.md`
- `workflow/plan-archive.md`
- `workflow/spec.md`
- `workflow/skills/adversary.md`
- `workflow/skills/implementation-loop.md`
- `workflow/skills/orchestration.md`
- `workflow/review-rubric.md`
- `workflow/ticket-template.md`
- `workflow/linear-ticket-template.md`
- `PLAN_TEMPLATE.md`
- `PLAN_TEMPLATE_FULL.md`
- `docs/agent-workflow.md`
- `docs/claude-code-workflow.md`
- `docs/agent-memory/README.md`
- `docs/plan/README.md`
- `docs/project-context.md`

Existing files are never overwritten by default. Review conflicts manually, or rerun with `--force` to create timestamped backups before replacing files.

`scaffold-project` is the user-facing command. It wraps `deploy-workflow` with explicit `--new` and `--convert` modes for new projects and existing project conversions.

Validation:

```bash
tests/codex-organization-smoke.sh
tests/workflow-scaffold-smoke.sh
tests/workflow-docs-smoke.sh
tests/claude-hooks-smoke.sh
tests/fix-links-smoke.sh
tests/install-smoke.sh
tests/nvim-smoke.sh
RUN_AGENT_CLI_SMOKE_SELF_TEST=1 tests/workflow-cli-smoke.sh
RUN_AGENT_CLI_SMOKE=1 tests/workflow-cli-smoke.sh
RUN_AGENT_CLI_SMOKE=1 RUN_CLAUDE_PRINT_SMOKE=1 tests/workflow-cli-smoke.sh
RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh
```

The CLI smoke test runs real Pi prompts in a temporary project and verifies the Claude Code binary with `claude --version`. Claude Code `--print` is behind `RUN_CLAUDE_PRINT_SMOKE=1` because Anthropic treats `--print` / `-p` as non-interactive Agent SDK usage.

The real agent scenarios test runs separate Pi, Claude Code, and Codex CLI invocations in temporary scaffolded projects. It checks realistic workflow-routing prompts with actual CLI/runtime context, including READY read-only prompts, adversarial code review, read-only adversarial PLAN.md review, actual READY implementation routing, prompt-only READY wording without a root `PLAN.md`, Codex's current-runtime-only subagent contract, and a Pi `TaskExecute` subagent run that creates an archive under `docs/plan/` and removes the root `PLAN.md`.

Codex App subagent orchestration is documented in `docs/codex-app-subagents.md`.
It is confirmed only for runtimes that expose `multi_agent_v1`; otherwise the
same workflow uses simulated `.workflow/<slug>/` packets.

## Config notes

- `codex/config.managed.toml` is a tracked non-secret baseline; live `~/.codex/config.toml` stays local.
- `codex/hooks.json`, `codex/workflow/`, `codex/prompts/`, `codex/automations/`, and `codex/skills/` deploy through `scripts/deploy-codex`.
- `pi/agent/settings.json` is a tracked bootstrap/default; live `~/.pi/agent/settings.json` stays local. `@tintinweb/pi-tasks` is paired with `@tintinweb/pi-subagents` because `TaskExecute` needs the `subagents:rpc:*` protocol; the separate `npm:pi-subagents` package does not satisfy that protocol.
- `pi/models.json` and `pi/settings.json` are linked into `~/.pi/`.
- `ghostty/config` is linked to `~/.config/ghostty/config`.
- secrets and auth files stay local and untracked.

## References

- `workflow/spec.md` - workflow contract
- `workflow/skills/` - shared skill contracts used by Pi and Claude wrappers
- `workflow/skills/orchestration.md` - shared capability, delegation, retry, and fallback contract
- `workflow/memory.md` - persistent agent memory convention
- `workflow/plan-archive.md` - implemented plan archive convention
- `workflow/review-rubric.md` - review output and priorities
- `docs/agentic-workflow-hardening.md` - source-backed hardening notes for agentic loops and subagents
- `PLAN_TEMPLATE.md` - default lightweight plan
- `PLAN_TEMPLATE_FULL.md` - full plan for risky work
- `workflow-scaffold/templates/` - project workflow scaffold templates
- `docs/codex-app-subagents.md` - Codex App subagent runner and fallback rules
- `docs/workflow-101.md` - guided introduction to the workflow
- `docs/codex-organization.md` - tracked Codex surface and deployment rules
- `docs/fable5-notes.md` - Fable 5 migration decisions
- `docs/pi-cheatsheet.md` - Pi usage reminders
- `nvim/README.md` - Neovim notes
- `claude/README.md` - Claude installed surface
