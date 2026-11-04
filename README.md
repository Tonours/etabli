# Etabli

Etabli gives Pi and Claude Code one workflow contract. The rules live in
`workflow/`, and each harness reads them through a thin adapter, so a plan, a
review or a guard behaves the same on both.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git && cd etabli
./scripts/install.sh            # tooling, Pi and managed links
scripts/claude-hooks-merge      # wire Claude hooks; --dry-run to preview
scripts/verify-agentic-infra core
```

The installer sets up the tooling and the managed links:

- system packages through brew, apt, dnf or pacman;
- `core.hooksPath=.githooks`, so the pre-push secret scan runs (a push is
  blocked when gitleaks is missing);
- rtk 0.39.0 or later;
- Pi at the exact version pinned in `pi/package.json`, only when `pi` is not
  already on your PATH, plus its packages;
- every managed link, through `scripts/deploy-agent-workflow --apply`
  ([`docs/symlink-layout.md`](docs/symlink-layout.md));
- your shell PATH, with `agent` kept as Cursor's.

It uses your existing Node.js, through `asdf` when available, and never
installs Node or Bun. `scripts/verify-agentic-infra` needs Bun and the `pi/`
dependencies, so run `cd pi && bun install --frozen-lockfile` once before the
first check.

`scripts/claude-hooks-merge` merges the Claude hooks into your live
`settings.json` instead of linking it, because that file can hold secrets. The
installer does not run it. Rerun it after a deploy that adds a hook.

Editor and terminal config live in
[dotfiles](https://github.com/Tonours/dotfiles) (`scripts/install-editor`, then
`scripts/fix-links --fix` there).

## What you get

- **One contract for both harnesses.** Pi and Claude read the same route table
  (`workflow/spec.md`), the same contracts (`workflow/skills/`) and the same
  skill tree (`skills/<scope>/`).
- **Guards in code, not in prose.** The first three run on Claude as hooks and
  on Pi as extensions, over one shared module each in `workflow/runtime/`:
  - an edit-tool write that adds a code comment to a file of a known language
    is refused, except doc comments and files outside a git work tree (a shell
    write, or a file without a known extension, is not checked);
  - shell output goes through rtk when compacting it is safe;
  - a `gh pr create` or `gh pr edit` body must follow the PR body contract, and
    the literal text of a `git commit` message carries no `Claude-Session:` or
    `Co-Authored-By:` trailer and no AI credit;
  - the Claude `scout`, `reviewer` and `adversary` agents get a read-only
    shell, apart from a plain `git fetch`.

  Nothing else stops for approval (ADR-0032).
- **Locked skills.** Vendored packs carry an `UPSTREAM_SHA` pin and an
  integrity lock (`skills-lock.json`). `scripts/update-vendor-skills`
  refreshes them.
- **One deploy for every machine.** `scripts/deploy-hosts` fast-forwards each
  host's checkout to the pushed `main`, then deploys and checks it there.

## How work flows

A project with a `workflow/spec.md` gets the workflow without asking for it.

1. A small request is handled directly.
2. Broad or risky work gets one root `PLAN.md`.
3. Only a `READY` plan authorizes implementation.
4. Push, deploy and publication run without approval stops. Secrets are never
   printed or committed.

The run keeps its evidence in `PLAN.md`, and a finished plan is archived in
`docs/plan/`. One writer at a time is a protocol, not an OS lock.

## Use the workflow in another project

```bash
scripts/deploy-workflow /path/to/project --dry-run   # read the planned writes
scripts/deploy-workflow /path/to/project
```

On a project that already has the scaffold, `--check` reports drift first
(`STALE` for an older etabli copy, `EDITED` for a local change). `--help`
covers `--force`, `--refresh-tracked` and `--prune`. A mistake an agent keeps
making becomes a rule in that project's own tooling
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
| `.githooks/` | Pre-push secret scan |
| `mcp/` | Sanitized MCP template, no credentials |
| `docs/` | Guides, decisions in `docs/adr/`, plan archives in `docs/plan/` |

## Everyday commands

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

`scripts/verify-agentic-infra` reads its checks from
`workflow/runtime/agentic-infra-checks.tsv`. Run the full relevant group before
a push.

CI runs `agentic-infra` on GitHub-hosted `ubuntu-24.04`: one job runs the
`shell-docs` group plus a full-history secret scan, the other the `pi` group
(`gh run list --workflow agentic-infra.yml`).

## Security

Credentials, OAuth material, cookies, session state and live runtime config
stay out of this repository. Tracked templates use placeholders, and the
project `.mcp.json` has no servers. [`SECURITY.md`](SECURITY.md) has the scan
policy.

## Learn more

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
- [`docs/adr/`](docs/adr/) and [`docs/plan/`](docs/plan/): decision and plan
  records, not runtime instructions.
