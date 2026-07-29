# Pi Coding Agent Cheatsheet

Workflow map (routes, PLAN, loops): [`docs/workflow-guide.md`](workflow-guide.md).
Agent one-pager: `workflow/agent-quick-card.md`.

## Start

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
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
/skill:plan-loop <task>       # create/review PLAN.md, stop at READY or CHALLENGED
/skill:plan-implement <task>  # plan, then implement once READY
/skill:adversary              # adversarial review of PLAN.md before implementation
/skill:implement              # implement an existing READY plan
/skill:review                 # review current diff
/skill:verify                 # verify checks/claims without editing
/skill:bug-check              # analyze a Linear bug root cause without editing
/skill:pr-review              # review a GitHub PR through gh
/skill:caveman [lite|full|ultra]
```

Rules:

- use one artifact: `PLAN.md`
- implement only from `Status: READY`
- run an adversary pass before implementation
- run focused checks
- review before commit

See `workflow/spec.md` for the
full contract.

For long-running orchestration and subagent delegation rules, use
`workflow/skills/orchestration.md`. Prefer structured Task* state when Pi
exposes it; treat TaskList text parsing as a fallback.

`TaskExecute` needs `@tintinweb/pi-subagents` loaded with `@tintinweb/pi-tasks`
so Pi can use `subagents:rpc:ping`, `subagents:rpc:spawn`, and
`subagents:rpc:stop`. The `npm:pi-subagents` package exposes a standalone
subagent tool, but it does not provide the Task* tracking RPC protocol.

## Local checks

From repo root:

```bash
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
- `glimpseui` without standalone skill

## tmux note

`tmux.conf` enables `extended-keys` and `extended-keys-format csi-u` so Pi receives modified Enter keys distinctly.

After changing that block:

```bash
tmux kill-server && tmux
```
