# Etabli

Personal dev environment for AI-assisted workflows across Neovim, Claude Code, Pi Coding Agent, tmux, iTerm2, VS Code, and a macOS tiling setup.

The repo is intentionally source-of-truth oriented: the install script symlinks tracked config into your local environment, so editing files here updates the live setup.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

- Supported: macOS and Linux (Ubuntu/Debian)
- VS Code should be installed separately on Linux if you want settings and extensions linked automatically
- Most secrets stay out of the repo and should come from shell env vars or local files loaded outside git

## Repo map

- `nvim/` - daily-driver Neovim config, including the diff-centric review workflow
- `claude/` - tracked Claude Code commands and workflow notes
- `pi/` - Pi configuration, extensions, skills, themes, and agent settings
- `workflow/` - canonical planning, review, and handoff docs shared across runtimes
- `profiles/` - explicit personal/work usage contracts
- `memory/` - minimal project memory layout and templates
- `scripts/` - installer, worktree tooling, terminal bootstraps, and platform helpers
- `vscode/` - tracked VS Code settings, keybindings, and extension list
- `tmux.conf`, `iterm2/`, `yabai/`, `skhd/`, `starship/` - terminal and window-management setup

## Where to look next

### Editor and review flow

- `nvim/README.md` - Neovim overview and key flows
- `docs/nvim-diff-review-workflow.md` - diff-centric review inbox, statuses, batch prompts, Claude/Pi launch flow

### Claude and Pi

- `claude/README.md` - Claude Code workflow notes
- `docs/pi-cheatsheet-fr.md` - Pi commands, shortcuts, and repo-specific reminders
- `pi/AGENTS.md` - project-specific agent instructions used by Pi

### ADE shared status

- Neovim exports one shared ADE snapshot per worktree at `~/.pi/status/<sanitized-cwd>.ade.json`
- Pi reads that snapshot through the ambient `ade-status` extension
- Claude reads that snapshot through `claude/commands/ade-status.md`
- `./scripts/test-ade-local.sh` runs the bounded local verification flow for this ADE surface

### Planning and execution

- `workflow/spec.md` - canonical workflow contract
- `workflow/operating-model.md` - daily Claude + Pi operating model, execution modes, and worktree parallelism rules
- `workflow/statuses.md` - lifecycle and status model
- `workflow/review-rubric.md` - review expectations
- `workflow/handoff-template.md` - continuation handoff template
- `PLAN_TEMPLATE.md` - canonical source for `PLAN.md`

### Profiles and memory

- `profiles/README.md` - profile structure and usage
- `docs/profiles.md` - when to choose personal vs work posture
- `memory/README.md` - memory goals and layout
- `memory/projects/README.md` - per-project memory convention

## Core workflow

```text
problem -> learn -> phase-0 measure -> plan -> PLAN.md (DRAFT) -> plan-review -> PLAN.md (CHALLENGED/READY) -> implement
```

- `PLAN.md` is the single execution contract across Claude and Pi
- `PLAN_TEMPLATE.md` is the canonical template
- the phase-0 measurement contract lives inside `PLAN.md`; no extra mandatory artifact is introduced
- the phase-1 execution contract also lives inside `PLAN.md`: slices, file scope, checks, invariants, done criteria, rollback points
- phase 2 keeps light implementation state in `PLAN.md`: active slice, completed slices, pending checks, next recommended action
- phase 3 makes review plan-aware: self-check, plan compliance, adversarial review, human checkpoint triggers
- implementation should start only from a `READY` `PLAN.md`
- review and handoff docs live under `workflow/` and are shared across runtimes

## Worktree and agent loop

Typical flow in this repo:

1. create or open a worktree with `cw`
2. explore or plan with Claude/Pi
3. implement from a `READY` plan
4. review diffs inside Neovim or via runtime review commands
5. hand off or merge once verified

Delegation default:
- scout/reviewer can run in parallel for reconnaissance/review
- worker stays single by default unless work is explicitly isolated

Daily execution modes:
- simple mode: one worker, one clear path
- standard mode: scout/worker/reviewer around one main implementation path
- option-compare mode: multiple workers only in isolated worktrees with explicit keep/discard gates

For the full zero-idle Claude + Pi loop, see `workflow/operating-model.md`.

Useful entrypoints:

- `cw new <repo> <task> [prefix]`
- `cw open <repo> [branch|path|name]`
- `cw pick <repo>`
- `scripts/cw-mode <simple|standard|option-compare> <repo|path> "<task>"`
- `source scripts/cw-mode-aliases.sh` for short shell wrappers: `cws`, `cwstd`, `cwcmp`, `cwtmux` (and `scripts/install.sh` now wires this automatically into Bash/Zsh rc files)
- `cw merge <repo> [branch|path|name] --yes`
- `cw rm <repo> [branch|path|name] --yes`
- `cw-clean <repo> --yes`

For the full workflow surface, use the dedicated docs above instead of this root README.

Local ADE verification:

- run `./scripts/test-ade-local.sh` before commit when touching the shared ADE snapshot flow
- it runs targeted ADE Bun tests, Neovim ADE/review smokes, the Pi extension suite, and `git diff --check`
- the real Claude `/ade-status` runtime check remains manual

## Config and secrets

- Pi tracked source files live in `pi/` and are symlinked into `~/.pi/` by `scripts/install.sh`
- `pi/models.json`, `pi/settings.json`, and `pi/agent/settings.json` are the editable source files
- `auth.json` and credentials are intentionally not tracked
- API keys such as `MISTRAL_API_KEY` should come from your shell environment or a non-tracked local secret loader

## Platform notes

- macOS tiling uses Yabai + skhd
- iTerm2, tmux, and Starship are configured from this repo
- VS Code config and recommended extensions are tracked under `vscode/`
- Prettier, language servers, and related CLI dependencies are handled by the installer where relevant

## Philosophy

- keep source-of-truth config in the repo
- keep secrets and auth local
- prefer small dedicated docs over one giant README
- keep planning and review contracts shared across Claude and Pi
