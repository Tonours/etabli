# Etabli

Personal dev environment for AI-assisted parallel workflows with VS Code, tmux, iTerm2 and Pi Coding Agent. Includes a keyboard-driven tiling WM setup for macOS.

Inspired by practical agentic coding workflows and parallel worktree execution.

## Inspiration & Credits

Parts of the multi-agent UX direction (team/chain dashboards, widget-first orchestration patterns) are inspired by:
- [disler/pi-vs-claude-code](https://github.com/disler/pi-vs-claude-code) by **@disler**

## Quick Start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

The installer symlinks all configs to the repo, so edits here are reflected everywhere.

Works on **macOS** and **Linux** (Ubuntu/Debian).

For Linux, install VS Code separately and make sure the `code` CLI is available if you want the repo installer to link settings and install extensions automatically.

### Pi config & secrets (important)

Pi is configured via repo-tracked source files, and `scripts/install.sh` symlinks them into the active Pi config under `~/.pi/`.

- `pi/models.json` is synced to `~/.pi/agent/models.json`.
- `pi/settings.json` and `pi/agent/settings.json` are the tracked source files for the installed Pi config.
- API keys (ex: `MISTRAL_API_KEY`, etc.) are expected via env vars.
- `auth.json` (or any local auth file) is intentionally **not** tracked.
- Default package set includes:
  - `npm:checkpoint` (session checkpoints)
  - `npm:pi-hooks` (LSP tool support)
  - `npm:pi-notify` (desktop notifications)
  - `git:github.com/badlogic/pi-skills` with `brave-search` + `youtube-transcript`
- Repo-local shared Pi skills also linked by the installer when absent:
  - `skills/vercel-react-best-practices`
  - `skills/web-design-guidelines`
- Default local Pi theme: `catppuccin-mocha`

Recommended local pattern:
- Export credentials in your shell profile (`.zshrc` / `.bashrc`) or a local secret file loaded outside the repo.
- Keep `.env*`, token files, and private keys out of git (they are already in `.gitignore` by default).


## What's Inside

```
pi/                         Pi Coding Agent config
  AGENTS.md                 Project instructions
  models.json               Custom model/provider config
  settings.json             Pi user settings
  extensions/               Pi extensions (safety, UI, image input, RTK, subagents, tilldone)
  skills/                   Pi skills (plan, plan-review, implement, plan-loop, plan-implement, review)
  themes/                   Pi themes

claude/
  commands/                 Tracked Claude Code command sources (installed into ~/.claude/commands/)
  README.md                 Claude Code workflow notes

iterm2/etabli.json          iTerm2 dynamic profile (font/colors, Option sends Esc+)

vscode/                     VS Code user config
  settings.json             Theme, font, formatter, language defaults
  keybindings.json          User-level keybindings tracked in the repo
  extensions.txt            Recommended extensions installed by the setup script

yabai/yabairc               BSP tiling WM (zero animation, macOS)
skhd/skhdrc                 Keyboard-driven tiling keybindings
sketchybar/                 Old status bar config kept as inactive backup
starship/starship.toml      Starship prompt (oh-my-zsh inspired, git-aware)

scripts/
  install.sh                Full setup (deps, VS Code, tmux, fonts, tiling WM, scripts)
  cw                        Worktree manager (worktree + tmux + optional agent)
  cw-clean                  Inspect/clean merged or gone worktrees (dry-run by default)
  dev-spawn                 Launch local + VPS tmux sessions
  iterm2-tmux.sh            iTerm2 bootstrap that auto-attaches tmux
  open-iterm2.sh            Open iTerm2 with the bundled profile + tmux bootstrap
  macos-disk-clean.sh       Safe macOS disk cleanup (report, safe, deep)
  macos-optimize.sh         Safe macOS responsiveness tuning for tiling
  mem-status                macOS memory/swap headroom helper (one-shot or watch)
  tiling-toggle.sh          Toggle tiling stack on/off
  yabai-space-local.sh      Local 1..5 workspace helper per display
  yabai-sudoers-update.sh   Regenerate yabai sudoers after brew upgrade
  tmux-clipboard.sh         Cross-platform clipboard (pbcopy/wl-copy/xclip/OSC52)

skills/                     Shared skills (React best practices, Web design guidelines)
PLAN_TEMPLATE.md            Canonical template used to create and revise PLAN.md

tmux.conf                   tmux config (Catppuccin Mocha, vi copy mode, fast nav)
```

## Workflow

```
problem  ->  plan  ->  PLAN.md (DRAFT)  ->  plan-review  ->  PLAN.md (CHALLENGED/READY)  ->  implement
```

`PLAN.md` is the single pre-implementation artifact across Pi and Claude Code. `PLAN_TEMPLATE.md` defines the structure, and `plan-review` revises `PLAN.md` in place instead of creating a separate `REVIEW.md`.

Optional interactive shortcut: `plan-loop` chains plan creation and plan critique in one flow, then stops at `CHALLENGED` or `READY`.

Direct continuation step: `implement` executes an existing `READY` `PLAN.md` without rerunning planning.

Optional one-shot shortcut: `plan-implement` runs `plan-loop`, stops if `PLAN.md` is still `CHALLENGED`, and implements only from `READY`.

### Git Worktrees

```bash
# Preferred: explicit subcommands
cw new myproject auth feature
cw open myproject fix/auth
cw ls myproject
cw attach myproject fix/auth

# Merge and remove a single worktree (both dry-run by default)
cw merge myproject fix/auth
cw merge myproject fix/auth --yes
cw rm myproject fix/auth
cw rm myproject fix/auth --yes

# Thin picker UI via fzf / fzf-tmux
cw pick myproject

# Backward-compatible alias during migration
cw myproject auth feature

# Batch cleanup stays in cw-clean
cw-clean myproject
cw-clean myproject --yes
```

`PI_PROJECT_ROOT` defaults to `~/projects`.
`cw` now creates worktrees under the current project when you run it from inside that repo, in `./.worktrees/<prefix>-<task>`.
If you run it elsewhere, it uses `"$PWD/.worktrees/<repo>/<prefix>-<task>"`.
`CW_WORKTREE_ROOT` can override that base directory explicitly.
`CW_DEFAULT_AGENT` defaults to `pi` and can be overridden per call with `--agent`.
Selectors for `open|attach|merge|rm` accept an exact branch name, a worktree path, or a unique worktree directory name.

`cw` command surface:

| Command | Role |
| ------- | ---- |
| `cw new` | Create/reuse a worktree, ensure a tmux target, optionally launch an agent |
| `cw open` | Reopen an existing worktree in tmux without changing git state |
| `cw ls` | Show registered worktrees, dirty state, and tmux targets |
| `cw attach` | Attach to an existing tmux target for a worktree |
| `cw merge` | Merge one secondary worktree branch into the base branch from the main repo worktree |
| `cw rm` | Remove one secondary worktree with explicit dirty/tmux checks |
| `cw pick` | Thin UI wrapper on top of `fzf` / `fzf-tmux` |
| `cw-clean` | Batch cleanup for merged, gone, or stale worktrees |

Notes:
- there is no separate `cw ui` command; the lightweight UI is `cw pick`
- `cw merge` and `cw rm` are dry-run by default; add `--yes` to apply
- `cw-clean` stays the batch cleanup tool; `cw rm` handles one worktree at a time

### Pi Commands

| Command                      | What it does |
| ---------------------------- | ------------ |
| `/skill:plan <feature>`      | Create `PLAN.md` from `PLAN_TEMPLATE.md` with status `DRAFT` |
| `/skill:plan-review`         | Stress-test and update `PLAN.md`, then mark it `CHALLENGED` or `READY` |
| `/skill:implement`           | Implement the existing `READY` `PLAN.md` without rerunning planning |
| `/skill:plan-loop <feature>` | Chain plan creation and plan critique until `PLAN.md` lands in `CHALLENGED` or `READY` |
| `/skill:plan-implement [feature]` | Run `plan-loop`, stop on `CHALLENGED`, implement only from `READY` |
| `/skill:review`              | Final pre-commit review (risks, regressions, edge cases) |
| `/review [target]`           | Focused runtime review flow for uncommitted changes, a branch diff, or a commit |
| `/handoff [path]`            | Write a continuation handoff document (`.pi/handoff.md` by default) |
| `/handoff-implement [path]`  | Write a plan-aware implementation handoff (`.pi/handoff-implement.md` by default) |
| `/scout <task>`              | Spawn a read-only reconnaissance subagent |
| `/worker <task>`             | Spawn an implementation subagent that can edit code |
| `/reviewer <task>`           | Spawn a read-only review subagent |
| `/loop tests`                | Red-green-refactor testing loop |
| `Ctrl+R`                     | Launch runtime code review shortcut (mitsupi) |
| `Ctrl+L`                     | Open model/provider selector |
| `Ctrl+P` / `Shift+Ctrl+P`    | Cycle models |

Notes:
- `/skill:*` commands come from repo-tracked Pi skills under `pi/skills/`.
- `/review`, `/handoff`, `/handoff-implement`, `/scout`, `/worker`, and `/reviewer` are runtime/extension commands loaded by Pi.

### Agentic Development Flow

Preferred loop on this project:

1. **Learn**
   - Use `scout` or read the code directly to gather context.
2. **Plan**
   - Create or refresh `PLAN.md` with `/skill:plan`, `/skill:plan-review`, or `/skill:plan-loop`.
   - Continue with `/skill:implement` only from `READY`.
3. **Implement**
   - Use `/skill:implement` in the main session or delegate a bounded task to `/worker <task>`.
4. **Review**
   - Run `/review` or `/skill:review` before calling the change done.
   - Use `/reviewer <task>` when a separate review pass is useful.
5. **Handoff**
   - Run `/handoff` for generic session continuation.
   - Run `/handoff-implement` when pausing active implementation from a `READY` plan.

Role summary:

| Role | Mode | Typical use |
| ---- | ---- | ----------- |
| `scout` | read-only | Map files, conventions, risks before planning or implementation |
| `worker` | read/write + todo + LSP | Implement a bounded task, verify it, and report changes |
| `reviewer` | read-only | Check correctness, regressions, safety, and missing validation |

Notes:
- `scout` and `reviewer` stay read-only.
- `worker` is the only implementation subagent and should stay tightly scoped.
- `worker` can use persistent `todo` tasks when relevant (`claim` → `get` → `append/update` → `close`) and use `lsp` when available.
- `cw` remains the worktree/tmux entrypoint; agent roles sit on top of that workflow, not beside it.

### Claude Commands

| Command                  | What it does |
| ------------------------ | ------------ |
| `/plan <feature>`        | Create `PLAN.md` from `PLAN_TEMPLATE.md` with status `DRAFT` |
| `/plan-review`           | Stress-test and update `PLAN.md`, then mark it `CHALLENGED` or `READY` |
| `/implement`             | Implement the existing `READY` `PLAN.md` without rerunning planning |
| `/plan-loop <feature>`   | Chain plan creation and plan critique until `PLAN.md` lands in `CHALLENGED` or `READY` |
| `/plan-implement [feature]` | Run `plan-loop`, stop on `CHALLENGED`, implement only from `READY` |
| `/review [target]`       | Review uncommitted changes, a branch diff, or a specific commit |
| `/handoff [path]`        | Write a generic continuation handoff |
| `/handoff-implement [path]` | Write a plan-aware implementation continuation handoff |

Claude note: the tracked source file is `claude/commands/plan-create.md`, but installation maps it to `/plan`.

### Pi Extensions

Local Pi extensions kept in this repo:
- `rtk.ts` rewrites shell commands through `rtk rewrite` when the `rtk` binary is installed.
  The install script installs `rtk` from [rtk-ai/rtk](https://github.com/rtk-ai/rtk).
- `subagent.ts` runs background Pi sub-agents with `/sub`, `/scout`, `/worker`, `/reviewer`, `/subcont`, `/subrm`, `/subclear`. The worker preset explicitly loads `todo` (mitsupi) and `lsp` (pi-hooks) extensions for implementation tasks.
- `/review` is provided by the loaded mitsupi review extension; project guidance and shared rubric stay aligned with that runtime command.
- `handoff.ts` adds `/handoff` and `/handoff-implement` to generate continuation docs in `.pi/`.
- `runtime-status.ts` writes lightweight runtime status to `~/.pi/status/*.json` and updates terminal title/footer.
- `tilldone.ts` enforces an explicit task list before tool usage with the `tilldone` tool and `/tilldone`.

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
| `Shift + Enter`  | Dedicated newline sequence forwarded to TUIs through tmux |

Clipboard: copy-mode pipes through `tmux-clipboard.sh` (pbcopy > wl-copy > xclip > OSC52).

### VS Code

| Default | Value / Role |
| ------- | ------------- |
| Theme | Catppuccin Mocha |
| Font | JetBrainsMono Nerd Font |
| Font size | 18 |
| Ruler | 100 columns |
| Wrap | Off |
| Copilot accept | `Alt+l` |

Recommended extensions installed by `scripts/install.sh` when the `code` CLI is available:

- Catppuccin theme + icons
- GitHub Copilot + Copilot Chat
- GitLens + Bookmarks
- Biome, ESLint, Prettier
- Tailwind CSS, Astro, Rust Analyzer, Even Better TOML, Ember + Glint
- Color preview + Todo Tree

Formatter split:
- Biome = default formatter for JS/TS/CSS/JSON/GraphQL
- Prettier = Astro + Handlebars
- ESLint = diagnostics first, no formatter role by default

The setup script also installs matching CLI tools globally (`typescript`, `prettier`, `eslint`, `@tailwindcss/language-server`) for shell/editor interoperability.

## Tiling WM (macOS)

Keyboard-driven tiling window management using Yabai + skhd.

### Tools

| Tool | Role | Equivalent (Hyprland) |
| ---- | ---- | --------------------- |
| Yabai | BSP tiling WM | Hyprland |
| skhd | Hotkey daemon | Hyprland bindings |
| Sol | App launcher | Walker |
| Starship | Shell prompt | Starship |

### Prerequisites

1. **Partially disable SIP** (required for yabai scripting addition):
   - Boot to Recovery Mode (hold Power on Apple Silicon)
   - Open Terminal and run: `csrutil enable --without fs --without debug --without nvram`
   - Reboot
2. **Run** `macos-optimize.sh apply` to strip most macOS UI animations, disable auto-rearrange, kill most Spaces swooshes/fades and enable separate Spaces per display
3. **Converge Spaces** with `yabai-space-local.sh ensure` if Mission Control still has the wrong count
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
| `alt + 1..5` | Focus workspace on focused display |
| `shift + alt + 1..5` | Move window to workspace on focused display |
| `alt + tab` | Next workspace on focused display |
| `shift + alt + tab` | Previous workspace on focused display |

**Apps:**

| Shortcut | Action |
| -------- | ------ |
| `alt + return` | Open iTerm2 |
| `cmd + space` | Open Sol (launcher) |

### Utility Scripts

```bash
tiling-toggle.sh           # Toggle tiling stack on/off
tiling-toggle.sh on        # Start yabai, skhd
tiling-toggle.sh off       # Stop all tiling services

macos-optimize.sh apply    # Strip most macOS UI animations, kill most Spaces swooshes/fades, lock Spaces behaviour, trim background services
macos-optimize.sh trim     # Quit known idle media/apps explicitly
macos-optimize.sh reset    # Restore reversible macOS defaults
macos-disk-clean.sh report # Show the main disk usage buckets
macos-disk-clean.sh safe --yes # Clean safe macOS/app caches, logs, trash
macos-disk-clean.sh deep --yes # Safe cleanup + rebuildable developer caches
mem-status                 # Show memory headroom, compression, swap
mem-status watch 1         # Refresh every second
yabai-space-local.sh ensure # Create missing spaces and prune empty extras down to 5/display

yabai-sudoers-update.sh    # Run after brew upgrade yabai
```

### Troubleshooting

| Problem | Fix |
| ------- | --- |
| Yabai not tiling | Check SIP: `csrutil status`, run `yabai-sudoers-update.sh` |
| skhd keys not working | Check `skhd --start-service`, then run `~/.local/bin/open-iterm2.sh` directly |
| Workspaces not switching | Run `macos-optimize.sh apply`, then `yabai-space-local.sh ensure` |
| Alt sends Unicode in terminal | Use the bundled `etabli` iTerm2 profile or set both Option keys to Esc+ |

## Manual Install

If you prefer to set things up yourself:

```bash
# VS Code user config
VSCODE_USER_DIR="$HOME/.config/Code/User"
[ "$(uname)" = "Darwin" ] && VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_USER_DIR"
ln -sf "$(pwd)/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
ln -sf "$(pwd)/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
VSCODE_BIN=""
if command -v code >/dev/null; then
  VSCODE_BIN="$(command -v code)"
elif [ "$(uname)" = "Darwin" ] && [ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
  VSCODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi
if [ -n "$VSCODE_BIN" ]; then
  while IFS= read -r extension; do
    "$VSCODE_BIN" --install-extension "$extension"
  done < "$(pwd)/vscode/extensions.txt"
fi

# tmux
ln -sf $(pwd)/tmux.conf ~/.tmux.conf

# iTerm2 (macOS)
mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
ln -sf $(pwd)/iterm2/etabli.json "$HOME/Library/Application Support/iTerm2/DynamicProfiles/etabli.json"

# Scripts (cross-platform)
mkdir -p ~/.local/bin
for s in cw cw-clean dev-spawn iterm2-tmux.sh tmux-clipboard.sh; do
  ln -sf $(pwd)/scripts/$s ~/.local/bin/$s
done

# Scripts (macOS launcher)
ln -sf $(pwd)/scripts/open-iterm2.sh ~/.local/bin/open-iterm2.sh

# Pi Coding Agent
mkdir -p ~/.pi ~/.pi/agent/skills ~/.pi/agent/themes ~/.pi/agent/extensions
ln -sf $(pwd)/pi/AGENTS.md ~/.pi/agent/AGENTS.md
ln -sf $(pwd)/pi/damage-control-rules.json ~/.pi/damage-control-rules.json
ln -sf $(pwd)/pi/models.json ~/.pi/agent/models.json
ln -sf $(pwd)/pi/settings.json ~/.pi/settings.json
ln -sf $(pwd)/pi/agent/settings.json ~/.pi/agent/settings.json
ln -sfn $(pwd)/pi/extensions ~/.pi/agent/extensions
ln -sfn $(pwd)/pi/themes ~/.pi/themes
rm -f ~/.pi/agent/skills/verify
for s in $(find "$(pwd)/pi/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;); do
  ln -sfn "$(pwd)/pi/skills/$s" ~/.pi/agent/skills/$s
done
for s in vercel-react-best-practices web-design-guidelines; do
  ln -sfn $(pwd)/skills/$s ~/.pi/agent/skills/$s
done
ln -sf $(pwd)/pi/themes/catppuccin-mocha.json ~/.pi/agent/themes/catppuccin-mocha.json
ln -sfn ~/.pi/npm/node_modules $(pwd)/pi/extensions/node_modules

# Claude Code
mkdir -p ~/.claude/commands
rm -f ~/.claude/commands/verify.md
ln -sf $(pwd)/claude/commands/plan-create.md ~/.claude/commands/plan.md
ln -sf $(pwd)/claude/commands/plan-review.md ~/.claude/commands/plan-review.md
ln -sf $(pwd)/claude/commands/implement.md ~/.claude/commands/implement.md
ln -sf $(pwd)/claude/commands/plan-loop.md ~/.claude/commands/plan-loop.md
ln -sf $(pwd)/claude/commands/plan-implement.md ~/.claude/commands/plan-implement.md
ln -sf $(pwd)/claude/commands/review.md ~/.claude/commands/review.md
ln -sf $(pwd)/claude/commands/handoff.md ~/.claude/commands/handoff.md
ln -sf $(pwd)/claude/commands/handoff-implement.md ~/.claude/commands/handoff-implement.md
ln -sf $(pwd)/claude/review-rubric.md ~/.claude/review-rubric.md
ln -sf $(pwd)/claude/handoff-template.md ~/.claude/handoff-template.md

# macOS-only scripts
for s in macos-optimize.sh macos-disk-clean.sh mem-status tiling-toggle.sh yabai-space-local.sh yabai-sudoers-update.sh; do
  ln -sf $(pwd)/scripts/$s ~/.local/bin/$s
done

# Tiling WM (macOS only)
mkdir -p ~/.config/yabai ~/.config/skhd
ln -sf $(pwd)/yabai/yabairc ~/.config/yabai/yabairc
ln -sf $(pwd)/skhd/skhdrc ~/.config/skhd/skhdrc
ln -sf $(pwd)/starship/starship.toml ~/.config/starship.toml

# Terminal + font (macOS)
brew install --cask iterm2 visual-studio-code font-jetbrains-mono-nerd-font
```

## Theme

Core editor stack stays close to Catppuccin Mocha, while iTerm2 keeps a colder blue accent palette. Font: JetBrains Mono Nerd Font, editor size 18.
