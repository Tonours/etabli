# Implemented: Claude skill index under an enforced budget (15 109 → 6 141 model-facing chars, gate 6 510)

## Metadata

- Archived: 2026-08-30
- Source plan: `PLAN.md` — put Claude's always-on skill index under an enforced budget using the native `skillOverrides` setting, and register the skill-load gates in CI
- Source plan SHA-256: `1f8fbcd2ada3a73f9d44de1f285cb751982586c4131ca35d8b79cd4aa8f6fff4`
- Status: IMPLEMENTED
- Commit / branch: uncommitted working tree on `main`

## Outcome

- Claude's model-facing skill index: **75 indexed skills / 15 109 chars
  (~3 777 tok) → 24 skills / 6 141 chars (~1 535 tok)**, a 59 % cut,
  measured folded-aware (`len(name)+len(description)+20` per listed entry).
- Mechanism: tracked exhaustive 84-key map
  (`claude/settings.skill-overrides.json`: 24 `on`, 60
  `user-invocable-only`) synced into `~/.claude/settings.json` by an atomic
  fail-closed merge (`scripts/lib/claude-settings-sync.mjs`), wired into
  `deploy_claude` and `install-main.sh`. Hidden skills stay user-invocable
  via `/name`.
- New gate `scripts/claude-skill-load-check`: index ≤ 6 510 (alert 6 490,
  name-only chars folded in), exhaustive bidirectional partition,
  pinned 24-name on-set failing both directions, pinned state histogram
  (24/60/0/0), zero danglings, zero `skills.disabled` links (both levels,
  readlink+realpath), repo/live map equality, no enabled plugin shipping
  `SKILL.md` (recursive scan, depth 5). Deployer hard-fails post-apply;
  installer runs it warn-only after linking (recorded decision).
- `tests/pi-skill-load-check-smoke.sh` (previously orphaned) and the new
  `tests/claude-skill-load-check-smoke.sh` are CI rows under
  `full/shell-docs`, pinned in the manifest smoke.
- Retired `~/.claude/skills/audit` link removed (content stays archived);
  deployer owns the removal and runs it before the gate.

## Context

- `skillOverrides` semantics verified from the Claude Code 2.1.241 binary:
  user-scope `~/.claude/settings.json` is a read source (A1); hidden from
  model + `/name` kept (A2); the runtime hides on
  `disableModelInvocation || settingsState-hidden` — an independent OR, so
  settings `on` cannot clear frontmatter dmi (A3 refuted).
- Consequence: the mattpocock router `ask-matt` (dmi) cannot be promoted;
  the mattpocock fold was abandoned — the 7 visible specialists stay
  indexed as entry points, `ask-matt` stays a user-side router.
- 9 skills already self-hide via dmi; keep-set = 15 indexed
  `claude/scopes` skills + `herdr` + `ember-employer-suite` (12
  specialists folded behind it, model-side path becomes file-read-based)
  - 7 mattpocock specialists.

## Decisions

### Hide via settings, never via link deletion

- Context: 41 unmanaged surface entries (17 `.agents` mirrors, 19 tanstack
  external links, 4 content-bearing realdirs, 1 retired audit link).
- Choice: `skillOverrides` map keyed by name.
- Rejected: deleting symlinks (irreversible for realdirs, non-convergent
  for links this repo does not create) ; editing vendored frontmatter
  (hash-locked) ; a `claude_visible` catalog column (leaves the 41
  ungoverned; pi's flat deny-list shape is the precedent).
- Rationale: idempotent against unknown writers, content-preserving,
  lock-safe.

### Exhaustive map, pinned on-set, pinned histogram

- Context: adversary rounds showed keep-by-absence and unpinned state
  counts let silent drift pass.
- Choice: all 84 discovered names carry explicit states; the check pins
  the 24-name on-set and the 24/60/0/0 histogram; stale keys fail
  (pi B2(ii) precedent — no tombstones).
- Consequences: any map amendment requires the CHALLENGED demotion rule.

### Folded-aware metric

- Context: two keepers use YAML `>-` descriptions; a one-line parser
  undercounted by 541 chars and the gate was initially pinned on the
  wrong number.
- Choice: `descriptionOf` parses folded scalars including blank lines; the
  gate was re-pinned 5 950 → 6 510 on the corrected measurement.

## Validation Evidence

- command: `scripts/claude-skill-load-check`
  - result: ok — `index_chars=6141 discovered=84 on_set=24 pinned=24 map_keys=84`
- command: `scripts/pi-skill-load-check`
  - result: ok — `model_block_chars=6780` (gate 7 190, unchanged)
- command: `scripts/verify-agentic-infra full`
  - result: 76/76 checks passed (includes both new smoke rows)
- command: `cd pi && bun test extensions/__tests__/ && bun run verify:skills`
  - result: 254 pass / 0 fail; 66 hashes verified
- command: `node scripts/validate-adrs .`
  - result: ok, 23 records
- command: `scripts/deploy-agent-workflow --apply` (twice)
  - result: idempotent; second run no-change; post-apply gate ok;
    regression-proven: recreating the retired audit link → removal then
    gate green (no dead-code cleanup path)
- command: `bash tests/claude-skill-load-check-smoke.sh`
  - result: PASS — pass case (nested `synced/`, `.DS_Store`) plus 8
    failure modes (ungoverned, keeper-dmi, dangling, skills.disabled,
    budget, beyond-pinned, plugin-ships-skills, repo/live divergence)
- `simplify: clean` (one strengthening added: state-value validation);
  `quality: shell+js | mechanical fixed: 0 | findings: 0 | status: clean`
  (shellcheck unavailable on host; bash -n green; sibling-anchored)

## Review evidence

- Plan-mode adversary: cross-model `openai-codex/gpt-5.6-sol` max thinking
  (fresh context, read-only) — VERDICT BLOCK, 14 findings, all folded
  (one partial); none rejected at plan level.
- Logic hunter (fresh context, default model): BLOCK — 3 findings, all
  accepted and fixed (gate-before-removal ordering with
  regression proof; nested skills.disabled hole; recursive-prose vs
  two-level reality).
- Spec hunter (fresh context): GO WITH NOTES — 1 dismissed (pi smoke
  pre-exists), 2 acted (installer asymmetry recorded; name-only chars
  gated).
- Code-diff adversary round 1 (gpt-5.6-sol:max): BLOCK — 7 accepted and
  fixed (fresh-machine gate ordering, folded-YAML undercount + gate
  re-pin, installer ordering, `constructor` prototype escape,
  symlink-chain detection, array-local rejection, C6 SKILL.md precision);
  1 rejected with evidence (descending into skill dirs).
- Code-diff adversary round 2 (gpt-5.6-sol:max): BLOCK — 6 hardening
  findings, 5 accepted and fixed (state histogram, `true # comment` dmi,
  blank lines in folded scalars, unreadable SKILL.md, plugin scan depth,
  mode preservation); 1 rejected (same skill-dir rationale).
- Rounds stopped at 2 per the 2 h operational budget (long-loop
  discipline); deciding-code tables complete on all runtime rows.

## Follow-up State

- Pending (external): live `claude -p` probes — OAuth session expired;
  re-auth then run the slice-1 probe set to confirm A1/A2 end-to-end and
  evidence AC4 (`/name` on a hidden skill) and A5 (file-read load of a
  hidden specialist). Static binary evidence already covers the
  semantics; the gate does not depend on it.
- Remaining risks: project-scope `.claude/settings.local.json` can shadow
  the user-scope map per-project (documented choice); further adversary
  hardening surface exists (YAML edge cases beyond comments/blank lines,
  plugin manifest-declared skill paths) — recorded, not chased.
- Next lever if more cuts are wanted: the Codex surface (47 skills) and
  `~/.agents`/Grok (48) have no equivalent lever documented; separate
  plan.
