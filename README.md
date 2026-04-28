# Etabli

Personal dev environment for AI-assisted workflows across Neovim, Claude Code, Pi Coding Agent, and tmux.

The repo stays source-of-truth oriented: the install script symlinks tracked config into your local environment, and re-running it re-syncs the live Neovim and Pi setup from the repo defaults.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

- Supported: macOS and Linux (Ubuntu/Debian)
- Neovim target is `0.12.2+`; the installer validates the local version after dependency setup
- Neovim Copilot uses native LSP inline completion via `copilot-language-server`
- Neovim exposes `:EtabliDoctor` plus `:CopilotStatus` / `:CopilotToggle` for local diagnosis and per-project Copilot control
- Default coding font is `CaskaydiaMono Nerd Font` with editor ligatures disabled
- Most secrets stay out of the repo and should come from shell env vars or local files loaded outside git

## Useful maintenance

Quick symlink audit or fix after moving or renaming the repo:

```bash
fix-links check
fix-links
```

The underlying scripts live in `scripts/check-fix-symlinks.sh` and `scripts/fix-links`.

## Repo map

- `nvim/` - daily-driver Neovim config, including the diff-centric review workflow
- `claude/` - tracked Claude Code commands and workflow notes
- `pi/` - Pi configuration, minimal workflow skills, lightweight extensions, themes, and agent settings
- `workflow/` - canonical planning and review docs shared across runtimes
- `profiles/` - explicit personal/work usage contracts
- `memory/` - minimal project memory layout and templates
- `scripts/` - installer, local verification runners, and workflow helpers

## Where to look next

- `nvim/README.md` - Neovim overview and key flows
- `docs/nvim-diff-review-workflow.md` - diff-centric review inbox and batch prompts
- `claude/README.md` - Claude Code workflow notes
- `docs/pi-cheatsheet.md` - Pi commands, shortcuts, and repo-specific reminders
- `workflow/spec.md` - canonical workflow contract
- `workflow/operating-model.md` - daily Claude + Pi operating model
- `workflow/statuses.md` - lifecycle and status model
- `workflow/review-rubric.md` - review expectations
- `PLAN_TEMPLATE.md` - canonical source for `PLAN.md`

## Core workflow

```text
problem -> learn -> phase-0 measure -> plan-loop -> PLAN.md (CHALLENGED/READY) -> implement -> review
```

- `PLAN.md` is the single execution contract across Claude and Pi
- `PLAN_TEMPLATE.md` is the canonical template
- the phase-0 measurement contract lives inside `PLAN.md`
- the execution contract also lives inside `PLAN.md`: slices, file scope, checks, invariants, done criteria, rollback points
- implementation should start only from a `READY` `PLAN.md`
- review stays plan-aware

## Daily loop

Typical flow in this repo:

1. inspect current repo state
2. explore or run `plan-loop`
3. implement from a `READY` plan
4. review diffs inside Neovim or via runtime review commands
5. run focused checks and manual QA
6. commit once verified

## OPS shared status

- Neovim exports one lightweight task projection per current cwd at `~/.pi/status/<sanitized-cwd>.task.json`
- Neovim exports one shared OPS snapshot per current cwd at `~/.pi/status/<sanitized-cwd>.ops.json`
- task + snapshot are regenerated together and share revision/timestamp metadata so Claude and local tooling see the same current task/title/next-action context
- task identity follows current branch first, then cwd/repo fallback
- Neovim exposes `:OPS`, `:OPSDoctor`, `:OPSReview`, `:OPSNext`, `:OPSAgents`, and related `:OPS*` commands for this surface
- `./scripts/test-ops-local.sh` runs the bounded local verification flow for this OPS surface
- `:EtabliDoctor` includes the existing OPS doctor checks alongside Neovim/Copilot/runtime checks

## Config and secrets

- Pi tracked source files live in `pi/`; most are symlinked into `~/.pi/` by `scripts/install.sh`, while mutable agent settings stay local
- Claude tracked commands and skills live in `claude/`; shared docs are installed from `workflow/` and the root `PLAN_TEMPLATE.md`
- `pi/models.json` and `pi/settings.json` are editable source files
- `pi/agent/settings.json` is a tracked bootstrap/default file; the live `~/.pi/agent/settings.json` stays local so model switches do not dirty the repo
- the installer now links only the core Pi skills by default: `plan-loop`, `plan-implement`, `review`, `implement`, `caveman`, `ui`, `grill-me`
- the default Pi extension loadout is `rtk.ts`, `filter-output.ts`, and `block-google-providers.ts`; damage-control is intentionally disabled by default
- third-party Pi packages are kept explicit and filtered: `pi-hooks` only for LSP, `mitsupi` only for `github`/`commit`, `badlogic/pi-skills` only for `brave-search`, `pi-interview` for the interview tool, `pi-autoresearch` for experiment loops, and `glimpseui` installed without loading its standalone skill
- tmux is configured for Pi with `extended-keys` and `extended-keys-format csi-u` so modified Enter keybindings stay distinct
- `auth.json` and credentials are intentionally not tracked

## Philosophy

- keep source-of-truth config in the repo
- keep secrets and auth local
- prefer a small Pi runtime over orchestration layers
- keep planning and review contracts shared across Claude and Pi
