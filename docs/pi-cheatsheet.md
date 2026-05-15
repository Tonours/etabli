# Pi Coding Agent Cheatsheet

## Start

```bash
npm i -g @mariozechner/pi-coding-agent
pi
```

Auth:

```bash
/login
# or provider env vars
export ANTHROPIC_API_KEY=...
```

## Interactive commands

- `/model`: switch model
- `/settings`: edit settings
- `/new`: start session
- `/resume`: resume session
- `/tree`: browse session tree
- `/compact`: compact context
- `/reload`: reload extensions, skills, prompts
- `/name <name>`: name session
- `/export [file]`: export HTML
- `/quit`: exit

## Keybindings

- `Ctrl+L`: model/provider picker
- `Ctrl+P` / `Shift+Ctrl+P`: cycle models
- `Shift+Tab`: thinking level
- `Esc`: interrupt
- `Esc` twice: open `/tree`
- `Ctrl+O`: toggle tool output
- `Ctrl+T`: toggle thinking output
- `Shift+Enter`: newline
- `Ctrl+V`: paste image

## Inputs

- `@file`: attach file
- `!command`: run command and send output
- `!!command`: run command without sending output

## Etabli workflow

Canonical contract: `workflow/spec.md`.

Pi commands:

```text
/skill:plan-loop <task>
/skill:plan-implement <task>
/skill:implement
/skill:review
/skill:caveman [lite|full|ultra]
/skill:ui
```

Rules:

- use one artifact: `PLAN.md`
- implement only from `Status: READY`
- run focused checks
- review before commit

## Local checks

From repo root:

```bash
./scripts/test-ops-local.sh
cd pi && bun test ./extensions/__tests__/*.test.ts
cd pi && bun run test:workflow
```

## Config files

Repo source:

- `pi/settings.json`
- `pi/models.json`
- `pi/agent/settings.json`
- `pi/extensions/`
- `pi/skills/`
- `pi/themes/`

Installed/local:

- `~/.pi/settings.json`
- `~/.pi/agent/settings.json`
- `~/.pi/agent/models.json`
- `~/.pi/agent/auth.json`
- `~/.pi/agent/{extensions,skills,themes}/`

Default extensions:

- `rtk.ts`
- `filter-output.ts`
- `block-google-providers.ts`

Curated packages:

- `pi-hooks` for LSP
- `mitsupi` for `github` and `commit`
- `brave-search`
- `pi-interview`
- `pi-autoresearch`
- `glimpseui` without standalone skill

## tmux note

`tmux.conf` enables `extended-keys` and `extended-keys-format csi-u` so Pi receives modified Enter keys distinctly.

After changing that block:

```bash
tmux kill-server && tmux
```
