# Etabli

[![agentic-infra](https://github.com/Tonours/etabli/actions/workflows/agentic-infra.yml/badge.svg)](https://github.com/Tonours/etabli/actions/workflows/agentic-infra.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Etabli gives your coding agents one way of working. Pi and Claude Code read the
same rules, follow the same plan-then-build loop and run the same guards, so a
task behaves the same whichever agent picks it up. Codex is pointed at the same
rules and skills, without the guards (ADR-0043).

*Établi* is French for a craftsman's workbench: one bench, the same tools, put
back in the same place every time.

## Why etabli

Without etabli, each agent has its own instruction file, and those files drift
apart. One agent plans before risky work while another dives straight in. A
rule such as "no AI trailer in commits" lives in prose, and prose gets ignored.
Setting up a second machine means copying config by hand.

Etabli fixes that with:

- **One contract, three harnesses.** The rules live once, in
  [`workflow/`](workflow/). Pi, Claude and Codex reach them through thin adapters, so
  you never maintain two prompt files.
- **Plans before risky work.** Broad or risky work gets a root `PLAN.md`.
  Nothing is implemented until that plan is `READY`, and a finished plan is
  archived in [`docs/plan/`](docs/plan/) as project memory.
- **Reviews from a fresh context.** Before a code change ships, a reviewer
  that never saw the conversation and a second model family both try to break
  it. A small docs or config edit gets a self-review instead.
- **Guards in code, not in prose.** Comment-free code, the PR body format,
  clean commit messages and read-only reviewer shells are enforced by hooks.
- **One setup on every machine.** `scripts/install.sh` links everything into
  your home, and `scripts/deploy-hosts` brings your other machines to the same
  commit.
- **Portable.** `scripts/deploy-workflow` drops the same workflow into any
  other project.

## How it works

```text
         workflow/   routes, plan rules, review rubric, guards
             │
     ┌───────┴────────┐
     ▼                ▼
 claude/           pi/
 hooks, agents     extensions
     │                │
     └───────┬────────┘
             ▼
 ~/.claude and ~/.pi, linked by scripts/install.sh
```

Your agent routes every request to the smallest route that fits it
([`workflow/spec.md`](workflow/spec.md)):

| You ask for | Route | What you get |
| --- | --- | --- |
| A question, a diagnosis, a small fix | `answer` | The answer or the edit, no plan |
| A plan ("fais un plan") | `plan-loop` | A `PLAN.md` that reaches `READY` or `CHALLENGED` |
| Plan and build, end to end | `plan-implement` | Plan, code, checks, reviews, archive |
| Build an existing `READY` plan | `implement` | Code, checks, reviews, archive |
| A review of a diff, PR or plan | `review` | Findings and a `GO`, `GO WITH NOTES` or `BLOCK` verdict |
| Proof that something works | `verify` | `VERIFIED`, `NOT VERIFIED` or `INCONCLUSIVE` |

A planned run goes through these steps:

```text
learn ─► plan ─► challenge ─► READY ─► implement ─► check ─► review ─► archive
```

The run keeps its evidence in `PLAN.md`: facts cited as `path:line`, the
checks and their results, every review verdict. Push, deploy and publication
run without approval stops (ADR-0032), and secrets are never printed or
committed.

## Requirements

- macOS or Linux (Debian, Fedora or Arch).
- Git and Node.js. The installer uses your Node.js, through `asdf` when
  available, and never installs it.
- [Bun](https://bun.sh), for the test suite.
- Claude Code, Pi, or both. The installer adds Pi when it is missing.
- gitleaks for the pre-push secret scan. The installer adds it on macOS. On
  Linux you install it yourself, or every push is blocked.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git && cd etabli
./scripts/install.sh                   # tooling, Pi and managed links
scripts/claude-hooks-merge --dry-run   # preview the Claude hooks
scripts/claude-hooks-merge             # wire them into your settings
(cd pi && bun install --frozen-lockfile)
scripts/verify-agentic-infra core      # every check should pass
```

The installer:

- installs system packages through brew, apt, dnf or pacman;
- sets `core.hooksPath=.githooks`, so the pre-push secret scan runs;
- installs rtk 0.39.0 or later;
- installs Pi at the version pinned in `pi/package.json` when `pi` is not
  already on your PATH, plus its packages;
- links every managed surface with `scripts/deploy-agent-workflow --apply`
  ([`docs/symlink-layout.md`](docs/symlink-layout.md));
- sets your shell PATH, keeping `agent` as Cursor's.

`scripts/claude-hooks-merge` merges into your live `settings.json` instead of
linking it, because that file can hold secrets. The installer does not run it,
so rerun it after a deploy that adds a hook.

Editor and terminal config live in
[dotfiles](https://github.com/Tonours/dotfiles).

## Usage

You talk to your agent as usual. In a project that has a `workflow/spec.md`,
the workflow is on without asking for it. For example:

```text
> fix the typo in the install message           → answer: edited directly
> fais un plan pour migrer les tests vers bun   → plan-loop: PLAN.md, READY
> /plan-implement add a --json flag to prs-today → plan, build, review, push
> /review 123                                   → findings and a verdict
```

### Add the workflow to another project

```bash
scripts/deploy-workflow /path/to/project --dry-run   # read the planned writes
scripts/deploy-workflow /path/to/project
```

On a project that already has the scaffold, `--check` reports drift first
(`STALE` for an older etabli copy, `EDITED` for a local change). `--help`
covers `--force`, `--refresh-tracked` and `--prune`. A mistake an agent keeps
making becomes a rule in that project's own tooling
([`workflow/project-constraints.md`](workflow/project-constraints.md)).

### Everyday commands

```bash
scripts/verify-agentic-infra core     # core checks; full, shell-docs, pi, all
bun test pi/extensions/__tests__/     # Pi extension tests
scripts/claude-hooks-check            # live Claude hooks wired?
scripts/check-fix-symlinks.sh         # managed links intact? --fix repairs
node scripts/validate-adrs .          # ADR format
scripts/plan-cleanup --status         # root PLAN.md status and age, as JSON
scripts/deploy-hosts                  # deploy the pushed main to other machines
scripts/prs-today                     # your open PRs: CI, review, stack order
```

## What the guards enforce

The first three guards run on Claude as hooks and on Pi as extensions, each
over one shared module in `workflow/runtime/`:

- An edit-tool write that adds a code comment to a file of a known language is
  refused. Doc comments and files outside a git work tree pass. A shell write,
  or a file without a known extension, is not checked.
- Shell output goes through rtk when compacting it is safe.
- A `gh pr create` or `gh pr edit` body must follow the PR body contract. The
  literal text of a `git commit` message must carry no `Claude-Session:` or
  `Co-Authored-By:` trailer and no AI credit.
- The Claude `scout`, `reviewer` and `adversary` agents get a read-only shell,
  apart from a plain `git fetch`.

Nothing else stops for approval. [`claude/README.md`](claude/README.md) § Hooks
has the details and the known blind spots.

## Repository map

| Path | Holds |
| --- | --- |
| `workflow/` | Routing, plans, guards, loops, validation contracts |
| `pi/`, `claude/` | Runtime adapters: settings, extensions, hooks, agents |
| `codex/` | Codex adapter, linked as `~/.codex/AGENTS.md` |
| `skills/` | First-party skills, one tree for every runtime |
| `vendor/`, `skills-lock.json` | Vendored skills, pinned by `UPSTREAM_SHA` and locked |
| `extras/` | Skills tracked but not deployed |
| `workflow-scaffold/` | Files `scripts/deploy-workflow` copies into a project |
| `scripts/`, `tests/` | Install, deploy, validation and regression checks |
| `.githooks/` | Pre-push secret scan |
| `mcp/` | Sanitized MCP template, no credentials |
| `docs/` | Guides, decisions in `docs/adr/`, plan archives in `docs/plan/` |

## Contributing

Etabli is a personal workflow, shared in the open. Issues and pull requests are
welcome. Before you open a PR:

1. Run `scripts/verify-agentic-infra full`. CI runs the `shell-docs` and `pi`
   groups on `ubuntu-24.04`, plus a full-history secret scan.
2. Record a structural decision as an ADR in [`docs/adr/`](docs/adr/).
3. Keep each commit to a conventional subject line
   ([`workflow/git-contract.md`](workflow/git-contract.md)).

## Security

Credentials, OAuth material, cookies, session state and live runtime config
stay out of this repository. Tracked templates use placeholders, and the
project `.mcp.json` has no servers. [`SECURITY.md`](SECURITY.md) has the scan
policy and how to report a leaked credential.

## License

[MIT](LICENSE)

## Learn more

- [`workflow/skills/investigation.md`](workflow/skills/investigation.md): learning
  from recovered run incidents, with evidence and no automatic rule changes.
- [Research note (French)](docs/research/20261107-agent-self-improvement.md):
  source analysis of Skill Doctor, GEPA, Reflexion and ACE.
- [`workflow/spec.md`](workflow/spec.md): workflow entry and map;
  [`workflow/contract-details.md`](workflow/contract-details.md) has the full
  rules.
- [`docs/symlink-layout.md`](docs/symlink-layout.md): every managed link,
  copy and merge.
- [`claude/README.md`](claude/README.md): scopes, Claude hooks, skill
  governance and the PR review scripts.
- [`docs/mcp-strategy.md`](docs/mcp-strategy.md): MCP ownership, memory vaults
  and drift checks.
- [`vendor/README.md`](vendor/README.md): vendored skills and how to update
  them.
- [ADR-0029](docs/adr/0029-subscription-model-routing.md) and
  [`model-routing.json`](workflow/runtime/model-routing.json): which model runs
  which task.
- [`GLOSSARY.md`](GLOSSARY.md): the terms the contracts use.
