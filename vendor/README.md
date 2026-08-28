# vendor/

Skill libraries maintained outside `etabli` and vendored in, so every harness
sees the same content and a fresh clone deploys a complete surface.

## Manifest

`sources.tsv` is the source of truth: one line per upstream, listing the repo,
the tracked ref, the deploy scope, and the exact skills to vendor. Each vendored
tree carries an `UPSTREAM_SHA` file with the commit it was taken from.

| Vendor | Upstream | Scope | Skills |
|---|---|---|---|
| `pstack` | `cursor/plugins` (`pstack/` subpath) | `shared` | 30 — task skills, poteto-mode, principles (see `docs/pstack-strategy.md`, ADR-0020, ADR-0021) |
| `ember-skills` | `Tonours/ember-skills` (private) | `work` | 13 — ForestAdmin Ember frontend |
| `adonisjs-skills` | `Tonours/adonisjs-skills` (private) | `personal` | 6 — AdonisJS 7 |

Generic language packs (mcollina) and React packs (vercel, tanstack) were
removed as unused surface. Full restore procedure for a dropped pack (all
inputs recoverable from git history — e.g.
`git show 18bc2f0^:vendor/sources.tsv`):

1. re-add the pack's row to `vendor/sources.tsv`;
2. re-add its skill rows to `workflow/runtime/skill-surface.tsv`;
3. run `scripts/sync-vendor-skills <pack>` (idempotent; refuses a dirty
   `vendor/` tree);
4. run `cd pi && bun run update:skills-lock`, review the diff, commit.

Scope follows `claude/README.md`: `shared` deploys everywhere, `work` and
`personal` only where the machine declares that scope in `~/.etabli-scope`.

## Syncing

```bash
scripts/sync-vendor-skills                  # every vendor
scripts/sync-vendor-skills pstack           # one vendor
```

The script refuses to run while `vendor/` has uncommitted changes, so a
forgotten local edit surfaces instead of being silently overwritten. It rewrites
each `UPSTREAM_SHA`, then prints a diffstat to review before committing.

The private repos clone over SSH. `gh`'s OAuth token can list them but cannot
read their contents, so HTTPS fails with a misleading 404.

After a vendor sync, refresh `skills-lock.json` so the lock matches the
vendored trees:

```bash
cd pi && bun run update:skills-lock
```

`bun run verify:skills` is the read-only check used by
`scripts/verify-agentic-infra`.

## Upstream is the source of truth

Never hand-edit a file under `<vendor>/skills/`. A local fix drifts silently and
the next sync overwrites it. Fix it upstream and re-sync, or fork the skill into
`claude/scopes/` under a different name.

This rule has already been paid for once: three `ember-skills` descriptions had
an unquoted `: ` in their YAML frontmatter, which truncates the description at
the colon and strips the trigger keywords an agent matches on. The fix lived only
in `etabli` until it was pushed upstream as `aa6ed23`.
