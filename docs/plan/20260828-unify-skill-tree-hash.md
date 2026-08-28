# Implemented: unified skill-tree hashing and license-copy helper

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — Apply thermo-nuclear review fixes — unify skill-tree hashing, simplify license copy
- Source plan SHA-256: `53c4ca1d7629931902520d1b7cf3a7388b556d4cb0906af3f81b098260e2ecf7`
- Status: IMPLEMENTED
- Commit / branch: `fix/unify-skill-tree-hash` @ `c126d07` (base `main` @ `a0eee9a`)

## Outcome

- BLOCKER closed: `scripts/lib/skill-tree-hash.mjs` is now the single
  skill-tree hasher, imported by both the skills-lock updater
  (`pi/scripts/verify-skills-lock.mjs`, whose `files`/`isHashable`/
  `UNHASHED_ENTRIES`/`hashSkill` internals are deleted) and the runtime
  skill canary (`scripts/lib/runtime-skill-canary.mjs`, local
  `hashDirectory` deleted). One exclusion set, forward-slash normalization,
  explicit in-tree symlink rejection (`lstat`, never `stat` — a followed
  stat cannot report the symlink it must reject).
- HIGH closed: `sync-vendor-skills` license copy is one
  `copy_first_license` helper (first match, no flag) with subpath→root
  precedence, symmetric at both levels.
- LOW closed: slug-domain comment on the skill-catalog grep; SC2034
  underscore renames in `skill_catalog_vendor_records` (pre-existing,
  surfaced by this turn's lint gate; sibling convention per
  `install-main.sh:1630`).
- `tests/skill-tree-hash-smoke.sh` pins the semantics: pollution
  equivalence (clean tree digest == polluted digest with `node_modules`
  incl. a symlinked `.bin`, `.DS_Store`, `*.pyc`, install key, caches) and
  the explicit symlink throw.

## Context

- The thermo-nuclear review of waves 1+2 flagged the twin hashers as its
  only blocker: the updater excluded `.DS_Store`/caches/`*.pyc` while the
  canary did not, and normalized path separators the canary ignored — a
  `.DS_Store` in any skill dir would make the two lock surfaces disagree
  permanently with no test catching it.

## Decisions

### One hasher module, property test over golden digest

- Context: two implementations that must agree, with no mechanical link.
- Choice: shared module + pollution-equivalence property smoke; digest
  compatibility proven by `verify-agentic-infra core` passing 18/18 with
  `skills-lock.json` byte-unchanged (the construction is the old updater's,
  which was the canonical digest).
- Rejected: twin-comment synchronization (keeps two implementations — the
  review's exact finding); golden-digest constant (brittle to fixture
  edits).
- Consequences: future exclusion changes land in exactly one file; the
  canary's symlink throw now also applies to the updater side (previously
  an accidental follow/crash split); no current tree has in-tree symlinks
  (only `pi/skills/herdr`, a top-level dir-target symlink, followed by
  `readdir` before any lstat — unchanged).

### Implementation self-catch

- During the rewrite the shared module briefly used `statSync`, which would
  have made the symlink rejection dead code (a followed stat never reports
  symlink). Caught and fixed to `lstatSync` with a comment before any
  review ran.

## Accepted Drift

- Original plan/spec: none material. The SC2034 renames were outside the
  plan's file list but were a hard lint blocker on an edited file; minimal
  and convention-matching.
- Why accepted: turn-lint gate requires clean files it dispatches.

## Validation Evidence

- command: `bash tests/skill-tree-hash-smoke.sh`
  - result: PASS
- command: `bash tests/sync-vendor-subpath-smoke.sh`
  - result: PASS (license precedence still holds; both-licenses case now
    deterministic first-match)
- command: `bash tests/skill-catalog-name-smoke.sh`
  - result: PASS
- command: `bash tests/runtime-skill-canary-smoke.sh`
  - result: ok
- command: `scripts/verify-agentic-infra core`
  - result: 18/18; `git diff --quiet -- skills-lock.json` clean
- command: `bun test pi/extensions/__tests__/`
  - result: 242 pass, 0 fail
- review: Logic hunter (fresh child) **GO, zero findings**; cross-model
  adversary `zai/glm-5.3` (high-risk 13b) **GO, zero findings**; Spec
  hunter parent clean; deciding-code tables complete on both hunters.

## Follow-up State

- Remaining risks: none identified; both hunters returned clean tables.
- Net diff: +172 / −97 lines while deleting an entire duplicate
  implementation.
- Next links: ADR-0021, `docs/pstack-strategy.md`,
  `tests/skill-tree-hash-smoke.sh`.
