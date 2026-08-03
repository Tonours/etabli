# Etabli

Personal source of truth for an **agentic development harness** and matching
dotfiles: **Pi**, **Claude Code**, **Neovim**, **Ghostty**, and **tmux**.

Etabli keeps a shared workflow contract explicit (`workflow/`), deploys adapters
conservatively, and treats validation claims as proportional to evidence.

## What it is

- A **workflow contract** agents apply ambiently when a project has
  `workflow/spec.md` (routes, PLAN.md, guards, loops).
- **Thin adapters** for Pi (`pi/`) and Claude (`claude/`) over that contract.
- **Editor/terminal** configs: Neovim as a code-first minimal IDE (Catppuccin
  Mocha, aligned with Ghostty/tmux), not an agent or review cockpit.
- **Installers and checks** under `scripts/` and `tests/`.

## What it is not

- Not a hosted SaaS or multi-tenant product.
- Not an in-Neovim agent dashboard or Hunk review inbox (product diff review,
  if used, is an **optional external** CLI such as `hunkdiff`, not an nvim
  subsystem).
- Not a multi-harness Codex/Kimi Code tree in-repo (removed; see ADR-0011).
  `openai-codex/*` names are **model providers**, not a tracked harness layout.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

The installer uses the existing Node.js runtime, preferring `asdf`; it does not
install `nvm`. Pi comes from `@earendil-works/pi-coding-agent`. Optional
terminal diff tooling may install `hunkdiff` (https://www.hunk.dev/) for use
**outside** Neovim (CLI / tmux pane).

## Layout

| Path | Role |
|------|------|
| `workflow/` | Canonical contract (`spec.md`, skills, loops) |
| `workflow/agent-quick-card.md` | One-page agent entry |
| `workflow/contract-details.md` | Long rules and command lists |
| `docs/workflow-guide.md` | Human guide with schemas (routes, PLAN, loops) |
| `pi/`, `claude/` | Runtime adapters |
| `nvim/`, `ghostty/`, `tmux.conf` | Editor and terminal |
| `mcp/` | Sanitized MCP template (`docs/mcp-strategy.md`) |
| `scripts/`, `tests/` | Deploy, validation, regression |
| `docs/adr/` | Architecture decisions (`node scripts/validate-adrs .`) |
| `docs/plan/` | Archives of completed plans (not active work) |
| `SECURITY.md` | Public-repo / secrets hygiene |

## Workflow in 60 seconds

Projects containing `workflow/spec.md` **activate the workflow ambiently**. Use
ordinary prompts; start from `workflow/agent-quick-card.md`, then
`docs/workflow-guide.md` for diagrams, then `workflow/spec.md` as authority.

```text
learn -> plan -> implement -> review -> validate
```

- Root **`PLAN.md`** is the only active execution artifact.
- Implement only from **`Status: READY`** (after adversary when required).
- Parent is the only writer (**protocol, not an OS lock**).
- Push, deploy, destructive actions, secrets, production changes, and external
  write-back still require explicit authority (`ops-stop`).

Deeper loops:

- `workflow/skills/self-improvement-loop.md`
- `workflow/skills/ambitious-project-loop.md`
- `workflow/skills/pr-maintenance-loop.md`
- `workflow/skills/ship.md`

Answer quality: `workflow/answer-quality.md`; durable artifacts use
`answer-quality-check` / `answer-quality-eval`. Research claims:
`research-proof-check`. Cross-project research notes:
`docs/cross-project-research-grounding.md`.

## Validation

```bash
scripts/verify-agentic-infra core
scripts/verify-agentic-infra full
scripts/vnext-suite --json
```

- `core` — daily health and safety gate (router/guards, deploy surfaces, held-out
  checks, including `bun audit` where configured).
- `full` — every deterministic repository check.
- `live` is separate and never reports a skipped run as success:

```bash
RUN_AGENT_CLI_SMOKE=1 RUN_REAL_AGENT_SCENARIOS=1 \
  scripts/verify-agentic-infra live
```

Optional read-only diagnostics: `workflow-retrospect`. Telemetry is experimental and
does not establish user value until **at least 10 representative** real tasks
have task-grader outcomes. `workflow-telemetry-recover` writes only with
explicit `--apply`.

`scripts/pr-latest-head-status` remains the source for latest-head PR evidence.

## Deployment

```bash
scripts/deploy-agent-workflow --dry-run
scaffold-project ~/code/my-project --new
deploy-workflow . --check
```

Use `--apply` only when the local deployment mutation is intended.
`deploy-agent-workflow` aligns Claude, Pi, and shared `~/.agents` surfaces and
conservatively syncs **managed Pi package/model entries**. `scaffold-project`
never overwrites existing files by default.

`pi/agent/settings.json` is a tracked bootstrap; the live copy can stay local.
Secrets and authentication files stay local and untracked (`SECURITY.md`).

## Public repository hygiene

This tree is intended to be safe to publish: MCP templates use `${VAR}`
placeholders only (`docs/mcp-strategy.md`), env files and key material are
gitignored, and machine-local auth stores are not tracked. See `SECURITY.md`.

After clone, point optional local MLX model ids in `pi/models.json` at your
weights path (tracked default is a `/path/to/models/...` placeholder).

## Where to go next

1. `docs/workflow-guide.md` — schemas for routes, PLAN lifecycle, guards, loops  
2. `workflow/agent-quick-card.md` — agent one-pager  
3. `workflow/spec.md` — full contract (wins on conflict)  
4. `nvim/README.md` — code-first editor map  
5. `docs/adr/` — decision log  
