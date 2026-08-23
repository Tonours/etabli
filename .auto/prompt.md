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
  skill snapshots (mcollina, ember-employer, adonisjs, tanstack-start,
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
