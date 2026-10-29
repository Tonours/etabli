# Etabli

Etabli gives Pi and Claude Code one workflow contract. The rules live in
`workflow/`, and each harness reads them through a thin adapter.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git && cd etabli
./scripts/install.sh            # tooling, Pi and managed links
scripts/claude-hooks-merge      # wire Claude hooks; --dry-run to preview
```

`scripts/verify-agentic-infra core` should then pass.

- `scripts/claude-hooks-merge` merges the Claude hooks into your live
  `settings.json` instead of linking it, because that file can hold secrets.
  The installer does not run it: rerun it after a deploy that adds a hook.
- Pi installs at the exact version in `pi/package.json`. The installer uses
  your existing Node.js, through `asdf` when available, and never installs
  Node.
- Editor and terminal config live in
  [dotfiles](https://github.com/Tonours/dotfiles) (`scripts/install-editor`,
  then `scripts/fix-links --fix` there).

## What you get

- **One contract for both harnesses.** Pi and Claude read the same route table
  (`workflow/spec.md`), the same contracts (`workflow/skills/`) and the same
  skill tree (`skills/<scope>/`).
- **A few guards in code.** An edit-tool write that adds a code comment is
  refused (a write through the shell is not checked),
  shell output goes through rtk when compacting it is safe, and reviewer
  shells stay read-only. Nothing else stops for approval (ADR-0032).
- **Locked skills.** Vendored packs carry an `UPSTREAM_SHA` pin and an
  integrity lock (`skills-lock.json`). `scripts/update-vendor-skills`
  refreshes them.

## How work flows

A project with a `workflow/spec.md` gets the workflow without asking for it.

1. A small request is handled directly.
2. Broad or risky work gets one root `PLAN.md`.
3. Only a `READY` plan authorizes implementation.
4. Push, deploy and publication run without approval stops. Secrets are never
   printed or committed.

The run keeps its evidence in `PLAN.md`, and a finished plan is archived in
`docs/plan/`. One writer at a time is a protocol, not an OS lock.

To use the workflow in another project, run
`scripts/deploy-workflow /path/to/project --dry-run`, read the planned writes,
then run it without `--dry-run`. On a project that already has the scaffold,
`--check` reports drift first; `--help` covers `--force`, `--prune` and
`--refresh-tracked`. A mistake an agent keeps making becomes a rule in that
project's own tooling
([`workflow/project-constraints.md`](workflow/project-constraints.md)).

## Repository map

| Path | Holds |
| --- | --- |
| `workflow/` | Routing, plans, guards, loops, validation contracts |
| `pi/`, `claude/` | Runtime adapters: settings, extensions, hooks, agents |
| `skills/` | First-party skills, one tree for both runtimes |
| `vendor/`, `skills-lock.json` | Vendored skills and their lock |
| `extras/` | Skills tracked but not deployed |
| `workflow-scaffold/` | Files `scripts/deploy-workflow` copies into a project |
| `scripts/`, `tests/` | Install, deploy, validation and regression checks |
| `mcp/` | Sanitized MCP template, no credentials |
| `docs/` | Guides, decisions in `docs/adr/`, plan archives in `docs/plan/` |

## Everyday commands

```bash
scripts/verify-agentic-infra core     # core checks
bun test pi/extensions/__tests__/     # Pi extension tests
scripts/claude-hooks-check            # live Claude hooks wired?
scripts/check-fix-symlinks.sh         # managed links intact? --fix repairs
node scripts/validate-adrs .          # ADR format
```

CI runs `agentic-infra` on GitHub-hosted `ubuntu-24.04`
(`gh run list --workflow agentic-infra.yml`).

## Learn more

- [`workflow/spec.md`](workflow/spec.md): workflow entry and map;
  [`workflow/contract-details.md`](workflow/contract-details.md) has the full
  rules.
- [`docs/symlink-layout.md`](docs/symlink-layout.md): every managed link and
  the `shared`/`work`/`personal` scopes.
- [`claude/README.md`](claude/README.md): Claude hooks, settings and skill
  governance.
- [`docs/mcp-strategy.md`](docs/mcp-strategy.md): MCP ownership, memory vaults
  and drift checks.
- [`vendor/README.md`](vendor/README.md): vendored skills and how to update
  them.
- [ADR-0029](docs/adr/0029-subscription-model-routing.md) and
  [`model-routing.json`](workflow/runtime/model-routing.json): which model runs
  which task.
- [`docs/adr/`](docs/adr/) and [`docs/plan/`](docs/plan/) are records, not
  runtime instructions.

## Security

Credentials, OAuth material, cookies, session state and live runtime config
stay out of this repository. Tracked templates use placeholders, and the
project `.mcp.json` has no servers. See [`SECURITY.md`](SECURITY.md).
