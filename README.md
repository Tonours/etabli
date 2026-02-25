# Etabli

Personal dev environment for AI-assisted parallel workflows with Neovim, tmux, Ghostty and Pi Coding Agent. Includes a keyboard-driven tiling WM setup for macOS.

Inspired by practical agentic coding workflows and parallel worktree execution.

## Quick Start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

The installer symlinks all configs to the repo, so edits here are reflected everywhere.

Works on **macOS** and **Linux** (Ubuntu/Debian).

### Pi config & secrets (important)

Pi is configured via repo files, but secrets are loaded from your local environment at runtime.

- `pi/models.json`, `pi/settings.json`, and `pi/agent/settings.json` are tracked templates.
- API keys (ex: `MISTRAL_API_KEY`, etc.) are expected via env vars.
- `auth.json` (or any local auth file) is intentionally **not** tracked.

Recommended local pattern:
- Export credentials in your shell profile (`.zshrc` / `.bashrc`) or a local secret file loaded outside the repo.
- Keep `.env*`, token files, and private keys out of git (they are already in `.gitignore` by default).


## What's Inside

```
pi/                         Pi Coding Agent config
  AGENTS.md                 Project instructions
  models.json               Custom model/provider config
  settings.json             Pi user settings
  extensions/               Pi extensions (filter-output, uv, nightshift, ship)
  skills/                   Pi skills (plan, plan-review, verify, review, coordinator, worker)
  themes/                   Pi themes

ghostty/config              Ghostty terminal (Catppuccin Mocha, JetBrains Mono)

nvim/                       Neovim config (LazyVim)
  lua/config/               Options, keymaps, autocmds
  lua/plugins/core/         Theme, LSP, git, editor, AI, lualine, explorer
  lua/plugins/lang/         TypeScript, Rust, Ember
  lua/plugins/extras/       Hardtime, Precognition

yabai/yabairc               BSP tiling WM (zero animation, macOS)
skhd/skhdrc                 Keyboard-driven tiling keybindings
sketchybar/                 Status bar (Catppuccin Mocha, workspaces, system info)
borders/bordersrc           JankyBorders (cyan-green gradient)
starship/starship.toml      Starship prompt (oh-my-zsh inspired, git-aware)

scripts/
  install.sh                Full setup (deps, nvim, tmux, fonts, tiling WM, scripts)
  cw                        Worktree manager (tmux + optional pi launch)
  cw-clean                  Clean merged worktrees
  nightshift                Overnight batch runner
  agent-scorecard           Weekly agentic metrics report
  agent-fanout              Spawn coordinator/worker sessions from a tasks file
  dev-spawn                 Launch local + VPS tmux sessions
  macos-optimize.sh         Aggressive macOS perf optimization
  tiling-toggle.sh          Toggle tiling stack on/off
  yabai-sudoers-update.sh   Regenerate yabai sudoers after brew upgrade
  tmux-clipboard.sh         Cross-platform clipboard (pbcopy/wl-copy/xclip/OSC52)

skills/                     Shared skills (React best practices, Web design guidelines)

tmux.conf                   tmux config (Catppuccin Mocha, vim keys, fast nav)
```

## Workflow

The engineer supervises parallel sessions, each in its own git worktree:

```
/skill:plan  ->  /skill:plan-review  ->  implement  ->  /skill:verify  ->  /skill:review  ->  commit
```

See [docs/agentic-flow.md](docs/agentic-flow.md) for the orchestrated `/ship`, scorecard, and coordinator/worker flow.

### Git Worktrees

```bash
# Create worktree + tmux window + launch pi
cw myproject auth feature        # -> feature/auth

# Create without launching pi
cw -n myproject bug42 fix        # -> fix/bug42

# Clean merged worktrees
cw-clean myproject
```

`PI_PROJECT_ROOT` defaults to `~/projects`.

### Slash Commands

| Command                 | What it does                               |
| ----------------------- | ------------------------------------------ |
| `/skill:plan <feature>` | Create PLAN.md with steps, risks, deps      |
| `/skill:plan-review`    | Challenge the plan before coding (assumptions, risks, edge cases) |
| `/skill:review`         | Final pre-commit review (risks, regressions, edge cases) |
| `/skill:verify`         | Run typecheck/tests/lint/build             |
| `/ship start --task`    | Orchestrate plan/review/verify flow        |
| `/ship finalize`        | Queue verify/review and prepare final decision |
| `/ship mark --result`   | Record `go` / `block` decision             |
| `/ship status`          | Show current run + weekly go/block summary |
| `/skill:coordinator`    | Run coordinator protocol for multi-worker flow |
| `/skill:worker`         | Run worker protocol for one scoped slice   |
| `/loop tests`           | Red-green-refactor testing loop            |
| `Ctrl+P`                | Switch model/provider quickly              |

### Ship (Orchestrated Flow)

```bash
/ship start --task "Implement X safely"  # queues plan + plan-review
# ... implement ...
/ship finalize                     # queues /skill:verify + /skill:review
/ship mark --result go --notes "ready to commit"
```

`/ship status` shows the active run and recent GO/BLOCK decisions.

### Night Shift

Prepare 1-3 tasks before leaving. The machine works overnight, commits and pushes (no PR, no merge).

```bash
nightshift init                  # Create tasks template
nightshift run --dry-run         # Preview
nightshift run --verify-only     # Execute + verify only (no commit/push)
nightshift run --require-verify  # Fail tasks without verify commands
nightshift run                   # Execute overnight
nightshift status                # Check results next morning
```

Tasks are Markdown blocks in `~/.local/state/nightshift/tasks.md`. Supports `codex` or `none` engines.
Each run also writes:
- `~/.local/state/nightshift/last-run-report.md`
- `~/.local/state/nightshift/last-run-report.json`
- `~/.local/state/nightshift/history.jsonl`

See [docs/nightshift.md](docs/nightshift.md) for details.

### Weekly Agentic Scorecard

```bash
agent-scorecard weekly --repo /path/to/repo
```

Generates a markdown report with Nightshift outcomes, Ship GO/BLOCK decisions, and commit activity.

### Coordinator / Workers Fanout

```bash
agent-fanout init
# edit ~/.local/state/pi-agentic/workers.md
agent-fanout run --tasks ~/.local/state/pi-agentic/workers.md
# optional: skip coordinator window
agent-fanout run --tasks ~/.local/state/pi-agentic/workers.md --no-coordinator
```

This creates one tmux worker window per task, launches Pi, starts `/ship` in each worker,
and auto-creates a coordinator window per repo (unless `--no-coordinator`).

### Dev Spawn

```bash
dev-spawn all                    # Local + VPS tmux sessions
dev-spawn local                  # Local only
dev-spawn vps                    # VPS only
```

## Keymaps

### tmux

| Shortcut         | Action                 |
| ---------------- | ---------------------- |
| `Prefix + 1..9`  | Jump to window         |
| `Prefix + h/j/k/l` | Navigate panes      |
| `Prefix + \|`    | Split vertical         |
| `Prefix + -`     | Split horizontal       |
| `Prefix + z`     | Zoom/unzoom pane       |
| `Prefix + Space` | Last session           |

Clipboard: copy-mode pipes through `tmux-clipboard.sh` (pbcopy > wl-copy > xclip > OSC52).

### Neovim

| Keymap         | Action                 |
| -------------- | ---------------------- |
| `<leader>cm`   | Open AGENTS.md         |
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

## Tiling WM (macOS)

Keyboard-driven tiling window management using Yabai + skhd, with SketchyBar and JankyBorders.

### Tools

| Tool | Role | Equivalent (Hyprland) |
| ---- | ---- | --------------------- |
| Yabai | BSP tiling WM | Hyprland |
| skhd | Hotkey daemon | Hyprland bindings |
| SketchyBar | Status bar | Waybar |
| JankyBorders | Window borders | Hyprland borders |
| Sol | App launcher | Walker |
| Starship | Shell prompt | Starship |

### Prerequisites

1. **Partially disable SIP** (required for yabai scripting addition):
   - Boot to Recovery Mode (hold Power on Apple Silicon)
   - Open Terminal and run: `csrutil enable --without fs --without debug --without nvram`
   - Reboot
2. **Create 5+ Mission Control Spaces** (System Settings > Desktop & Dock)
3. **Disable** "Automatically rearrange Spaces based on most recent use"
4. **Hide macOS menu bar** (System Settings > Control Center > Automatically hide and show the menu bar > Always)
5. **Configure Sol hotkey** to `alt+space` in Sol preferences

### Keybindings (skhd)

`alt` is the modifier key (equivalent to `SUPER` on Linux).

**Window management:**

| Shortcut | Action |
| -------- | ------ |
| `alt + w` | Close window |
| `alt + t` | Toggle float (center 50%) |
| `alt + f` | Toggle fullscreen |
| `alt + j` | Toggle split direction |

**Navigation:**

| Shortcut | Action |
| -------- | ------ |
| `alt + arrows` | Focus window direction |
| `shift + alt + arrows` | Swap windows |
| `alt + minus/equals` | Resize horizontal |
| `shift + alt + minus/equals` | Resize vertical |
| `shift + alt + 0` | Balance BSP tree |

**Workspaces:**

| Shortcut | Action |
| -------- | ------ |
| `alt + 1..9` | Focus workspace |
| `shift + alt + 1..9` | Move window to workspace |
| `alt + tab` | Next workspace |
| `shift + alt + tab` | Previous workspace |

**Apps:**

| Shortcut | Action |
| -------- | ------ |
| `cmd + return` | Open Ghostty |
| `cmd + space` | Open Sol (launcher) |

### Utility Scripts

```bash
tiling-toggle.sh           # Toggle tiling stack on/off
tiling-toggle.sh on        # Start yabai, skhd, sketchybar, borders
tiling-toggle.sh off       # Stop all tiling services

macos-optimize.sh apply    # Disable animations, services, clean RAM
macos-optimize.sh daemon   # RAM cleanup loop (every 5 min)
macos-optimize.sh reset    # Restore macOS defaults

yabai-sudoers-update.sh    # Run after brew upgrade yabai
```

### Troubleshooting

| Problem | Fix |
| ------- | --- |
| Yabai not tiling | Check SIP: `csrutil status`, run `yabai-sudoers-update.sh` |
| skhd keys not working | Check `skhd --start-service`, verify `macos-option-as-alt = true` in Ghostty |
| SketchyBar not showing | `brew services restart sketchybar` |
| Borders missing | `brew services restart borders` |
| Workspaces not switching | Create Mission Control spaces manually, disable auto-rearrange |
| Alt sends Unicode in terminal | Set `macos-option-as-alt = true` in Ghostty config |

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

# Scripts (cross-platform)
mkdir -p ~/.local/bin
for s in cw cw-clean nightshift agent-scorecard agent-fanout dev-spawn tmux-clipboard.sh; do
  ln -sf $(pwd)/scripts/$s ~/.local/bin/$s
done

# Pi Coding Agent
mkdir -p ~/.pi ~/.pi/agent/skills ~/.pi/agent/themes ~/.pi/agent/extensions
ln -sf $(pwd)/pi/AGENTS.md ~/.pi/agent/AGENTS.md
ln -sf $(pwd)/pi/models.json ~/.pi/agent/models.json
ln -sf $(pwd)/pi/settings.json ~/.pi/settings.json
ln -sf $(pwd)/pi/agent/settings.json ~/.pi/agent/settings.json
ln -sfn $(pwd)/pi/extensions ~/.pi/extensions
ln -sfn $(pwd)/pi/extensions ~/.pi/agent/extensions
ln -sfn $(pwd)/pi/themes ~/.pi/themes
for s in plan plan-review verify review coordinator worker; do
  ln -sfn $(pwd)/pi/skills/$s ~/.pi/agent/skills/$s
done
ln -sf $(pwd)/pi/themes/catppuccin-mocha.json ~/.pi/agent/themes/catppuccin-mocha.json

# macOS-only scripts
for s in macos-optimize.sh tiling-toggle.sh yabai-sudoers-update.sh; do
  ln -sf $(pwd)/scripts/$s ~/.local/bin/$s
done

# Tiling WM (macOS only)
mkdir -p ~/.config/yabai ~/.config/skhd ~/.config/borders
ln -sf $(pwd)/yabai/yabairc ~/.config/yabai/yabairc
ln -sf $(pwd)/skhd/skhdrc ~/.config/skhd/skhdrc
ln -sfn $(pwd)/sketchybar ~/.config/sketchybar
ln -sf $(pwd)/borders/bordersrc ~/.config/borders/bordersrc
ln -sf $(pwd)/starship/starship.toml ~/.config/starship.toml

# Font (macOS)
brew install --cask font-jetbrains-mono-nerd-font
```

## Theme

Catppuccin Mocha everywhere: Neovim, tmux, Ghostty, SketchyBar, JankyBorders. Font: JetBrains Mono Nerd Font.
