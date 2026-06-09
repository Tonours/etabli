# Etabli

Personal dev environment for AI-assisted workflows across Neovim, Claude Code, Pi Coding Agent, Ghostty, and tmux.

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
- `pi/` - Pi config, extensions, skills, themes
- `claude/` - Claude Code commands and local instructions
- `workflow/` - canonical workflow contract and templates
- `docs/` - focused user docs
- `scripts/` - installer and maintenance scripts

## Workflow

Canonical contract: `workflow/spec.md`.

Default loop:

```text
learn -> plan -> implement -> review -> validate
```

Use `PLAN.md` as the only execution artifact. Implement only from `Status: READY`.

## Useful commands

```bash
fix-links check
fix-links
hunk diff --watch
bun test pi/extensions/__tests__/
```

Neovim review:

```text
:ReviewInbox          # opens or reloads Hunk for the current repo
:ReviewCurrentHunk    # focuses the current line in the live Hunk session
:ReviewClaudeReview   # launches an interactive Claude Hunk review prompt
:ReviewPiReview       # launches an interactive Pi Hunk review prompt
:ReviewHunkSync       # pulls live Hunk notes into local persistence
:ReviewHunkNextComment
:ReviewHunkPrevComment
```

Legacy local review commands are hidden by default. Set `vim.g.etabli_review_legacy_commands = 1` only if you need the old local status inbox while Hunk persistence gaps remain.

Pi:

```text
/skill:plan-loop <task>
/skill:plan-implement <task>
/skill:implement
/skill:review
```

Claude:

```text
/plan-loop
/plan-implement
/implement
/review
```

## Project harness

Deploy the Etabli agent harness into a new or existing project:

```bash
deploy-harness ~/code/my-project
deploy-harness . --dry-run
```

The harness installs:

- `AGENTS.md`
- `CLAUDE.md`
- `workflow/spec.md`
- `workflow/review-rubric.md`
- `workflow/ticket-template.md`
- `PLAN_TEMPLATE.md`
- `PLAN_TEMPLATE_FULL.md`
- `docs/agent-harness.md`
- `docs/claude-code-harness.md`
- `docs/project-context.md`

Existing files are never overwritten by default. Review conflicts manually, or rerun with `--force` to create timestamped backups before replacing files.

Validation:

```bash
tests/harness-smoke.sh
tests/workflow-docs-smoke.sh
tests/fix-links-smoke.sh
tests/install-smoke.sh
tests/nvim-smoke.sh
RUN_AGENT_CLI_SMOKE_SELF_TEST=1 tests/harness-cli-smoke.sh
RUN_AGENT_CLI_SMOKE=1 tests/harness-cli-smoke.sh
RUN_AGENT_CLI_SMOKE=1 RUN_CLAUDE_PRINT_SMOKE=1 tests/harness-cli-smoke.sh
```

The CLI smoke test runs real Pi prompts in a temporary project and verifies the Claude Code binary with `claude --version`. Claude Code `--print` is behind `RUN_CLAUDE_PRINT_SMOKE=1` because Anthropic treats `--print` / `-p` as non-interactive Agent SDK usage.

## Config notes

- `pi/agent/settings.json` is a tracked bootstrap/default; live `~/.pi/agent/settings.json` stays local.
- `pi/models.json` and `pi/settings.json` are linked into `~/.pi/`.
- `ghostty/config` is linked to `~/.config/ghostty/config`.
- secrets and auth files stay local and untracked.

## References

- `workflow/spec.md` - workflow contract
- `workflow/review-rubric.md` - review output and priorities
- `docs/hunk-review-migration-feasibility.md` - Hunk review migration evidence and decision record
- `PLAN_TEMPLATE.md` - default lightweight plan
- `PLAN_TEMPLATE_FULL.md` - full plan for risky work
- `harness/templates/` - project harness templates
- `docs/pi-cheatsheet.md` - Pi usage reminders
- `nvim/README.md` - Neovim notes
- `claude/README.md` - Claude installed surface
