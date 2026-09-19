# Etabli

Etabli is a personal source tree for local agent workflows and terminal
configuration. The shared contract lives in `workflow/`; Pi and Claude expose
thin runtime adapters, while the skill catalog feeds the other local harness
surfaces (shared `~/.agents`, Codex, Devin). The full link layout and the
`shared`/`work`/`personal` scope system live in
[`docs/symlink-layout.md`](docs/symlink-layout.md).

## Install

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

The installer uses the existing Node.js runtime, preferring `asdf` when it is
available. It does not install Node or `nvm`. Pi comes from
`@earendil-works/pi-coding-agent`.

Optional terminal diff tooling is `hunkdiff`; use it from the CLI or a tmux
pane, not from inside Neovim.

## Managed surfaces

| Path | Purpose |
| --- | --- |
| `workflow/` | Shared routing, plans, guards, loops, and validation contracts |
| `workflow-scaffold/` | Templates `scripts/deploy-workflow` copies into scaffolded projects |
| `pi/` | Pi settings, extensions, agents, skills, and themes |
| `claude/` | Claude commands, agents, hooks, and scoped skills |
| `vendor/` | Vendored skill sources and the catalog that controls their scope |
| `nvim/`, `ghostty/`, `tmux.conf` | Editor and terminal configuration |
| `herdr/` | Herdr configuration, layouts, plugins, and multihost tooling |
| `mcp/` | Sanitized MCP inventory template; no live credentials |
| `scripts/`, `tests/` | Install, deploy, validation, and regression checks |
| `skills-lock.json` | Integrity lock for the managed skill tree |
| `docs/adr/` | Architecture decisions; validate with `node scripts/validate-adrs .` |

## Workflow

Projects containing `workflow/spec.md` activate the workflow ambiently.

1. Small requests can be handled directly.
2. Broad or risky work uses the root `PLAN.md` as its single active plan.
3. Only a `READY` plan authorizes implementation on that route.
4. Push, deploy, secrets, and publication still need explicit authority.

Pi and Claude share the same workflow source through managed links. A change in
this repository is the change every linked runtime reads.

One writer at a time is a protocol, not an OS lock. Long-running routes keep
their rules in [`workflow/skills/self-improvement-loop.md`](workflow/skills/self-improvement-loop.md),
[`workflow/skills/ambitious-project-loop.md`](workflow/skills/ambitious-project-loop.md),
and [`workflow/skills/pr-maintenance-loop.md`](workflow/skills/pr-maintenance-loop.md).

## Useful commands

```bash
# Preview or apply managed links
scripts/deploy-agent-workflow --dry-run
scripts/deploy-agent-workflow --apply

# Check links and run the core repository checks
scripts/check-fix-symlinks.sh
scripts/verify-agentic-infra core

# Verify the Pi skill tree
cd pi && bun run verify:skills
```

The public GitHub repository runs `agentic-infra` on `ubuntu-latest`. Private
repositories use the configured self-hosted labels instead. Check a live run
with `gh run list --workflow agentic-infra.yml`.

## Documentation

Start with [`docs/README.md`](docs/README.md). It separates active references
from decision and evaluation history. The fast path is
`workflow/agent-quick-card.md`, followed by `workflow/contract-details.md` when
you need the full command rules.

## Security

Keep credentials, OAuth material, cookies, session state, and live runtime
configuration outside this repository. Tracked templates use placeholders and
the project `.mcp.json` intentionally has no servers. See
[`SECURITY.md`](SECURITY.md) and [`docs/mcp-strategy.md`](docs/mcp-strategy.md)
for the boundary.
