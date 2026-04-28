# Pi Coding Agent - Cheatsheet

## Installation & Startup

```bash
npm i -g @mariozechner/pi-coding-agent
pi
```

Authentication:

```bash
/login
# or
export ANTHROPIC_API_KEY=...
pi
```

## Useful Interactive Commands

- `/model`: switch model
- `/settings`: edit settings
- `/new`: start a new session
- `/resume`: resume a session
- `/tree`: browse session history as a tree
- `/compact`: compact context
- `/reload`: reload extensions, skills, and prompts
- `/name <name>`: name the session
- `/export [file]`: export HTML
- `/share`: generate a shareable link
- `/quit`: exit

## Essential Keybindings

- `Ctrl+L`: model/provider picker
- `Ctrl+P` / `Shift+Ctrl+P`: cycle models
- `Shift+Tab`: thinking level
- `Esc`: interrupt
- `Esc` twice: open `/tree`
- `Ctrl+O`: toggle tool output
- `Ctrl+T`: toggle thinking output

## Power-User Inputs

- `@file`: inject a file
- `!command`: run bash and send output to the model
- `!!command`: run bash without sending output
- `Shift+Enter`: insert a newline
- `Ctrl+V`: paste an image

## tmux

- Pi expects distinct modified key sequences for `Enter`, `Shift+Enter`, and `Ctrl+Enter`.
- `tmux.conf` enables `extended-keys` with `extended-keys-format csi-u`.
- After changing this block, fully restart tmux: `tmux kill-server && tmux`.

## Canonical Repo Contract

- workflow: `workflow/spec.md`
- statuses: `workflow/statuses.md`
- review: `workflow/review-rubric.md`
- profiles: `profiles/README.md`
- profiles guide: `docs/profiles.md`
- project memory: `memory/projects/README.md`

## Useful Shortcuts In This Repo

```bash
/skill:plan-loop <feature>
/skill:plan-implement <feature>
/skill:implement
/skill:caveman [lite|full|ultra]
/skill:ui
/review [uncommitted|branch <base>|commit <sha>]

git status --short
git log --oneline -3
PLAN.md
```

Repo notes:

- the recommended workflow starts from the repo root or current working directory
- keep focus on `PLAN.md`, review, targeted validation, and manual QA
- the default Pi config is intentionally small
- `rtk` stays enabled to reduce shell noise and token cost

## Local Workflow Verification

From the repo root:

```bash
./scripts/test-ops-local.sh
```

Useful tests under `pi/`:

```bash
bun test ./extensions/__tests__/*.test.ts
bun run test:workflow
bun run test:workflow-coverage
```

## Neovim Diff Review Shortcuts

Actions on the current hunk:

- `<leader>ri`: open the Git review inbox
- `<leader>rh`: preview the current hunk
- `<leader>ra`: annotate the current hunk
- `<leader>rs`: choose a status (`new`, `accepted`, `needs-rework`, `question`, `ignore`)
- `<leader>rA`: accept the current hunk directly
- `<leader>rc` / `<leader>rC`: launch Claude with a `revise` / `explain` prompt
- `<leader>rp` / `<leader>rP`: launch Pi with a `revise` / `explain` prompt
- `<leader>rbc` / `<leader>rbp`: prepare a `needs-rework` batch for Claude / Pi

## Auto-Validation

Automatic checks:

- `PLAN.md` presence
- `PLAN.md` status
- working tree Git
- conflict markers
- TypeScript compilation for maintained surfaces
- unexpected large files

## Recommended Flow In This Repo

1. Read directly to understand the area being changed.
2. Run `/skill:plan-loop` until `PLAN.md` is `READY`, or `/skill:plan-implement` for the full planning-to-implementation flow.
3. Run `/skill:implement` if a `READY` `PLAN.md` already exists.
4. Run `/review` or `/skill:review` for final verification.

The repo Pi runtime stays intentionally small:

- no subagents
- no TillDone
- no local Pi handoff
- no separate `plan` or `plan-review`

## Important Configuration Files

- Repo source: `pi/settings.json`, `pi/models.json`, `pi/agent/settings.json`
- Repo source: `pi/{extensions,skills,themes}/`
- Installed: `~/.pi/settings.json`, `~/.pi/agent/settings.json` (local, not symlinked to the repo)
- Installed: `~/.pi/agent/models.json`, `~/.pi/agent/auth.json`, `~/.pi/agent/keybindings.json`
- Installed: `~/.pi/agent/{extensions,skills,prompts,themes}/`
- Default extensions: `rtk.ts`, `filter-output.ts`, `block-google-providers.ts`
- `damage-control` is disabled by default.
- Context: `AGENTS.md`, `pi/AGENTS.md`, `claude/README.md`
