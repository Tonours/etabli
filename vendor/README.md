# vendor/

You get skill libraries maintained outside etabli, copied in so every harness
sees the same content and a fresh clone deploys a complete surface.

## Manifest

`sources.tsv` is the source of truth: one line per upstream, with the repo,
the tracked ref, the deploy scope, the exact skills to vendor, and an optional
`subpath` when the upstream keeps its `skills/` below the root. Each vendored
tree carries an `UPSTREAM_SHA` file with the commit it was taken from, and the
sync copies the upstream `LICENSE` next to it.

| Vendor | Upstream | Scope | Skills |
|---|---|---|---|
| `mattpocock` | `mattpocock/skills` | `shared` | 8: the engineering pack plus `productivity/grilling` (below) |
| `petergyang` | `petergyang/no-ai-slop` | `shared` | 1: `no-ai-slop`, an AI-slop editing pass |
| `typesafe-ai` | `typesafe-ai/skills` | `shared` | 1: `typesafe-ai`, build with TypeSafe System One (Jev) |
| `cloudflare` | `cloudflare/security-audit-skill` | `shared` | 1: `security-audit`, a six-phase audit with fresh verifier agents, run on GLM by `security-audit-glm` |

Pi gets a vendored skill only when its `workflow/runtime/skill-surface.tsv`
row sets `pi_core=1`, and no vendored row does today. Claude visibility follows
`claude/settings.skill-overrides.json`. Scope follows
[`claude/README.md`](../claude/README.md) § Scopes: `shared` deploys
everywhere, `work` and `personal` only where the machine declares that scope in
`~/.etabli-scope`.

## mattpocock pack

`codebase-design`, `domain-modeling`, `grill-with-docs`,
`improve-codebase-architecture`, `prototype`, `research` and `wizard`, plus
`productivity/grilling`, which `grill-with-docs` calls with `domain-modeling`.
Catalog rows use the upstream path (`engineering/<name>`), and the skills
deploy under their frontmatter names.

Skipped on purpose, so each name has one owner:

- `engineering/code-review` → etabli's `review` route (`workflow/skills/review.md`).
- `engineering/implement` → etabli's `implement` route.
- `engineering/setup-matt-pocock-skills` → configures the suite's own installer
  conventions, which etabli's vendoring replaces.

Under etabli, suite references to skipped or dropped names resolve to the
etabli equivalents, and the suite's own repo conventions fall back to Linear
plus `workflow/`. `research` delegates reading to a background agent, and
parent-only Pi runs it as sequential reads. The etabli routes own gating and
evidence. Vendored skills are task-level entry points, and repo research under
the etabli contract stays `workflow/skills/investigation.md`.

## Update the vendored skills

```bash
scripts/update-vendor-skills                 # every vendor, review then commit
scripts/update-vendor-skills mattpocock      # one vendor
```

It runs `scripts/sync-vendor-skills`, refreshes `skills-lock.json`, runs
`verify:skills` and both skill load checks, then prints each vendor whose
`UPSTREAM_SHA` moved with a GitHub compare link to the upstream changes. It
exits early when nothing moved. Deploy afterwards
(`scripts/deploy-agent-workflow --apply`) so the live surfaces pick it up.

`scripts/sync-vendor-skills` refuses to run while a tracked file under
`vendor/` has uncommitted changes, staged or not, so a forgotten local edit
surfaces instead of being overwritten. Untracked files are not checked: the
sync deletes and recreates each vendored tree, so an untracked file inside one
is lost.
`bun run verify:skills` is the read-only check `scripts/verify-agentic-infra`
runs.

## Restore a dropped pack

Dropped packs stay in git history. `git show 5a943a1f^:vendor/sources.tsv`
holds `ember-skills`, `adonisjs-skills` and the mattpocock skills pruned at
that commit. To bring one back:

1. Re-add the pack's row to `vendor/sources.tsv`.
2. Re-add its skill rows to `workflow/runtime/skill-surface.tsv`.
3. Commit both, since the sync refuses a `vendor/` tree with uncommitted
   changes, staged ones included.
4. Run `scripts/sync-vendor-skills <pack>`.
5. Run `cd pi && bun run update:skills-lock`, review the diff, then commit.

## Limitations

The sync rewrites `.cursor/skills/` and `.cursor/plugins/` paths to their
`.claude/` equivalents (ADR-0022). Apart from that, a vendored file matches
upstream.

> **Warning:** never hand-edit a file under `<vendor>/skills/`. An uncommitted
> edit blocks every sync, and a committed one is replaced by the next sync. Fix
> it upstream and re-sync, or fork the skill into `skills/<scope>/` under a
> different name.

## What's next

[`extras/README.md`](../extras/README.md) covers the shelf for skills that are
tracked but not deployed.
