# Implemented: dead skill links are pruned on every harness surface, the Codex skill surface is recorded, and TanStack Start has a router

## Metadata
- Archived: 2026-08-07
- Source plan: Close the three open items from the skills-vendoring session — ADR/Codex mismatch, missing Claude skill pruning, missing TanStack router
- Status: IMPLEMENTED
- Commit / branch: `badf49c` on `main`; upstream `Tonours/tanstack-start-skills@0215f92`

## Outcome
- `prune_stale_managed_skill_links` removes dangling symlinks from
  `~/.claude/skills`, `~/.pi/agent/skills`, `~/.codex/skills` and
  `~/.agents/skills` on every install, gated so a live target or a link this repo
  does not own is never touched.
- ADR-0015 records `~/.codex/skills` as a managed link surface, amending ADR-0011
  in prose without touching it.
- `tanstack-start-suite` routes the 19 TanStack skills by dominant risk, written
  upstream and vendored back, and named by `stack-suite`.

## Context
- `scripts/lib/install-main.sh:44` — `prune_stale_managed_claude_agent_links` was
  the working model: match only targets under a managed root, delete only when the
  target is gone. Its prefix-glob matching turned out to matter (see Drift).
- Three writers reach `~/.claude/skills`, not two: `pi/skills` via
  `CROSS_HARNESS_PI_SKILLS`, `vendor/*/skills`, and `claude/scopes/*/skills`.
  A two-root accept list would have skipped `react-doctor-100`.
- `prune_managed_pi_skills` only matches `pi/skills/*` targets, so it cannot see a
  dangling vendor link even on the Pi surface it owns.
- ADR-0011 removed per-harness *authoring* trees and justified it by "harnesses
  with no live local install"; `codex-cli` 0.147.0 is installed here, so the
  premise no longer holds for a symlink into a running harness.
- `~/.claude/skills` really contains relative links (`code-simplifier`,
  `find-skills` → `../../.agents/skills/…`) that this repo must not touch.

## Decisions

### Prune every skill surface rather than Claude only
- Context: the first plan scoped pruning to `~/.claude/skills`, arguing the other
  surfaces had no observed drift.
- Choice: prune all four surfaces in one pass.
- Rejected options: Claude-only (contradicted the plan's own acceptance criteria);
  extending `prune_managed_pi_skills` (it deletes live non-core links, a different
  job).
- Rationale: the adversary pass refuted "no drift evidence" by mechanism — one
  install links a vendored skill into all four surfaces, so an upstream removal
  dangles all four simultaneously.
- Consequences: the missing-target guard makes the wide sweep no riskier than the
  narrow one; a new harness surface must be added to the list explicitly.

### Record the Codex skill surface in a standalone ADR
- Context: the installer writes into `~/.codex/skills` while ADR-0011 declares the
  Codex harness removed.
- Choice: a new ADR-0015 that amends ADR-0011 in prose, with no `supersedes:`
  frontmatter.
- Rejected options: editing ADR-0011 (accepted ADRs are immutable, ADR-0008);
  declaring `supersedes:` (the validator forbids a one-way supersede, and it would
  mark ADR-0011's still-valid Kimi and MCP decisions dead); leaving it unrecorded
  (that absence is how 39 dead shells accumulated unnoticed).
- Rationale: the reversal is real but narrow — skills links, not the harness.
- Consequences: ADR-0011 stands unchanged; a reader now finds why `~/.codex` is
  written to.

### Write the TanStack router upstream, not in etabli
- Context: 19 skills vendored from a private repo, with no router.
- Choice: author `tanstack-start-suite` in `Tonours/tanstack-start-skills`, then
  vendor it like any other skill.
- Rejected options: writing it in `claude/scopes/personal` (splits the set across
  two homes and breaks `sync-vendor-skills`).
- Rationale: one source of truth per skill set, already the rule in
  `vendor/README.md`.
- Consequences: updating the router means a push upstream then a re-sync.

## Accepted Drift
- Original plan: extend `tests/fix-links-smoke.sh` with the red/green pruning case.
- Implemented reality: the case lives in the `ETABLI_INSTALL_HELPER_SMOKE` block of
  `scripts/lib/install-main.sh`, run by `tests/install-smoke.sh`.
- Why accepted: `fix-links-smoke.sh` drives `check-fix-symlinks.sh`, which never
  runs the installer, so a case planted there could not have gone from red to
  green. Caught by the plan adversary pass.

- Original plan: compare the link target's parent against each managed root for
  exact equality.
- Implemented reality: exact equality on canonicalised paths (`pwd -P` both sides),
  plus a lexical-prefix fallback under `$repo_dir` when the parent no longer exists.
- Why accepted: two bugs found by testing the exact-match version. A relative
  target resolved to a path still containing `../..` and never matched, so every
  relative link was silently skipped. And deleting a whole `vendor/<name>/` tree
  removes the root itself, so both the root enumeration and the parent lookup
  skipped it — the precise 39-dead-link shape ADR-0015 documents. `[ -e ]` remains
  the only gate that authorises deletion.

## Validation Evidence
- command: `ETABLI_INSTALL_HELPER_SMOKE=1 bash scripts/lib/install-main.sh`
  - result: ok. Covers a stale link per managed root, a live link per root, an
    unmanaged link, the three non-Claude surfaces, relative links inside and
    outside the roots, a symlinked repo path, and a wholesale-removed vendor tree.
    Each destructive assertion was confirmed red by mutating out its branch.
- command: `bash tests/install-smoke.sh`
  - result: ok
- command: `bash tests/fix-links-smoke.sh`
  - result: ok
- command: `bash tests/workflow-contract-coverage-smoke.sh`
  - result: ok
- command: `node scripts/validate-adrs`
  - result: ok, 15 records, next ADR-0016
- command: `bash scripts/check-fix-symlinks.sh`
  - result: 0 issues
- command: `bash scripts/verify-agentic-infra core`
  - result: exit 0
- command: end-to-end — plant dangling managed links in `~/.claude/skills` and
  `~/.agents/skills`, plus one hand-made link, then run `scripts/install.sh`
  - result: both managed links pruned, the hand-made link kept, live skills intact,
    0 dead links across all four surfaces
- review: fresh-context reviewer, `GO WITH NOTES`. Both findings folded in — the
  wholesale-tree gap (fixed with the fallback) and a stale decision-log line.
  Same-family pass: no cross-model runner on this machine per
  `~/.claude/rules/claude-only-agents.md`.

## Follow-up State
- Remaining risks: adding a fifth harness surface means editing the surface list
  in `prune_stale_managed_skill_links`; nothing discovers surfaces automatically.
- Parking lot:
  - `tests/claude-agents-smoke.sh` fails on `main` at `d90bd62`, before this work:
    `claude/scopes/shared/agents/reviewer.md: unsupported tools: Skill`. Reproduced
    on a clean HEAD worktree. Not in the `core` group, untouched here.
  - `workflow/runtime/skill-surface.tsv` has a trailing tab on the
    `tanstack-start-suite` row and sits apart from the other TanStack rows; parses
    fine under `NF>=5`.
  - `scripts/lib/install-main.sh` calls `mkdir -p ~/.agents/skills` twice.
  - AdonisJS and TanStack Start are `personal` scope, so their routers are absent
    on this `work` machine; `stack-suite` states the fallback explicitly.
- Superseded docs/specs: none. ADR-0011 stands.
- Next links: `vendor/README.md` for the sync contract; ADR-0015 for the Codex
  skill surface.
