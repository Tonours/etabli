# Implemented: Minimal core T2 — experimental instrumentation removed, hard gates kept

## Metadata
- Archived: 2026-09-26
- Source plan: `PLAN.md` — Recentrage minimal — Tranche 2 : retrait de l'instrumentation expérimentale
- Source plan SHA-256: `a7ec70cfe5af2ea1f1492dfc744ebf137e27b9f918781a8fe840983c2fdad373`
- Status: IMPLEMENTED
- Commit / branch: `refactor/minimal-core-routes` (single tranche commit on top of `049d01b`; not pushed)
- Workflow initiative: `minimal-core-t2`

## Outcome
- 427 tracked files deleted: Jev stack (judge, shadow, route-shadow, semantic judgment/profiles/routes, typesafe system/transport), token-protocol bundle (T8a/T8b scripts, libs, tests, fixtures), self-improvement / reviewer-improvement / program-orchestration contracts, program-state, project-autonomy, evidence-proof, retrospects, harness-eval v1/v2, outcome metrics, `outcome-metric-emit` and `proof-shadow` Claude hooks, tracked `t8b-runs` evidence.
- Kept: READY gate, check-freeze, write guard, ops-stop, context-budget, skill-eval (`workflow/self-improvement/manifests/*`), `review-metrics.md`, `usage-accounting.mjs`, `harness-token-usage.mjs`, `vendor/typesafe-ai/`.
- `no_progress` mutation guard removed from `planMutationGuardDecision` (READY + check-freeze only); the no-progress stop rule stays prose.
- Pi router extension is deterministic only; parity has a single Pi site; core manifest 36 → 27 checks.
- `autonomous-completed-strict` fails closed on `harness_validation_completed` (comparator chain gone); `session-handoff` program replay returns `replay_valid:false` with an explicit reason.
- Claude hook migration: `claude-hooks-merge` removes `RETIRED_HOOK_COMMANDS` (exact command), `claude-hooks-check` fails while they stay wired, both resolve `$CLAUDE_CONFIG_DIR` (else `~/.claude`); the hook prune removes only `name -> $REPO_DIR/claude/hooks/name` links whose target is gone.
- `deploy-agent-workflow` maintains every Claude surface in `~/.claude` and, when set and different, in `$CLAUDE_CONFIG_DIR` (second pass through `CLAUDE_ROOT` / `MANAGED_CLAUDE_ROOT`); `claude-skill-load-check` reads that root and only warns there about live skills outside the tracked profile; dangling links into the repo are replaced without a `.bak` (other dangling links keep one).
- `scripts/lib/claude-config-dir.sh` gates `CLAUDE_CONFIG_DIR`: applied only when it sits under `$HOME` or `$HOME` is the passwd login home, so smokes under a disposable HOME never touch the real config; sourced by deploy, check-fix-symlinks (audits both roots), merge, check and load-check.

## Context
- `workflow/runtime/workflow-router-core.mjs`: `planMutationGuardDecision` composes the READY, check-freeze and check-freeze-bash decisions.
- `scripts/claude-hooks-merge` was add-only; installs merged with the old fragment kept firing deleted Stop hooks.
- The live session runs with `CLAUDE_CONFIG_DIR=/Volumes/Crucial/.homes/claude` (set by `~/.zshrc` when the disk is mounted); deploy never maintained it, so it still carried pre-T1 state (10 dangling work commands, 6 dangling moved skills, 17 broken mirrors). `~/.codex` is a symlink to its relocated home, so Codex was unaffected.
- asdf node shims exit 126 when `HOME` points at a disposable tree: smokes that override `HOME` must pin `PATH` to the resolved Node binary.
- A deploy run with `HOME_DIR = HOME` and no `ETABLI_INSTALL_HELPER_SMOKE=1` repoints the repo `pi/extensions/node_modules` link to that home.

## Decisions
### Remove the `no_progress` guard instead of closing ledgers
- Context: 116 of 141 ledgers were non-terminal; the guard blocked even reads when several stayed open.
- Choice: drop the mechanical block, keep the written stop rule.
- Rejected options: bulk-closing ledgers (not durable); keeping the guard behind a flag.
- Rationale: T1 decision « gates durs seuls ».
- Consequences: autonomous loops rely on their explicit cap.

### Gate `CLAUDE_CONFIG_DIR` on the login home
- Context: a smoke running deploy under a disposable HOME inherited the real `CLAUDE_CONFIG_DIR` and rewrote it with the test scope.
- Choice: honor it only when it sits under `$HOME` or `$HOME` is the passwd home.
- Rejected options: unsetting it in every smoke (fragile, one miss rewrites the real config).
- Rationale: fail-safe default for every caller, tests included.
- Consequences: a relocated dir outside a non-login HOME is ignored; `--home DIR` keeps meaning `DIR/.claude`.

### Retire hooks by exact command, not by pattern
- Context: the merge must never drop user hooks.
- Choice: a frozen `RETIRED_HOOK_COMMANDS` list in `scripts/lib/claude-hooks-fragment.mjs`.
- Rejected options: removing any hook whose script is missing (would touch user hooks).
- Rationale: only commands the repo itself shipped are removed.
- Consequences: future hook retirements append to the list.

## Accepted Drift
- Original plan/spec: AC4 asked only for no dangling links under `~/.claude/hooks`.
- Implemented reality: also `settings.json` retirement, full `CLAUDE_CONFIG_DIR` support in deploy, merge, check and load-check, no-backup replacement of dangling managed links, PATH pinning in the install and claude-profile smokes.
- Why accepted: the Codex review and a live Stop-hook failure showed the link fix alone left broken hooks firing.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: 27/27 PASS
- command: per-check `full` runner (`/tmp/t1-full-each.sh`)
  - result: 54/54 exit 0
- command: `bun test pi/extensions/__tests__/`; `bash tests/pi-typecheck-smoke.sh`
  - result: 350/350; no type errors
- command: `scripts/router-eval`; `scripts/workflow-router-parity`
  - result: 0 misses; `clean (8 routes)`
- command: `scripts/workflow-adapter-sync --check`; `cd pi && bun ./scripts/verify-skills-lock.mjs`; `scripts/workflow-ref-linter`; `scripts/workflow-context-budget`
  - result: clean; 80 hashes; clean; 8 surfaces within ceiling
- command: `scripts/deploy-agent-workflow --apply`; `scripts/check-fix-symlinks.sh`; `scripts/claude-hooks-check`
  - result: stale hook links removed; 0 issues; all fragment hooks wired
- command: `bash tests/deploy-agent-workflow-smoke.sh`; `bash tests/guards-active-smoke.sh`
  - result: PASS (seeded stale, personal, traversal, dry-run and relocated-config cases; mutation without the prune is red)
- command: reviews
  - result: reviewer Logic GO WITH NOTES, reviewer Spec GO WITH NOTES, Codex `gpt-6-astra` BLOCK ×4 → GO WITH NOTES (no finding), every finding folded

## Follow-up State
- Remaining risks: the relocated dir carries 46 live personal skills outside `claude/profiles/lean.settings.json` (88 discovered, index 16380 chars vs ~6400 native budget, so the model-facing listing is truncated); user-owned, reported by the load check, not removed.
- Parking lot: `jev_state` field in `workflow/trace-observation.schema.json`; retired event types in `workflow/events.md`; `workflow/runtime/ledger-drift-grandfathered.json` Jev slug.
- Superseded docs/specs: `docs/harness-eval.md` (deleted).
- Next links: T3 — ledger simplification and non-core contract shelving.
