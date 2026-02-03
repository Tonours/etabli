# Etabli

Personal dev environment for AI-assisted parallel workflows with Neovim, tmux, Ghostty, Claude Code and OpenCode.

Inspired by [Anthropic's Claude Code best practices](https://anthropic.com/engineering/claude-code-best-practices) (Boris Cherny).

## Quick Start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

The installer symlinks all configs to the repo, so edits here are reflected everywhere.

Works on **macOS** and **Linux** (Ubuntu/Debian).

## What's Inside

```
claude/                     Claude Code config
  settings.json             Permissions + PostToolUse hooks (Prettier)
  commands/                 Slash commands: plan, review, verify, commit, learn
  CLAUDE.md.template        Starter CLAUDE.md for new projects

ghostty/config              Ghostty terminal (Catppuccin Mocha, JetBrains Mono)

nvim/                       Neovim config (LazyVim)
  lua/config/               Options, keymaps, autocmds
  lua/plugins/core/         Theme, LSP, git, editor, AI, lualine, explorer
  lua/plugins/lang/         TypeScript, Rust, Ember
  lua/plugins/extras/       Hardtime, Precognition

opencode/opencode.json      OpenCode config (GPT-5.2-Codex, Claude Opus)

scripts/
  install.sh                Full setup (deps, nvim, tmux, fonts, scripts)
  cw                        Claude Worktree Manager
  cw-clean                  Clean merged worktrees
  nightshift                Overnight batch runner
  dev-spawn                 Launch local + VPS tmux sessions
  tmux-clipboard.sh         Cross-platform clipboard (pbcopy/wl-copy/xclip/OSC52)
  tmux-claude-status.sh     Claude session count in tmux status bar
  claude-usage.sh           Enable Claude status display

skills/                     Shared skills (React best practices, Web design guidelines)

tmux.conf                   tmux config (Catppuccin Mocha, vim keys, fast nav)
```

## Workflow

The engineer supervises parallel sessions, each in its own git worktree:

```
/plan  ->  /review  ->  implement  ->  /verify  ->  /commit  ->  /learn
```

### Git Worktrees

```bash
# Create worktree + tmux window + launch Claude
cw myproject auth feature        # -> feature/auth

# Create without launching Claude
cw -n myproject bug42 fix        # -> fix/bug42

# Clean merged worktrees
cw-clean myproject
```

`CLAUDE_PROJECT_ROOT` defaults to `~/projects`.

### Slash Commands

| Command            | What it does                              |
| ------------------ | ----------------------------------------- |
| `/plan <feature>`  | Create PLAN.md with steps, risks, deps    |
| `/review`          | Staff-engineer review of PLAN.md          |
| `/verify`          | Run typecheck, tests, lint                |
| `/commit`          | Stage, commit, push, create PR            |
| `/learn`           | Update CLAUDE.md after a mistake          |

### Night Shift

Prepare 1-3 tasks before leaving. The machine works overnight, commits and pushes (no PR, no merge).

```bash
nightshift init                  # Create tasks template
nightshift run --dry-run         # Preview
nightshift run                   # Execute overnight
nightshift status                # Check results next morning
```

Tasks are Markdown blocks in `~/.local/state/nightshift/tasks.md`. Supports `codex`, `claude`, or `none` engines. See [docs/nightshift.md](docs/nightshift.md) for details.

### Dev Spawn

```bash
dev-spawn all                    # Local + VPS tmux sessions
dev-spawn local                  # Local only
dev-spawn vps                    # VPS only
```

## Keymaps

### tmux

| Shortcut       | Action                 |
| -------------- | ---------------------- |
| `Alt+1..5`     | Jump to window         |
| `Alt+arrows`   | Navigate panes         |
| `Prefix + \|`  | Split vertical         |
| `Prefix + -`   | Split horizontal       |
| `Prefix + z`   | Zoom/unzoom pane       |
| `Prefix + Space` | Last session         |

Clipboard: copy-mode pipes through `tmux-clipboard.sh` (pbcopy > wl-copy > xclip > OSC52).

### Neovim

| Keymap         | Action                 |
| -------------- | ---------------------- |
| `<leader>cm`   | Open CLAUDE.md         |
| `<leader>gw`   | Switch worktree        |
| `<leader>gW`   | Create worktree        |
| `<leader>gd`   | Diff view              |
| `<leader>gD`   | Diff vs last commit    |
| `<leader>gh`   | File history           |
| `<leader>ha`   | Harpoon add            |
| `<leader>hh`   | Harpoon menu           |
| `<leader>1-5`  | Harpoon file 1-5       |
| `<leader>sR`   | Search & replace       |
| `Alt+l`        | Accept Copilot         |

## Manual Install

If you prefer to set things up yourself:

```bash
# Neovim (symlink, not copy)
ln -sfn $(pwd)/nvim ~/.config/nvim

# tmux
ln -sf $(pwd)/tmux.conf ~/.tmux.conf

# Ghostty
mkdir -p ~/.config/ghostty
ln -sf $(pwd)/ghostty/config ~/.config/ghostty/config

# Scripts
mkdir -p ~/.local/bin
for s in cw cw-clean nightshift dev-spawn tmux-clipboard.sh tmux-claude-status.sh claude-usage.sh; do
  ln -sf $(pwd)/scripts/$s ~/.local/bin/$s
done

# Claude Code
mkdir -p ~/.claude/commands
ln -sf $(pwd)/claude/settings.json ~/.claude/settings.json
ln -sf $(pwd)/claude/commands/*.md ~/.claude/commands/

# OpenCode
mkdir -p ~/.config/opencode
ln -sf $(pwd)/opencode/opencode.json ~/.config/opencode/opencode.json

# Font (macOS)
brew install --cask font-jetbrains-mono-nerd-font
```

## Theme

Catppuccin Mocha everywhere: Neovim, tmux, Ghostty. Font: JetBrains Mono Nerd Font.
