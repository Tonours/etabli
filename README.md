# Etabli

Personal source of truth for an **agentic development harness** and matching
dotfiles: **Pi**, **Claude Code**, managed **Codex** skills, the shared **Grok**
surface, **Neovim**, **Ghostty**, **tmux**, and **Herdr**.

Etabli keeps a shared workflow contract explicit (`workflow/`), deploys adapters
conservatively, and treats validation claims as proportional to evidence.

## What it is (and is not)

- A **workflow contract** agents apply ambiently when a project has
  `workflow/spec.md` (routes, PLAN.md, guards, loops).
- **Thin adapters** for Pi (`pi/`) and Claude (`claude/`), plus catalog-driven
  skill links for Codex and Grok's `~/.agents` discovery surface.
- **Editor/terminal** configs: Neovim as a code-first minimal IDE (Catppuccin
  Mocha, aligned with Ghostty/tmux/Herdr), not an agent or review cockpit.
- **Installers and checks** under `scripts/` and `tests/`.

Not a hosted SaaS, not an in-Neovim agent dashboard (product diff review is an
optional external CLI such as `hunkdiff`), not a full Codex/Grok/Kimi harness
tree in-repo (removed; see ADR-0011 — `openai-codex/*` names are **model
providers**).

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

The installer uses the existing Node.js runtime, preferring `asdf`; it does not
install `nvm`. Pi comes from `@earendil-works/pi-coding-agent`. Optional
terminal diff tooling may install `hunkdiff` (<https://www.hunk.dev/>) for use
**outside** Neovim (CLI / tmux pane).

## Layout

| Path | Role |
|------|------|
| `workflow/` | Canonical contract (`spec.md`, skills, loops) |
| `workflow/agent-quick-card.md` | One-page agent entry |
| `workflow/contract-details.md` | Long rules and command lists |
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

Etabli is not a tool you invoke. It is a **contract that agents read**, plus
the symlinks that put it where each runtime looks: one tracked source links
into `~/.claude/workflow`, `~/.pi/agent/workflow`, and `~/.agents/workflow`.
One edit here changes every agent's behavior — no per-runtime copy to sync.

Three mechanisms do the work:

1. **Ambient activation** — projects containing `workflow/spec.md`
   **activate the workflow ambiently**; you never write "use the Etabli
   workflow".
2. **One plan, one gate** — root `PLAN.md` is the only execution artifact;
   pre-`READY`, hooks deny every write except the plan itself. Once `READY`,
   checks strengthen-only.
3. **Guards that fail closed** — Claude and Pi share one guard decision
   function; repeated failure trips `no_progress` instead of grinding. One
   writer at a time is a **protocol, not an OS lock** — sidecar scouts and
   reviewers stay read-only. Push, deploy, secrets, and production always need
   explicit authority.

Long-running loops have their own contracts — self-improvement
(`workflow/skills/self-improvement-loop.md`), ambitious project
(`workflow/skills/ambitious-project-loop.md`), PR maintenance
(`workflow/skills/pr-maintenance-loop.md`), ship, investigation, programs —
and so does the knowledge vault.

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
| `/verify-workflow` | Prove a claim or re-run checks, no edits | Verdict with evidence |
| `/pr-review`, `/pr-qa` | Review a PR, or build its test plan | Findings / test plan |
| `/sec-pr` | Audit a Dependabot or security PR | `PASS` / `FAIL` |
| `/ci-fix` | Repair failing CI autonomously | CI green, or blocked at cap |

Also shared: `/spec-guide` and the `/linear-*` commands. Scoped surfaces
depend on `~/.etabli-scope` — run `ls ~/.claude/commands` for what this machine
actually has.

## Where to go next

1. `workflow/agent-quick-card.md` — agent one-pager
2. `workflow/spec.md` — full contract (wins on conflict)
3. `docs/harness-eval.md` — behavioral eval suite
4. `docs/mcp-strategy.md` — MCP inventory and scope
5. `nvim/README.md` — code-first editor map
6. `docs/adr/` — decision log
