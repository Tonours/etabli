# Etabli

One workflow contract for every local coding agent. `workflow/` holds the
rules; Pi and Claude read them through thin adapters, and the skill catalog
also feeds the shared `~/.agents`, Codex and Devin surfaces.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh                     # agent workflow
scripts/deploy-agent-workflow --apply    # managed links; omit --apply to preview
scripts/claude-hooks-merge --dry-run     # review, then run without --dry-run
scripts/verify-agentic-infra core        # every check should PASS
```

- The Claude hooks are merged into your live `settings.json` rather than linked,
  because that file can hold secrets. Rerun the merge after a deploy that adds a
  hook.
- Editor and terminal config live in [dotfiles](https://github.com/Tonours/dotfiles)
  (`scripts/fix-links --fix` there).
- Pi comes from `@earendil-works/pi-coding-agent`. The installer uses your
  existing Node.js, preferring `asdf` when available; it never installs Node.
- Optional diff tooling: `hunkdiff`, from the CLI or a tmux pane.
- [Native Pi Durable](docs/pi-durable.md) provides resumable reviews, missions,
  task dependencies, Mobile admissions, CI waits, campaigns and compaction via
  `scripts/pi-durable`, alongside the classic profile.

## What you get

- **One contract, every harness.** Pi and Claude routers are kept identical by
  a shared fixture set (`scripts/router-eval`).
- **Rules enforced by code.** Guards block edits on a plan that is not `READY`,
  weakened frozen checks, staged plan files, non-read-only reviewer shells and
  unconsented default-branch pushes.
- **State that survives compaction.** Claude re-injects the plan status and the
  last ledger handoff on `compact|resume`, with the same compact instructions
  as Pi.
- **Budgeted context.** Per-route instruction size is measured and can only
  shrink: always-on went from 28,423 to 11,789 chars
  ([`docs/workflow-context-budget.md`](docs/workflow-context-budget.md)).
- **Locked skills.** Vendored packs carry `UPSTREAM_SHA` pins and an integrity
  lock (`skills-lock.json`). Skill changes pass promotion gates
  (`workflow/skills/skill-evaluation.md`), and routing stays deterministic code
  (ADR-0027).

## How work flows

Projects containing `workflow/spec.md` activate the workflow ambiently.

1. Small requests are handled directly.
2. Broad or risky work gets one root `PLAN.md`.
3. Only a `READY` plan authorizes implementation.
4. Push, deploy, secrets and publication always need explicit consent.

Every run leaves an event ledger under `.workflow/<slug>/`, and finished plans
are archived in `docs/plan/`.
One writer at a time is a protocol, not an OS lock.

## Repository map

| Path | Holds |
| --- | --- |
| `workflow/` | Routing, plans, guards, loops, validation contracts |
| `pi/`, `claude/` | Runtime adapters: settings, extensions, hooks, agents, skills |
| `vendor/`, `skills-lock.json` | Vendored skills, their scope catalog and lock |
| `workflow-scaffold/` | Templates `scripts/deploy-workflow` copies into projects |
| `scripts/`, `tests/` | Install, deploy, validation and regression checks |
| `mcp/` | Sanitized MCP template, no credentials |
| `docs/` | Guides, plan archives, research; decisions in `docs/adr/` |

## Everyday commands

```bash
scripts/verify-agentic-infra core     # core checks
bun test pi/extensions/__tests__/     # Pi extension tests
scripts/token-bench --check           # context cost per route
scripts/claude-hooks-check            # live Claude hooks wired?
scripts/check-fix-symlinks.sh         # managed links intact?
node scripts/validate-adrs .          # ADR format
scripts/workflow-ship-metrics --dir .workflow report --since 2026-09-01 # stats and patterns
scripts/workflow-run-check preflight # prerequisites before validation
scripts/workflow-run-check close --dir .workflow your-run # prospective event-chain check
```

CI runs `agentic-infra` on `ubuntu-24.04` for the public repository and on
self-hosted runners for private ones (`gh run list --workflow agentic-infra.yml`).

## Learn more

- [`docs/workflow-statistics.md`](docs/workflow-statistics.md): local statistics,
  recurring patterns, evidence and explicit multi-project reports.
- [`docs/README.md`](docs/README.md): index of current references and history.
- [`workflow/agent-quick-card.md`](workflow/agent-quick-card.md): one-page
  workflow entry; [`workflow/contract-details.md`](workflow/contract-details.md)
  for the full rules.
- [`docs/symlink-layout.md`](docs/symlink-layout.md): every managed link and the
  `shared`/`work`/`personal` scopes.
- [`claude/README.md`](claude/README.md): Claude commands, hooks and settings.

## Security

Credentials, OAuth material, cookies, session state and live runtime config stay
out of this repository. Tracked templates use placeholders, and the project
`.mcp.json` has no servers. See [`SECURITY.md`](SECURITY.md) and
[`docs/mcp-strategy.md`](docs/mcp-strategy.md).
