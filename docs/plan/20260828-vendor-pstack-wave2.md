# Implemented: pstack wave-2 — poteto-mode, playbooks, and 21 principles vendored

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — Vendor pstack wave-2 — poteto-mode (with inline playbooks) and 21 principles
- Source plan SHA-256: `07f3312932633c7274813c2ea720039bac1c55d563598a309ddea227a4782765`
- Status: IMPLEMENTED
- Commit / branch: `feat/vendor-pstack-wave2` @ `6f65889` (base `main` @ `754b38b`)

## Outcome

- `poteto-mode` (23 playbooks inline) and the 21 `principle-*` skills vendored
  from the same snapshot `397c8660da6d` (upstream unmoved since wave-1 —
  purely additive tree). 30 pstack skills total in `vendor/sources.tsv`.
- 22 catalog rows (`source=pstack`, `0 0 1`); skills-lock refreshed
  (additive); live links verified 22/22 on Pi, Claude, Codex.
- `scripts/lib/skill-catalog.sh`: `skill_declared_name` falls back to the
  directory basename when the declared `name:` is not a valid slug
  (`^[a-z0-9][a-z0-9-]*$`) — poteto-mode declares `Poteto Mode`; covered by
  `tests/skill-catalog-name-smoke.sh`.
- `hashDirectory` (runtime-skill-canary.mjs) and
  `pi/scripts/verify-skills-lock.mjs` both exclude generated install
  artifacts (`node_modules`, `.poteto-mode-tools-install-key`) so
  poteto-mode's self-installing helper scripts cannot drift the pinned lock
  hash on first use.
- ADR-0021 records the adoption (user-directed, ahead of ADR-0020's coverage
  gate, superseding its rejection #3); `docs/pstack-strategy.md` carries the
  deployment table, opt-in semantics, full dangling-reference inventory, and
  the wave-3 menu.

## Context

- User reviewed the wave-1 landing and directed wave-2 explicitly
  (poteto-mode, playbooks, principles), plus deletion of the two merged
  local branches (done first: `feat/vendor-pstack-skills`,
  `chore/grok-surface-hygiene`).

## Decisions

### Slug-validation fallback instead of manual or adapter links

- Context: poteto-mode's declared name is `Poteto Mode` — the vendor loop
  links by declared name; a space-bearing link breaks on Claude/Codex and
  degrades on Pi.
- Choice: basename fallback for non-slug declarations in the shared catalog
  helper.
- Rejected: catalog-less manual link (invisible to lock/canary, not
  reproducible on new machines — prune only removes dead targets, so it
  would survive but orphaned); thin adapter skill (symlink-relative path
  resolution fragile cross-machine).
- Consequences: installer-lib touch → high-risk tier → cross-model
  adversary run (see below).

### Exclude generated artifacts from lock hashes

- Context: cross-model adversary found poteto-mode's `scripts/bootstrap.ts`
  runs `bun install --frozen-lockfile` inside the vendored tree on first
  helper use (watch-pr, orch), writing `node_modules/` and an install-key
  marker that the whole-directory lock hash would pin or throw on
  (symlinks in `node_modules/.bin`).
- Choice: exclusion sets in both hashers (updater already excluded
  `node_modules`; canary aligned, both exclude the install key).
- Rejected: editing the vendored bootstrap (verbatim rule).
- Consequences: no lock regeneration needed (trees contain no generated
  artifacts); running the helper scripts still dirties the vendor tree with
  untracked files until the next sync (`rm -rf` + re-copy self-heals).

## Accepted Drift

- Original plan/spec: tier standard, sync-script-only surfaces.
- Implemented reality: tier high-risk — `skill-catalog.sh`,
  `runtime-skill-canary.mjs`, `pi/scripts/verify-skills-lock.mjs` touched
  (adversary folds), plus 3 doc count fixes (wave-3 list names 15 not 14;
  23 playbooks not 22; setup-pstack added to the ADR inventory).
- Why accepted: each fold traces to a verified review finding; plan updated
  in place; READY held.

## Validation Evidence

- command: `bash tests/skill-catalog-name-smoke.sh`
  - result: PASS (kebab kept, display/space/missing fall back, quoted kept)
- command: `bash tests/sync-vendor-subpath-smoke.sh`
  - result: PASS
- command: `scripts/sync-vendor-skills pstack`
  - result: 30 skills at `397c8660da6d` (same SHA as wave-1; additive only)
- command: `node scripts/validate-adrs .`
  - result: ok, 21 records
- command: `scripts/verify-agentic-infra core`
  - result: 18/18 (re-run green after every fold)
- command: `bun test pi/extensions/__tests__/`
  - result: 242 pass, 0 fail
- review: Logic hunter (default family, fresh child) GO WITH NOTES — 3
  doc-inventory findings fixed; cross-model adversary `zai/glm-5.3`
  (high-risk 13b) GO WITH NOTES — 1 medium hash-drift finding fixed;
  Spec hunter parent — 1 incomplete post-check finding closed (22/22 links
  verified); deciding-code tables complete on both hunters.

## Follow-up State

- Remaining risks: catalog +22 on three surfaces (Pi ~103 entries) —
  reversible per row; poteto-mode opt-in semantics rest on
  `disable-model-invocation` plus user habit; `reminder:` field is a
  residual self-trigger vector outside Cursor (documented in ADR-0021).
- Deliberate no-new-unit-test: hash exclusion mirrors the sibling
  UNHASHED_ENTRIES pattern; `hashDirectory` is unexported; end-to-end
  skill-lock check exercises the updater.
- Parking lot: wave-3 menu (15 remaining skills) in `docs/pstack-strategy.md`.
- Next links: `docs/pstack-strategy.md`, ADR-0021, ADR-0020.
