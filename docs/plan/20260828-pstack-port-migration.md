# Implemented: pstack migrated to @zenspc/pi-pstack (Pi focus)

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — Migrate pstack from vendored layer to @zenspc/pi-pstack (Pi focus)
- Source plan SHA-256: `c9cbc8f63c24ef3e2c4803128637cadcd4de4b033938e84478fb7ee53cf9ed71`
- Status: IMPLEMENTED
- Commits: surface removal per ADR-0023, lock prune, docs rewrite,
  code-quality leaf repoint (base `main` @ `fbf39d4`)

## Outcome

- `@zenspc/pi-pstack` 0.3.0 + `pi-subagents` 0.59.0 installed (packages
  registered in pi settings; 45 skills + 2 subagents + extension live via
  the package manifest, outside the etabli catalog).
- Vendored surface fully removed: 37 catalog rows, manifest row,
  `vendor/pstack/**` (git history is the rollback), links on all three
  runtimes, and — discovered during removal — **pre-existing real-dir
  copies on the Pi surface dated Aug 20** that predate the session: the
  wave-1/2 `ln -sfn` commands had nested inside them (the classic
  ln-on-existing-dir footgun) and the `test -d` post-checks passed
  vacuously. All 37 removed with `rm -rf`.
- 37 lock entries pruned by direct lock edit (`--write` never removes —
  recorded as a tooling limitation); 66 hashes verify green.
- Docs: `docs/pstack-strategy.md` rewritten as migration record + port
  operation notes (`/setup-pstack`, `/pstack off`, models.json,
  `/skill:` syntax); `docs/vendor-skills.md` and README rows updated.
- `pi/skills/code-quality` TypeScript row repointed to the vendored
  mattpocock `codebase-design` leaf (link-name resolution) with pstack
  principles as port prose — the docs-smoke direct-leaf invariants forced
  the precise phrasing (three iterations: no leaves → unresolvable leaf →
  correct link name).

## Decisions

- Migration per user directive; multi-runtime pstack explicitly
  deprioritized (ADR-0023 records the trade and the rollback).
- Vendoring mechanism kept — serves mattpocock; mechanism ≠ policy.

## Accepted Drift

- The Aug-20 real-dir discovery revealed wave-1/2 "live links verified"
  claims were partially vacuous on the Pi surface — the port install makes
  the question moot, but the verification lesson stands: `test -d` on a
  link path proves nothing about what created it; use `readlink`.

## Validation Evidence

- `scripts/verify-agentic-infra full` → **74/74**
- `node scripts/validate-adrs .` → ok, 23 records · lock verify 66 green
- Port + peer present in pi settings; pstack skills resolve from the
  package; Pi skill dir at 95 entries (no duplicates)
- Logic hunter: **No findings, GO**; Spec parent clean.

## Follow-up State

- The user's pstack test period now applies to the port (`/skill:poteto-mode`,
  `/setup-pstack`, `/pstack off`).
- Rollback path (if the port disappoints): restore catalog rows + manifest
  row from git history, re-sync, re-link (ADR-0023).
- Next links: ADR-0023, `docs/pstack-strategy.md`, `docs/vendor-skills.md`.
