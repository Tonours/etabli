# Etabli

One workflow contract for Pi and Claude Code. `workflow/` holds the rules;
both harnesses read them through thin adapters.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git && cd etabli
./scripts/install.sh            # tooling, Pi and managed links
scripts/claude-hooks-merge      # wire Claude hooks; --dry-run to preview
```

Then `scripts/verify-agentic-infra core` should PASS.

- The Claude hooks are merged into your live `settings.json` rather than linked,
  because that file can hold secrets. Rerun the merge after a deploy that adds a
  hook.
- Editor and terminal tooling and config live in [dotfiles](https://github.com/Tonours/dotfiles)
  (`scripts/install-editor`, then `scripts/fix-links --fix` there).
- Pi is pinned to `@earendil-works/pi-coding-agent@1.0.3`; fresh installation reads the exact version from `pi/package.json`. The installer uses your
  existing Node.js, preferring `asdf` when available; it never installs Node.
- [Subscription model routing](docs/adr/0029-subscription-model-routing.md) records the task/model choices and Muse terms boundary; the [registry](workflow/runtime/model-routing.json) keeps active selections consistent.

## What you get

- **One contract, every harness.** Pi and Claude share one route classifier
  and its golden fixtures (`tests/router-evals/core.json`).
- **A few guards in code.** No-comments and rtk guards on writes and shell
  commands, and read-only reviewer shells; everything else runs without
  approval stops (ADR-0032).
- **Locked skills.** Vendored packs carry `UPSTREAM_SHA` pins and an integrity
  lock (`skills-lock.json`); `scripts/update-vendor-skills` refreshes them, and
  routing stays deterministic code (ADR-0027).

## How work flows

Projects containing `workflow/spec.md` activate the workflow ambiently.

1. Small requests are handled directly.
2. Broad or risky work gets one root `PLAN.md`.
3. Only a `READY` plan authorizes implementation.
4. Push, deploy and publication run without approval stops; secrets are never
   printed or committed.

A run keeps its evidence in `PLAN.md`, and finished plans are archived in
`docs/plan/`.
One writer at a time is a protocol, not an OS lock.

To adopt the workflow in another project, deploy the current scaffold with
`scripts/deploy-workflow /path/to/project` (review drift before `--force` on an
existing project). A recurring agent mistake becomes a rule in the project's
own tooling ([`workflow/project-constraints.md`](workflow/project-constraints.md)).

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
scripts/claude-hooks-check            # live Claude hooks wired?
scripts/check-fix-symlinks.sh         # managed links intact?
node scripts/validate-adrs .          # ADR format
```

CI runs `agentic-infra` on GitHub-hosted `ubuntu-24.04`
(`gh run list --workflow agentic-infra.yml`).

## Learn more

- [`workflow/spec.md`](workflow/spec.md): workflow entry and map;
  [`workflow/contract-details.md`](workflow/contract-details.md) for the full rules.
- [`docs/symlink-layout.md`](docs/symlink-layout.md): every managed link and the
  `shared`/`work`/`personal` scopes.
- [`claude/README.md`](claude/README.md): Claude hooks and settings.
- [`docs/mcp-strategy.md`](docs/mcp-strategy.md): sanitized MCP inventory and scope;
  [`docs/vendor-skills.md`](docs/vendor-skills.md): vendored skills and update path.
- History: [`docs/adr/`](docs/adr/) (decisions) and [`docs/plan/`](docs/plan/)
  (implemented plan archives) are records, not runtime instructions.

## Security

Credentials, OAuth material, cookies, session state and live runtime config stay
out of this repository. Tracked templates use placeholders, and the project
`.mcp.json` has no servers. See [`SECURITY.md`](SECURITY.md) and
[`docs/mcp-strategy.md`](docs/mcp-strategy.md).
