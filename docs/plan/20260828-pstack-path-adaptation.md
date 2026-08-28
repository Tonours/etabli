# Implemented: pstack path adaptation — .cursor skill surfaces → .claude

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — pstack path adaptation — .cursor skill surfaces → .claude at sync time
- Source plan SHA-256: `4014c232819bd6826ed4f0bee032dc000a174a59c3afa4e0bb2165c688a04adb`
- Status: IMPLEMENTED
- Commits: adaptation layer + smoke, pstack re-sync + ADR-0022 + docs, lock
  refresh (base `main` @ `59b6bd0`)

## Outcome

- `scripts/sync-vendor-skills` applies a declared post-copy adaptation
  table (ADR-0022): `.cursor/skills/` → `.claude/skills/`,
  `.cursor/plugins/` → `.claude/plugins/` — substring form covers `~/`
  variants; the table lives in the script, so adaptations survive every
  re-sync (the reason a one-off edit was rejected).
- pstack re-synced: **10 occurrences rewritten** (create-verification ×3,
  maintain ×1, automate-me ×3, reflect reviewers ×3); **9 intentional
  remainders** (transcript globs `~/.cursor/projects/`, the
  `~/.cursor/rules/pstack-models.mdc` config interrogate reads as plain
  text, `.cursor/worktrees/`) — zero unexpected. Plan predicted 7
  remainders; actual 9, same categories (miscount, corrected here).
- Smoke asserts the transform (fixture text in, `.claude` out, zero
  `.cursor/skills` surviving).
- `docs/pstack-strategy.md`: the verify-`<app>` caveat now points at
  `.claude/skills/` with Pi's documented bridge — project
  `.pi/settings.json` → `{ "skills": ["../.claude/skills"] }` (pi
  docs/skills.md:57 pattern; Pi's native project surfaces are
  `.pi/skills/` and `.agents/skills/`, not `.claude`).
- ADR-0022 amends the vendored-verbatim rule: verbatim except the declared
  sync-time path-adaptation table.
- mattpocock tree untouched (zero `.cursor` refs).

## Decisions

- `.claude` as the single deterministic target (user asked "`.pi` ou
  `.claude` selon le runtime"): it is Claude's native project-local and
  user surface AND the target of Pi's own documented bridge; runtime-
  conditional prose was rejected as non-deterministic under sed.
- Transcript/config/worktree references stay verbatim — they are Cursor
  facts; transforming them would falsify semantics rather than adapt.

## Validation Evidence

- `bash tests/sync-vendor-subpath-smoke.sh` → PASS (incl. transform
  assertion)
- `scripts/verify-agentic-infra full` → **74/74** (after lock refresh)
- `node scripts/validate-adrs .` → ok, 22 records
- grep: transformable=0, unexpected=0, intentional remainders=9
- Logic hunter: GO WITH NOTES, empty findings section; Spec parent clean.

## Follow-up State

- Future adaptations extend the table with an ADR reference — never
  hand-edit vendored files.
- Next links: ADR-0022, `docs/pstack-strategy.md`, `docs/vendor-skills.md`.
