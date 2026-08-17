# Etabli

Personal source of truth for an **agentic development harness** and matching
dotfiles: **Pi**, **Claude Code**, managed **Codex** skills, the shared **Grok**
surface, **Neovim**, **Ghostty**, **tmux**, and **Herdr**.

Etabli keeps a shared workflow contract explicit (`workflow/`), deploys adapters
conservatively, and treats validation claims as proportional to evidence.

## What it is

- A **workflow contract** agents apply ambiently when a project has
  `workflow/spec.md` (routes, PLAN.md, guards, loops).
- **Thin adapters** for Pi (`pi/`) and Claude (`claude/`), plus catalog-driven
  skill links for Codex and Grok's `~/.agents` discovery surface.
- **Editor/terminal** configs: Neovim as a code-first minimal IDE (Catppuccin
  Mocha, aligned with Ghostty/tmux/Herdr), not an agent or review cockpit.
- **Installers and checks** under `scripts/` and `tests/`.

## What it is not

- Not a hosted SaaS or multi-tenant product.
- Not an in-Neovim agent dashboard or Hunk review inbox (product diff review,
  if used, is an **optional external** CLI such as `hunkdiff`, not an nvim
  subsystem).
- Not a full Codex/Grok/Kimi harness tree in-repo (removed; see ADR-0011).
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
| `nvim/`, `ghostty/`, `tmux.conf`, `herdr/` | Editor and terminal (Herdr multihost + plugins docs) |
| `mcp/` | Sanitized MCP template (`docs/mcp-strategy.md`) |
| `vendor/` | Vendored upstream skills (`vendor/sources.tsv`, scope-gated) |
| `workflow-scaffold/` | Project templates `deploy-workflow` copies into a repo |
| `scripts/`, `tests/` | Deploy, validation, regression |
| `docs/adr/` | Architecture decisions (`node scripts/validate-adrs .`) |
| `docs/plan/` | Archives of completed plans (not active work) |
| `SECURITY.md` | Public-repo / secrets hygiene |

## How it works

Etabli is not a tool you invoke. It is a **contract that agents read**, plus the
symlinks that put it where each runtime looks.

`scripts/install.sh` links one tracked source into every runtime: the workflow
contract lands in `~/.claude/workflow`, `~/.pi/agent/workflow`, and
`~/.agents/workflow`; commands, skills, and agents are linked from
`claude/scopes/<scope>/`. One edit in this repo changes every agent's behavior —
there is no per-runtime copy to keep in sync.

From there, three mechanisms do the work:

**1. Ambient activation.** Projects containing `workflow/spec.md`
**activate the workflow ambiently**. You write ordinary prompts; you never write
"use the Etabli workflow". Slash commands select a *specific* route when you want
more control than the default.

**2. One plan, one gate.** Root `PLAN.md` is the only active execution artifact,
and it carries a status:

```text
DRAFT ──▶ CHALLENGED ──▶ READY ──▶ implement ──▶ archive under docs/plan/
                                   ▲
                        code changes allowed only here
```

Pre-READY, only `PLAN.md` itself may be edited — other writes and mutating shell
are **denied by hooks**, not by convention. Once READY, checks may only be
strengthened; weakening one demotes the plan back to `CHALLENGED`.

**3. Guards that fail closed.** Claude `PreToolUse` hooks and Pi `tool_call`
share one decision function (`planMutationGuardDecision`), so both runtimes deny
the same thing. Repeated failure trips a `no_progress` stop instead of letting an
agent grind. One writer holds the plan at any instant:
a **protocol, not an OS lock** — sidecar scouts and reviewers stay read-only.
Push, deploy, secrets, production, and external write-back always need explicit
authority (`ops-stop`).

What that buys you: an agent cannot start coding from a vague plan, cannot
quietly lower the bar it agreed to, cannot loop forever on a red check, and
cannot push or deploy on its own.

## Using it

Nothing to run for ordinary work — ask for what you want. Reach for a command
when you want a specific route and a specific stopping point.

| Command | Use it when | Stops at |
| --- | --- | --- |
| *(plain prompt)* | Small fix, question, focused change | Answer or minimal diff |
| `/plan-loop` | Shape and challenge a plan before any code | `READY` or `CHALLENGED` |
| `/adversary` | Stress-test a plan or a diff, cross-model | Findings folded into `PLAN.md` |
| `/implement` | Execute an existing `READY` plan | Archived plan, root `PLAN.md` gone |
| `/plan-implement` | Plan → adversary → implement in one autonomous chain | Same as `/implement` |
| `/ship` | One task A to Z, including PR and green CI | Merged-ready PR |
| `/review` | Review the diff, a branch, or a commit | `GO` / `GO WITH NOTES` / `BLOCK` |
| `/pre-commit` | Last pass: review, strip debug, targeted tests | Commit message |
| `/commit` | One scoped conventional commit (never pushes) | Commit |
| `/verify-workflow` | Prove a claim or re-run checks, no edits | Verdict with evidence |
| `/pr-review`, `/pr-qa` | Review a PR, or build its test plan | Findings / test plan |
| `/sec-pr` | Audit a Dependabot or security PR | `PASS` / `FAIL` |
| `/ci-fix` | Repair failing CI autonomously | CI green, or blocked at cap |
| `/recap` | Standup or team message from git evidence | Recap text |

Also shared: `/spec-verify` and `/cross-repo-audit` (verify claims against real
code with `file:line` evidence), plus the `/linear-*` commands. Scoped surfaces
depend on `~/.etabli-scope` — run `ls ~/.claude/commands` for what this machine
actually has.

Longer loops are contracts of their own:

- `workflow/skills/self-improvement-loop.md`
- `workflow/skills/ambitious-project-loop.md`
- `workflow/skills/pr-maintenance-loop.md`
- `workflow/skills/recurring-run.md`
- `workflow/skills/skill-evaluation.md`
- `workflow/skills/ship.md`

Answer quality is a contract too (`workflow/answer-quality.md`): durable
artifacts run `answer-quality-check` / `answer-quality-eval`, research claims run
`research-proof-check`. Cross-project research notes:
`docs/cross-project-research-grounding.md`.

## Knowledge vault

Durable technical findings live outside this repo, in a vault served read-only
over MCP. On a work machine that vault is `~/work/brain`; it runs its own
standalone engine and exposes `vault_search`, `vault_context`, `vault_read`, and
`vault_health` (ADR-0017, `docs/mcp-strategy.md`). Agents consult it before
re-investigating a known mechanic; writes go through the vault's own contract and
validator, never through MCP.

Runtime availability is per-runtime and not guaranteed — check before relying on
it, as with any MCP server.

## Validation

```bash
scripts/verify-agentic-infra core
scripts/verify-agentic-infra full
scripts/-suite --json
```

- `core` — daily health and safety gate (router/guards, deploy surfaces, held-out
  checks, including `bun audit` where configured).
- `full` — every deterministic repository check.
- `live` is separate and never reports a skipped run as success:

```bash
RUN_AGENT_CLI_SMOKE=1 RUN_REAL_AGENT_SCENARIOS=1 RUN_SKILL_RUNTIME_CANARY=1 \
  scripts/verify-agentic-infra live
```

Optional read-only diagnostics: `workflow-retrospect`. Telemetry is experimental and
does not establish user value until **at least 10 representative** real tasks
have task-grader outcomes. `workflow-telemetry-recover` writes only with
explicit `--apply`.

Conversation-derived workflow candidates remain read-only and aggregate-only:
`scripts/conversation-retrospect`. Compare real baseline/candidate skill runs
with `scripts/skill-eval`; tracked held-out fixtures are frozen/public, not
confidentially isolated. Use `scripts/runtime-skill-canary` for offline
source/link proof and opt-in live invocation, and `scripts/session-handoff` for
a compact projection of the active plan, ledger, and Git state.

`scripts/pr-latest-head-status` remains the source for latest-head PR evidence.

## Deployment

```bash
scripts/deploy-agent-workflow --dry-run
scaffold-project ~/code/my-project --new
deploy-workflow . --check
```

Use `--apply` only when the local deployment mutation is intended.
`deploy-agent-workflow` aligns Claude, Pi, the skill-only Codex surface, and
Grok's shared `~/.agents` surface. It activates `shared` plus the machine scope
from `~/.etabli-scope` (`work` on the current workstation), and conservatively
syncs **managed Pi package/model entries**. Runtime auth, MCP configuration,
plugins, histories, and private settings stay local. `scaffold-project` never
overwrites existing files by default.

`pi/agent/settings.json` is a tracked bootstrap; the live copy can stay local.
Secrets and authentication files stay local and untracked (`SECURITY.md`).

After clone, point optional local MLX model ids in `pi/models.json` at your
weights path (tracked default is a `/path/to/models/...` placeholder).

## Where to go next

1. `docs/workflow-guide.md` — schemas for routes, PLAN lifecycle, guards, loops  
2. `workflow/agent-quick-card.md` — agent one-pager  
3. `workflow/spec.md` — full contract (wins on conflict)  
4. `nvim/README.md` — code-first editor map  
5. `docs/adr/` — decision log  
