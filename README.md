# Etabli

Personal source of truth for Pi, Claude Code, Neovim, Ghostty, and tmux
configuration. The repository keeps agent workflow policy explicit,
deployments conservative, and validation claims proportional to the evidence.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

The installer uses the existing Node.js runtime, preferring `asdf`; it does not
install `nvm`. Pi comes from `@earendil-works/pi-coding-agent`, and Neovim
review uses `hunkdiff` (https://www.hunk.dev/).

## Map

- `workflow/agent-quick-card.md` — one-page agent entry (routes, READY,
  check-freeze, ops-stop, validation)
- `workflow/spec.md` — canonical routing, safety, planning, and completion map
- `workflow/contract-details.md` — long rules and command lists
- `workflow/answer-quality.md` — live final-answer gate and durable-artifact
  checker contract
- `pi/`, `claude/` — runtime-specific adapters and configuration
- `nvim/`, `ghostty/`, `tmux.conf` — editor and terminal configuration
- `scripts/`, `tests/` — deployment, validation, and focused regression checks
- `docs/adr/` — architecture decisions (`node scripts/validate-adrs .`)
- `docs/plan/` — distilled archives of completed plans

Projects containing `workflow/spec.md` activate the workflow ambiently. Use
ordinary prompts; start from `workflow/agent-quick-card.md` then the map.
`PLAN.md` is the only active execution artifact, and implementation starts only
from `Status: READY`. The parent is the only writer (protocol, not an OS lock).
Push, deploy, destructive actions, secrets, production changes, and external
write-back still require explicit authority.

For deeper work, start from
`workflow/skills/self-improvement-loop.md`,
`workflow/skills/ambitious-project-loop.md`, or
`workflow/skills/pr-maintenance-loop.md`. Pi's named-workflow adapter remains
explicit-use and is documented in `workflow/pi-workflow-adapter.md`.

## Validation

```bash
scripts/verify-agentic-infra core
scripts/verify-agentic-infra full
scripts/vnext-suite --json
```

- `core` runs the small daily health and safety gate, including `bun audit`,
  router/guard regressions, deployment, and held-out vNext checks.
- `full` adds every deterministic repository check.
- `live` is separate and never reports a skipped run as success:

```bash
RUN_AGENT_CLI_SMOKE=1 RUN_REAL_AGENT_SCENARIOS=1 \
  scripts/verify-agentic-infra live
```

The vNext suite is deterministic host regression proof, not live-model
effectiveness evidence. `answer-quality-check` and `answer-quality-eval`
protect durable answer/research/handoff artifacts and their versioned
fixtures. `research-proof-check` rejects unsourced durable research.

Optional read-only diagnostics include `workflow-monitor`,
`workflow-metrics`, `workflow-dossier`, and `workflow-retrospect`.
`workflow-telemetry-recover` writes only with explicit `--apply`; telemetry is
experimental and does not establish user value until at least 10 representative
real tasks have task-grader outcomes. The project-autonomy envelope is also
experimental, opt-in, and outside `core`.
`scripts/pr-latest-head-status` remains the source for latest-head PR evidence.
See `docs/cross-project-research-grounding.md` for research context.

## Deployment

```bash
scripts/deploy-agent-workflow --dry-run
scaffold-project ~/code/my-project --new
deploy-workflow . --check
```

Use `--apply` only when the local deployment mutation is intended.
`deploy-agent-workflow` aligns Claude, Pi, and shared `~/.agents` surfaces and
conservatively syncs managed Pi package/model entries. `scaffold-project`
never overwrites existing files by default.

`pi/agent/settings.json` is only a tracked bootstrap; the live copy remains
local. Secrets and authentication files stay local and untracked.

## Public repository hygiene

This tree is intended to be safe to publish: MCP templates use `${VAR}`
placeholders only (`docs/mcp-strategy.md`), env files and key material are
gitignored, and machine-local auth stores (for example Copilot `auth.db`) are
not tracked. See `SECURITY.md` for the pre-public checklist.

After clone, point the optional local MLX model id in `pi/models.json` at your
weights path (tracked default is a `/path/to/models/...` placeholder).
