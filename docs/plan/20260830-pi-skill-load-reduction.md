# Implemented: pi skill load reduction (47 706 → 6 780 model-facing chars) and discovery-surface hygiene

## Metadata

- Archived: 2026-08-30
- Source plan: `PLAN.md` — pi skill load reduction and discovery-surface hygiene (missions A + B, recalibrated on the 2026-08-30 measured state)
- Source plan SHA-256: `6d2f0facf53cd16f1ac71578c560345c722a0e3bf8f06933ac49ee15cc358ea7`
- Status: IMPLEMENTED
- Commit / branch: uncommitted working tree on `main` (this record precedes the commit)

## Outcome

- Native skills block (model-facing, post-`/pstack off`): **47 706 → 6 780 chars**
  (gate 7 190, alert 7 175, headroom 410). Rendered manifest: 17 default-root
  keepers + 3 package keepers (github, commit, mcp-scripting) + 4
  extension-injected pi-lens skills.
- Post-change partition verified live: universe 53 = keep 17 + dmi 5 + deny 31.
- `pi_core` now governs vendor linking on the pi surface in BOTH
  `scripts/deploy-agent-workflow` and `scripts/check-fix-symlinks.sh`;
  four prune passes converge: managed, orphan (row vanished), vendor-pattern
  `*/<vendor>/skills/<name>` (covers flag-demoted rows, inactive scopes, and
  foreign checkouts of a catalog vendor), broken cross-surface mirrors.
- Live surfaces converged: mattpocock-14 + ember-13 + adonisjs-6 (incl. the
  foreign-checkout suite link) removed from pi; 25 dangling pi-root mirror
  links + multica-inbox + 12 paperasse links (agents+codex) removed; 7 stale
  Cursor realdirs deleted from the pi root (arena, bro, no-comments, recall,
  swarm, technical-writing, setup-pstack — they referenced `~/.cursor` paths
  and shadowed the Pi-native npm copies); grok launcher collision fixed.
- Settings: top-level `skills` deny-list (31 `!name` entries) + twelve explicit
  package entries (pstack bare-tracked, pi-subagents `skills: []` un-legacy'd
  and tracked); sync carries the `skills` key through the new shared
  `scripts/lib/pi-agent-settings-sync.mjs` (deployer + installer, DRY).
- ADR-0023 amendment records the install half; `/pstack off`
  (`skillsEnabled: false`, roles preserved) is the pinned standing state.
- New gate: `scripts/pi-skill-load-check` (native zero-cost dump via a
  `before_agent_start` extension that exits before the model call) asserting
  B1/B2/B3 every run; smoke-tested on fixtures.

## Context

- path/source: pi 0.84.4 `dist/core/package-manager.js` — top-level `skills`
  is an override list (default enabled, `!` excludes via parentName, `+`/`-`
  exact, precedence exclude → force-include → force-exclude, one array for
  both user roots); package `skills` key present → positive include (`[]`
  disables), absent → all enabled.
- path/source: `@zenspc/pi-pstack` 0.3.0 `extensions/pstack/` — `/pstack off`
  persists `skillsEnabled: false` in `~/.pi/agent/pstack/models.json` and
  strips by location prefix at render time; `/skill:<name>` keeps working.
- Drift that reshaped the v14 plan: 13/17 pinned deny names and omarchy had
  vanished; ~50 new entrants (pstack package, Cursor mirrors/realdirs,
  paperasse); measured block had tripled.

## Decisions

### Delegated round 5 (user: "tu peux tout faire")

- Context: v14 arithmetic invalidated by live drift; keep/deny rulings for new
  entrants were user-decision class.
- Choice: keep-20 under work scope (suite is scope-gated), deny-31 post-change
  complement, dmi on obsidian only (plus pinned 3), pstack hidden via its own
  toggle (not `skills: []`, preserving `/skill:<name>` per ADR-0023),
  pi-subagents kept as tracked peer, stale Cursor copies deleted,
  B4b probe repinned to bug-bounty.
- Rejected options: purging pi-subagents (breaks pstack fan-out — adversary
  #10 blocker); `skills: []` on pstack (kills `/skill:name`); pinning the
  33 to-be-unlinked vendor names in the deny-list (they leave the universe;
  `deny ⊆ universe` would fail).
- Rationale: honor ADR-0023's accepted direction and the absolute 7 190 gate
  with the levers pi actually exposes.
- Consequences: `/pstack off` is live state outside git (asserted by the
  checker); Cursor may re-create its copies (new names trip B2(ii) loudly).

### brave-search double lever

- Context: v14 pinned `git:…pi-skills` to `['brave-search']`, which would have
  let the package copy survive the name deny (latent gap).
- Choice: `skills: []` on that entry AND `!brave-search` in the deny-list.
- Rationale: both sources of the name must be closed for the hide to hold.

### pi-lens allow-set

- Context: pi-lens's four skills are injected by its extension, immune to the
  package `skills` filter (verified: they vanish under `-ne`).
- Choice: allow them in the checker; they stay inside the gate.
- Rationale: disabling the extension would kill the lens tooling; 4 skills
  (~1 k chars) fit the budget.

## Accepted Drift

- Original plan/spec: v15c projected landing ≈ 4 9xx–5 160.
- Implemented reality: 6 780 measured.
- Why accepted: the projection missed the extension-injected pi-lens skills
  (discovered at implementation); B1's absolute gate holds with 410 headroom.

## Validation Evidence

- command: `scripts/pi-skill-load-check`
  - result: ok — `model_block_chars=6780 entries=69 universe=53 deny=31 dmi=5
    pstack_entries=45`; manifest == expected; deny == complement; zero
    danglings; zero collisions; repo/live deny sync (pre-state 47 706/127)
- command: `scripts/deploy-agent-workflow --dry-run && scripts/check-fix-symlinks.sh`
  - result: dry-run clean (1 WOULD_SYNC only before apply; post-apply
    convergence OK) / Summary: 0 issue(s), exit 0
- command: `scripts/verify-agentic-infra full`
  - result: 74/74 checks passed
- command: `cd pi && bun test extensions/__tests__/`
  - result: 254 pass / 0 fail; `bun run verify:skills` 66/66 hashes
- command: `bash tests/vendor-prune-modes-smoke.sh`
  - result: PASS (gating, foreign checkout, mirror, orphan, non-vacuous
    row+tree dangling regression)
- command: probes (`--provider zai --model zai/glm-5.3`)
  - result: positives linear-ticket-create / plan-loop / adversary;
    negatives bug-bounty / deslop / brave-search → none visible;
    `--skill ~/.pi/agent/skills/bug-bounty` loads AND renders;
    `/skill:project-hunt` invoked natively (dmi keeps `/skill:name`)
- command: `scripts/runtime-skill-canary --skill runtime-skill-canary --json` ×5
  - result: offline_passed ×5 (outputs kept at /tmp/canary-{1..5}.out)
- command: `node scripts/validate-adrs .`
  - result: ok, 23 records

## Review evidence

- Logic hunter (`scripts/pi-review-hunter`, default model, fresh context):
  GO WITH NOTES — 3 findings (install-mode default-keep write trigger lost,
  pstack doc overclaim, package keepers matched by bare name); all three
  fixed and re-verified; deciding-code table complete on all four runtime rows.
- Spec hunter: `spec: parent` (Daily Pi exception) — all AC green at review
  time except B7 (ADR amendment, completed after).
- Code-diff adversary #11 (cross-model `openai-codex/gpt-5.6-sol`, no-tools,
  patch inline): BLOCK → arbitration: 2 HIGH rejected on mechanical evidence
  (`cd pi && bun run verify:skills` 66/66 — the code-quality edit preceded
  the lock regen; `git show HEAD:scripts/deploy-agent-workflow` proves the
  old code never linked vendors to `.agents` and zero vendor links survive
  there), 1 MEDIUM accepted+fixed (vacuous row+tree scenario), 1 MEDIUM
  rejected (vendor-pattern prune breadth = recorded delegated decision 12,
  triple match name+vendor-path+catalog-row), 1 LOW accepted+fixed
  (`--home` scope documented). Effective post-fold: GO WITH NOTES.
- Plan adversary lineage: v14 rounds 1–9 (106 findings), v15 refresh round
  (#10 sol, 10/10 accepted), code-diff #11 above.
- `simplify: clean` (shellcheck 0 on all changed scripts; 4 console.* advisories
  accepted — CLI output channel, sibling-consistent).
- `quality: shell+typescript | mechanical fixed: 0 | findings: 0 | status:
  clean` (code-quality skill, sibling comparison).

## Follow-up State

- Remaining risks: `/pstack off` resets if the port rewrites its config on
  update (checker catches: pstack entries render without the pin → FAIL);
  pi-lens injection grows upstream (B1 alert at 7 175); Cursor re-creates
  mirror links (B2(ii) trips on new names until ruled).
- Parking lot: unpublished Bun/`@cursor/sdk` loader note (removed from
  `docs/`; git history); personal-scope re-check (`adonisjs-suite`
  relinks on pi when scope=personal — by design).
- Superseded docs/specs: v14 plan arithmetic (in git history of `PLAN.md`);
  CLAUDE.md ADR-index extension item retracted with evidence (no index exists).
- Next links: `scripts/pi-skill-load-check`, `docs/pstack-strategy.md`,
  `docs/adr/0023-…md` § Amendment. Frozen `docs/skill-load/` snapshot
  removed 2026-09-13 (git history).
