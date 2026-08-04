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
# Z.AI / GLM coding plan
export ZAI_API_KEY=...
```

## Thinking level

Default is high. Override anytime with `Shift+Tab`.

## Network latency (z.ai / model APIs)

Etabli prefers **IPv4-first DNS for Node/Pi**. On this network, `api.z.ai` often
resolves IPv6 first under Node's default `verbatim` order; cold TLS then sits
around ~370–575 ms vs ~55–95 ms on IPv4. Cloudflare-backed hosts (x.ai, kimi)
are already fast; the mainland `open.bigmodel.cn` path is worse from EU and is
**not** used by Pi's coding endpoint (`https://api.z.ai/api/coding/paas/v4`).

If `pi/extensions/prefer-ipv4-dns.ts` is loaded, it applies
`dns.setDefaultResultOrder("ipv4first")` at load. The quasi-vanilla profile
does not ship it by default; set the order in your shell or Node env if needed.

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

See `workflow/spec.md` for the full contract.

Task tracking uses `@tintinweb/pi-tasks`. Subagents are disabled in the
quasi-vanilla profile (`pi/agent/subagents.json` stubs concurrency to 0).

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

## Quasi-vanilla packages

Tracked in `pi/agent/settings.json`:

- `npm:mitsupi` — skills `github`, `commit`
- `local:etabli-workflow` — workflow skills only (no extensions)
- `git:github.com/badlogic/pi-skills` — `brave-search`
- `npm:@tintinweb/pi-tasks@0.7.1` — task tracking

Subagents, MCP, pi-hooks, and glimpseui are out of the default profile.

## tmux note

`tmux.conf` enables `extended-keys` and `extended-keys-format csi-u` so Pi receives modified Enter keys distinctly.

After changing that block:

```bash
tmux kill-server && tmux
```
