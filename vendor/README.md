# vendor/

You get skill libraries maintained outside `etabli`, copied in so every harness
sees the same content and a fresh clone deploys a complete surface.

## Manifest

`sources.tsv` is the source of truth: one line per upstream, listing the repo,
the tracked ref, the deploy scope, and the exact skills to vendor. Each vendored
tree carries an `UPSTREAM_SHA` file with the commit it was taken from.

| Vendor | Upstream | Scope | Skills |
|---|---|---|---|
| `mattpocock` | `mattpocock/skills` | `shared` | 8 — engineering pack plus `productivity/grilling` (below) |
| `petergyang` | `petergyang/no-ai-slop` | `shared` | 1 — `no-ai-slop`, AI-slop editing pass |
| `typesafe-ai` | `typesafe-ai/skills` | `shared` | 1 — `typesafe-ai`, build with TypeSafe System One (Jev) |
| `cloudflare` | `cloudflare/security-audit-skill` | `shared` | 1 — `security-audit`, six-phase audit with fresh verifier agents; run on GLM by `security-audit-glm` |

Pi gets a vendored skill only when its `workflow/runtime/skill-surface.tsv`
row sets `pi_core=1`; no vendored row does today. Claude visibility follows
`claude/settings.skill-overrides.json`.

To restore a dropped pack, take its rows from git history (for example
`git show 18bc2f0^:vendor/sources.tsv`), then:

1. re-add the pack's row to `vendor/sources.tsv`;
2. re-add its skill rows to `workflow/runtime/skill-surface.tsv`;
3. run `scripts/sync-vendor-skills <pack>` (idempotent; refuses a dirty
   `vendor/` tree);
4. run `cd pi && bun run update:skills-lock`, review the diff, commit.

Scope follows `claude/README.md`: `shared` deploys everywhere, `work` and
`personal` only where the machine declares that scope in `~/.etabli-scope`.

## mattpocock pack

`codebase-design`, `domain-modeling`, `grill-with-docs`,
`improve-codebase-architecture`, `prototype`, `research`, `wizard`, plus
`productivity/grilling`, which `grill-with-docs` calls with `domain-modeling`.
Catalog rows use the upstream path (`engineering/<name>`); the skills deploy
under their frontmatter names.

Skipped on purpose, so each name has one owner:

- `engineering/code-review` → etabli's `review` route (`workflow/skills/review.md`).
- `engineering/implement` → etabli's `implement` route.
- `engineering/setup-matt-pocock-skills` → configures the suite's own installer
  conventions; etabli's vendoring replaces it.

Under etabli, suite references to skipped or dropped names resolve to the etabli
equivalents, and the suite's own repo conventions degrade to Linear plus
`workflow/`. `research` delegates reading to a background agent; parent-only Pi
runs it as sequential reads. The etabli routes own gating and evidence; vendored
skills are task-level entry points (repo research under the etabli contract
stays `workflow/skills/investigation.md`).

## Updating

```bash
scripts/update-vendor-skills                 # every vendor, review then commit
scripts/update-vendor-skills mattpocock      # one vendor
```

One step: it runs `scripts/sync-vendor-skills`, refreshes `skills-lock.json`,
runs `verify:skills` and both skill load checks, then prints each vendor whose
`UPSTREAM_SHA` moved with a GitHub compare link to read the upstream changes.
It exits early when nothing moved. Deploy afterwards
(`scripts/deploy-agent-workflow --apply`) so the live surfaces pick it up.

`scripts/sync-vendor-skills` alone refuses to run while `vendor/` has
uncommitted changes, so a forgotten local edit surfaces instead of being
silently overwritten. `bun run verify:skills` is the read-only check used by
`scripts/verify-agentic-infra`.

## Upstream is the source of truth

Never hand-edit a file under `<vendor>/skills/`. A local fix drifts silently and
the next sync overwrites it. Fix it upstream and re-sync, or fork the skill into
`skills/<scope>/` under a different name.
