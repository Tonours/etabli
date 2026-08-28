# Implemented: Matt Pocock engineering suite vendored (14 skills)

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — Vendor Matt Pocock engineering skill suite (14 skills)
- Source plan SHA-256: `e6b642cc40d434718101a3163161e90f54ce0945d1f72c7165dbc00634e62bb2`
- Status: IMPLEMENTED
- Commits: manifest row `feat(vendor)`, sync `d06b0d2`, catalog+docs, three
  baseline-bump test commits (base `main` @ `bb19578`)

## Outcome

- `vendor/mattpocock/skills/engineering/` — 14 skills synced verbatim from
  `mattpocock/skills` @ `main` (MIT): ask-matt, codebase-design,
  diagnosing-bugs, domain-modeling, grill-with-docs,
  improve-codebase-architecture, prototype, research,
  resolving-merge-conflicts, to-spec, to-tickets, triage, wayfinder,
  wizard. Nested names (`engineering/<name>`) supported by a one-line
  `mkdir -p` in `sync-vendor-skills`, covered by a new `nested/one`
  fixture in the subpath smoke.
- 14 catalog rows `source=mattpocock` `0 0 1`; lock refreshed; links live
  on Pi/Claude/Codex.
- `docs/vendor-skills.md` maps all three suites, the collision rules, and
  the update procedure; README vendor row points to it.
- Skipped with reasons: `engineering/code-review`, `engineering/implement`,
  `engineering/tdd` (name collisions — etabli/pstack canonicals),
  `engineering/setup-matt-pocock-skills` (no target under etabli
  vendoring).

## Decisions

- **One canonical owner per skill name**: colliding upstream skills are
  skipped, not aliased — aliasing/prefixing adds catalog noise for no
  clarity.
- **Catalog baselines raised deliberately** (total 95→120, pi_core 17→20,
  agents_visible 17→20, pi_core description bytes 1600→2000,
  agents_visible 1850→2200) with rationale comments: the caps exist to
  force exactly this moment on suite adoption.

## Accepted Drift

- Original plan/spec: checks listed core only.
- Implemented reality: the Logic hunter's deciding-code table caught the
  catalog-size cap (workflow-docs-smoke, profile `full`) blown by the
  cumulative thermo+unslop+mattpocock additions — my per-cycle core-only
  gating never executed it. Fixed by the deliberate bumps + a full-profile
  run.
- Why accepted: the caps did their job; the miss was gate selection, now
  recorded. Skill-surface changes gate on `full` from here on.

## Validation Evidence

- `scripts/verify-agentic-infra full` → **74/74** (after bumps)
- `scripts/verify-agentic-infra core` → 18/18 · `bun test` → 242 pass
- `bash tests/sync-vendor-subpath-smoke.sh` → PASS (incl. nested fixture)
- `node scripts/validate-adrs .` → ok · `bash scripts/fix-links` → 0 issues
- frontmatter names: 14/14 valid slugs
- Logic hunter: GO WITH NOTES — the one deciding-code FAIL (catalog cap)
  folded and fixed; Spec parent clean.

## Follow-up State

- Wave-3 pstack planning queued (separate plan).
- The productivity/misc mattpocock tiers remain unvendored (unasked).
- Next links: `docs/vendor-skills.md`, `docs/pstack-strategy.md`.
