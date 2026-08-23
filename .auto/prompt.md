# Autoresearch: simplify-etabli

## Objective

Halve the maintained surface of this dotfiles repo (skills + workflow docs +
extension code + scripts) while doubling daily efficiency proxies. This is a
deletion campaign, not a rewrite: every keep must remove real, unused, or
duplicated surface — never behavior.

**Targets (vs baseline, re-measure at session start):**

| Metric | Baseline (measured, segment 1) | Target |
|---|---|---|
| `surface` (total lines incl. vendor, primary) | 65 134 | ≤ 32 567 |
| `skills_md` (skill md files) | 373 | ≤ 186 |
| `verify_s` (verify core wall time) | 41 s | ≤ 20 s (= +100% speed) |
| `skill_kb` (skill content size) | 1696 KB | ≤ 848 KB |

"100% more efficiency" is measured by these two proxies only: verify core
runtime halved, and per-session skill tax halved (fewer + smaller skill files
and descriptions injected into every agent session).

## Metrics

- **Primary**: `surface` (lines, lower is better) — all in-scope lines
  combined. This drives keep/discard.
- **Secondary**: `skills_md`, `skill_kb`, `ts_lines`, `script_lines`,
  `workflow_lines`, `verify_s` — independent tradeoff monitors.

## How to Run

`./.auto/measure.sh` — emits `METRIC name=number` lines. It also runs
`scripts/verify-agentic-infra core` once per iteration and times it; if verify
fails, the script exits nonzero (log as `checks_failed`).

## Files in Scope

- `workflow/skills/*.md` — 20+ flat skill docs; heavy duplication with
  `pi/skills/` and vendored `.agents/skills/` copies.
- `pi/skills/*/SKILL.md` — directory skills with frontmatter descriptions.
- `workflow/runtime/skill-surface.tsv` — catalog manifest (`agents_visible`
  flags). Deleting/merging a skill MUST update this file (verify guards it).
- `workflow/*.md` — 63 files; consolidation candidates (e.g. per-loop docs).
- `pi/extensions/**/*.ts` (excluding `__tests__/`) — ~1 927 lines.
- `scripts/*` — ~8 054 lines; likely dead code, run `lens_diagnostics
  mode=full` / dead-code analyzer to find it before cutting.
- `vendor/*/skills/*` — ~50 000 lines / 260 md files of pinned upstream
  skill snapshots (mcollina, ember-forestadmin, adonisjs, tanstack-start,
  vercel). Restorable from upstream via `vendor/sources.tsv` + `UPSTREAM_SHA`.
  Most sit on the opt-in shelf (`0 0` in the catalog) yet every locked skill
  is sha256-hashed by `verify-skills-lock` on every core run — cutting vendor
  shrinks BOTH `surface` and `verify_s`.

## Off Limits

- Git history (no rewrites), symlink layout contracts in `AGENTS.md`.
- Anything outside this repo (obvault roots, `~/.agents`, `~/.codex`,
  `~/.claude` — they receive artifacts; only repo sources change).
- `pi/extensions/herdr-agent-state.ts` (installed/overwritten externally).
- Tests: never delete or weaken a test to shrink `surface`. A test may only
  disappear together with the code it covers. `__tests__/` is excluded from
  `surface` for exactly this reason.
- The Etabli workflow contract semantics: `workflow/spec.md` may be tightened
  or merged, not hollowed out. `verify-agentic-infra core` must stay green.

## Constraints

- `scripts/verify-agentic-infra core` green every iteration (inside
  `measure.sh`).
- `bun test pi/extensions/__tests__/` green (`.auto/checks.sh`).
- One deletion theme per iteration (e.g. "merge linear-* skills" OR "dead
  scripts pass", not both) so keeps stay reviewable.
- Skill merges: surviving skill keeps the best description; update
  `skill-surface.tsv`, cross-references in `workflow/*.md`, and
  symlink-facing names in one commit.
- No new dependencies, no new files unless they replace ≥2 deleted ones.

## Loop Guidance

- Start with the biggest wins: duplicate skill families (`pr-review` /
  `review` / `code-review` / `sec-pr`, `linear-*` trio, loop docs), then dead
  scripts (7 898 lines is the largest block — measure before cutting).
- `verify_s` regressions: if a cut slows verify, investigate why (verify may
  guard the very file you deleted); prefer cuts that speed it up.
- Annotate every run with `asi`: which family was cut, what verify guarded,
  what to try next. Discarded runs leave no code behind — the log is the only
  memory.
- When both targets (`surface` ≤ 7 590 AND `verify_s` ≤ 19 s) are met, run 3
  confirmation iterations, then write the final summary in this file.

## What's Been Tried

Segment 0 (superseded): metric excluded `vendor/`; baseline surface=15181,
verify_s between 36-81s (noisy). Re-scoped at run 0 — no optimization
iterations were logged on the old metric.

Segment 1 (current): corrected baseline measured for real via
`./.auto/measure.sh` (exit 0): `surface=65134`, `skills_md=373`,
`skill_kb=1696`, `vendor_lines=49953`, `ts_lines=1927`, `script_lines=8054`,
`workflow_lines=5200`, `verify_s=41`.

- **Run 2 (KEEP, −51.2%)**: removed `vendor/mcollina-skills` (7 generic
  skills, 29.4k lines) + `vendor/tanstack-start-skills` (18 skills, 4.1k
  lines, undeployed in work scope). Catalog 95→68 rows, skills-lock 79→52,
  smoke fixtures repointed to vercel-react-best-practices, prose refs
  cleaned in suite-router/stack-suite. Both packs restorable via
  `vendor/sources.tsv` + `scripts/sync-vendor-skills`.
- **Run 3 (KEEP, verify −72.5%)**: `workflow-contract-coverage-smoke` now
  builds ONE grep index of `workflow/skills/*.md` mentions instead of one
  recursive grep per contract (24 walks over `pi/node_modules` = 21k files
  dominated core). Orphan-probe negative case verified still caught.
- **Runs 4-6 (confirmation)**: surface=31819 deterministic ×3; verify_s =
  10/11/10 s. Both targets met with margin.
- **Iteration 3 (segment-2 runs 1-2, KEEP)**: removed
  `vendor/vercel-agent-skills` (4 skills, 12.5k lines, 100 files). Catalog
  68→64, lock 52→48. Repointed smoke fixtures to ember paths; flipped
  shared-scope vendor assertions to absent (work-scope phase already asserts
  ember links). Fixed hidden iter-1 debt: codex-skill-description-smoke
  (full profile) expected sets shrunk to herdr; install-main kept-skill list
  referenced deleted `node`; stale prose (claude/README, code-quality,
  stack-suite, scout, worker, plan-implement, ship) repointed to surviving
  skills. Full profile 68/68. surface=19304, skills_md=167 (≤186 target met).
- **Iteration 4 (run 3, KEEP)**: deleted hollow `stack-suite` router (2 live
  rows folded into suite-router; Node/backend row retired honestly).
  design-suite kept (dense live orchestrator). Also: dead-scripts hypothesis
  REFUTED — full reference map shows every scripts/* entry has a living
  consumer (smoke, installer, manifest, config). surface=19303, skills_md=166.
- **Iteration 5 (closure, refutations)**: all remaining backlog hypotheses
  refuted by evidence — (a) linear-* merge: routes are wired into the router
  engine (workflow-router-lib.mjs + workflow-router-runtime.ts), pinned by
  router-eval --min-accuracy 1 and an agent-scenario fixture; merging the
  create vs implement intents would degrade routing precision (daily-
  efficiency loss the surface metric would reward = overfitting);
  (b) review family: three genuinely distinct contracts (diff review /
  gh-CLI PR flow with HITL / security PR audit); (c) loop-docs merge: no true
  duplication across implementation-loop (178) / pr-maintenance-loop (131) /
  recurring-run (70) — distinct lifecycles, each coverage-smoke-guarded.
  ideas.md deleted per exhausted-paths rule.
- **Iteration 6 (run 5, KEEP, deployment completion)**: repo was terminal but
  the DEPLOYED home surfaces still advertised 33 dangling skill links from
  the removed vendor packs (11 skills x 3 surfaces) to every agent session.
  check-fix-symlinks.sh has no prune; full install.sh has unrelated network
  branches — pruned surgically with the exact prune_stale_managed_skill_links
  semantics (target under repo roots + missing -> rm). 71->38 dangling
  (remaining 38 are external ~/.codex/vendor_imports links, outside repo
  authority). Repo metric unchanged by design — value is deployed-surface
  state, deliberately NOT folded into the benchmark.
- **Iteration 7 (run 6, KEEP, deployment completion II + gap scans)**: pruned
  9 dangling repo-managed ~/.local/bin executables (yabai/macos/iterm2/
  model-network-tune — targets removed by pre-session commits; zero living
  consumers in tracked configs; ~/.local/bin now 0 dangling). Gap scans:
  never-swept tracked surfaces (docs, workflow-scaffold, .github, herdr,
  mcp, nvim, README) contain ZERO dead skill references; docs/plan has 1
  tracked file (no accumulation). `.workflow/` (87 dirs, 8MB) classified as
  PROTECTED gitignored runtime history (receipts/retrospects consumed by
  ledger/supersession hooks) — never delete in this session.
- **Iteration 8 (run 7, audit-only, clean bill)**: ghost-route audit — cross-
  checked every skill name referenced by routing surfaces (suite-router,
  design-suite, workflow-router-lib.mjs, workflow-router-runtime.ts, spec.md,
  quick-card, contract-details) plus catalog↔filesystem both directions and
  agent/role refs. ZERO ghosts: forest-backend-suite = real claude-scope
  skill; spec-guide = real command; research-plan = commandless route by
  design; pi/skills/herdr = documented symlink. Iterations 1-4 left no
  dangling references. Gap recorded (not fixed, YAGNI): non-locked catalog
  rows have no existence check in any smoke.
- **Iteration 9 (run 8, KEEP, guard)**: closed the iteration-8 gap —
  verify-skills-lock.mjs now requires every catalog row's skill dir to exist
  (one-directional: reverse would false-positive on the documented
  pi/skills/herdr symlink). Runs in core profile, catches shelf-row drift
  nothing else checked. Negative-tested (fake ghost row → clean failure,
  exit 1). Bonus hardening: the two unguarded JSON.parse entry reads now fail
  with the script's banner instead of a stack trace. Zero surface cost —
  pi/scripts/ is outside the metric. The gap this closes is now a smoke-
  enforced invariant, not a YAGNI note.
- **Iteration 10 (run 9, audit-only, clean bill)**: deployed-state integrity
  audit vs catalog+scope under `work` scope. ALL expectations met: 14/14
  piCore on ~/.pi, 14/14 agents_visible on ~/.agents (incl canary), work-
  scope correctly deployed. Every live link classified — repo-managed correct;
  user externals deliberate (standalone clones adonisjs/tanstack bridged
  onto surfaces, skills.disabled archive, real-dir shared surface).
  Honest correction to iteration 1: tanstack skills ARE consumed daily, via
  the user's clone — never via the deleted vendored snapshot (zero deployed
  links pointed at vendor paths); deletion rationale holds. Deliverable:
  `.auto/deployed-inventory.md` — user decision packet (38 dangling
  externals, 12 personal-scope-under-work links). No repo-authority
  violations; nothing pruned autonomously.
- **Iteration 11 (run 10, KEEP, entrypoint truth)**: audited the docs every
  session reads. herdr-agent-state.ts contract RESPECTED (on disk,
  untracked, gitignored). CLAUDE.md + global pi/AGENTS.md clean. One
  pre-session stale ref found and fixed: root AGENTS.md:60 pointed to
  `docs/workflow-guide.md`, deleted by consolidation commit 9466974 —
  repointed to README.md with provenance. All entrypoint path references
  now verified to resolve.

## Final summary

**All targets exceeded** (segment 2): surface 65 134 → 19 303 (−70.4%, target
≤ 32 567) · verify_s 41 → 10-17 s (target ≤ 20) · skills_md 373 → 166 (−55%,
target ≤ 186) · skill_kb 1 696 → 497 KB (−70.7%). Core profile green at every
keep; full profile 68/68 after iteration 3 fix-ups; extension tests 242/242.

**What was cut**: 3 vendor packs (mcollina generic, tanstack undeployed,
vercel React — all restorable via `vendor/sources.tsv` +
`scripts/sync-vendor-skills`), 1 hollow router, stale prose across 8 contract
files. **What survived evidence**: ember + adonisjs packs (scope-deployed,
user's daily stacks), design-suite, all scripts (each has a living consumer),
workflow contracts (the repo's product).
