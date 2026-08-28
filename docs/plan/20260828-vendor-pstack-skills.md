# Implemented: pstack wave-1 task skills vendored into etabli

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — Vendor pstack wave-1 task skills into etabli (Pi-first, additive)
- Source plan SHA-256: `e18b89d2576713a29851dc81f19f8dd024c094c52c811be51f3720f4aa9f7dd3`
- Status: IMPLEMENTED
- Commit / branch: `feat/vendor-pstack-skills` @ `1d1d7aa` (base `main` @ `9409527`)

## Outcome

- Eight pstack skills (`how`, `why`, `architect`, `blast-radius`, `tdd`,
  `interrogate`, `create-verification-skill`, `maintain-verification-skill`)
  vendored verbatim from `cursor/plugins` @ `397c8660da6d` and deployed via
  catalog rows (`source=pstack`, `0 0 1`) to `~/.pi/agent/skills`,
  `~/.claude/skills`, `~/.codex/skills` (live links created and verified).
- `scripts/sync-vendor-skills` gained an optional 6th `subpath` manifest
  column (backward compatible) plus subpath-scoped license copying, covered by
  a hermetic smoke test (`tests/sync-vendor-subpath-smoke.sh`).
- Decision recorded in ADR-0020; operational map in `docs/pstack-strategy.md`.
- Etabli workflow contract, existing skills, and `install-main.sh` untouched.

## Context

- User asked whether to drop etabli for pstack; analysis found ~30-40%
  overlap (task-skill layer only) and recommended vendoring instead of
  migration (ADR-0020 rejected alternatives).
- A previously blocked Grok-hygiene plan occupied the single-plan slot; it hit
  its own documented escalation (`grok inspect` ignores `[plugins].disabled`
  for Claude-compat plugins) and was discarded with a record before this run.

## Decisions

### Vendor cursor/plugins monorepo with a subpath column

- Context: pstack skills live under `pstack/skills/`, not a root `skills/`.
- Choice: optional `subpath` column in `vendor/sources.tsv`, empty = legacy
  root layout; license copied from the subpath when it ships one, root
  fallback only when the subpath ships neither.
- Rejected options: forking pstack; depending on the 0-star `pi-pstack` npm
  port; editing vendored files.
- Rationale: upstream provenance + etabli's governed vendor/catalog surface.
- Consequences: upstream layout drift fails sync closed; `UPSTREAM_SHA` pins
  snapshots.

### agents_visible=0 for pstack rows

- Context: Grok and Cursor already run pstack natively.
- Choice: catalog flags `0 0 1` (vendor loop deploys; `~/.agents` skipped).
- Rationale: no duplicate catalogs on the Grok surface.

## Accepted Drift

- Original plan/spec: subpath documented as `plugins/pstack`.
- Implemented reality: `pstack` (monorepo root) — first sync attempt failed
  closed, manifest corrected, ADR text fixed after Logic-hunter finding.
- Why accepted: fail-closed behavior proved the mechanism; both docs and
  manifest now agree on `pstack`.

## Validation Evidence

- command: `bash tests/sync-vendor-subpath-smoke.sh`
  - result: PASS (both layouts, license mixing guard, dirty refusal, missing-skill refusal)
- command: `scripts/verify-agentic-infra core`
  - result: 18/18 passed (after skills-lock refresh via `bun run update:skills-lock`)
- command: `bun test pi/extensions/__tests__/`
  - result: 242 pass, 0 fail
- command: `node scripts/validate-adrs .`
  - result: ok, 20 records
- command: frontmatter `name:` check over 8 vendored SKILL.md
  - result: 8/8 present, matching directory names
- review: Logic hunter (fresh-context pi child) verdict GO WITH NOTES — 3
  findings (ADR subpath contradiction, license root-fallback mixing,
  `.cursor/skills/` output path undeclared) all accepted, fixed, rechecked;
  Spec hunter in parent (Daily Pi exception), one finding folded; deciding-code
  table complete.

## Follow-up State

- Remaining risks: Cursor-specific prose degrades to single-model behavior on
  Pi (documented in `docs/pstack-strategy.md`); `disable-model-invocation`
  frontmatter may be ignored outside Cursor/Claude.
- Parking lot: wave-2 menu (21 principles, playbooks, poteto-mode,
  arena/swarm) — manifest + catalog-flag flip, gated by a follow-up ADR.
- Ledger hygiene: stale non-terminal `herdr-claude-relaunch` ledger (its plan
  was discarded 2026-08-26) was tripping `ambiguous_active_ledgers`; closed
  with a `blocked` terminal event during this run.
- Unrelated leftover for the user: merge `chore/grok-surface-hygiene`
  (`.mcp.json` brain removal) — see
  `docs/plan/20260828-discarded-blocked-grok-plugin-gate.md`.
- Next links: `docs/pstack-strategy.md`, ADR-0020.
