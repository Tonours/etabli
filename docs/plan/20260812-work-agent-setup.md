# Implemented: Work-scoped Codex, Claude, Pi, and Grok setup

## Metadata
- Archived: 2026-08-12
- Source plan: `PLAN.md` — Synchronize Etabli with the work-scoped local agent setup
- Source plan SHA-256: `4b960752b14b9af860da0add752e319cffce4ba0af05d8fbc046959277bc3972`
- Status: IMPLEMENTED
- Branch: `main`
- Commit: not created; publication was outside the requested scope

## Outcome
- Extended the daily deployer and symlink checker across the repo-owned Pi,
  Claude, Codex skill-only, and Grok-facing `~/.agents` surfaces.
- Made `~/.etabli-scope=work` converge `shared + work` vendor links while
  removing only exact repo-owned links from inactive scopes and preserving
  user-owned or external targets.
- Applied the local managed deployment: four missing Grok-facing skill links
  were created, the second dry run reported no `WOULD_*`, and the live checker
  reported zero issues.
- Replaced the stale seven-server Claude-centric MCP reference with the
  sanitized runtime-specific work inventory and recorded ADR-0016.
- Kept live auth, settings, histories, sessions, databases, trust state, MCP
  configuration, plugins, project paths, and permission modes local.

## Context
- `~/.etabli-scope`: observed value `work`; active set resolves to
  `shared work`.
- `workflow/runtime/skill-surface.tsv`: source of `pi_core`,
  `agents_visible`, and `cross_harness` ownership.
- `vendor/sources.tsv`: source of vendor-to-scope assignments.
- `docs/adr/0011-*.md` and `docs/adr/0015-*.md`: full Codex/Grok harness trees
  remain out of scope; Codex ownership remains skill links only.
- `mcp/servers.template.json`: sanitized reference-only union; it is never
  deployed into live runtime files.

## Decisions

### Preserve one authored skill source across four consumers
- Context: the installer already linked active vendor skills to Pi, Claude, and
  Codex, while the daily deploy/check pair covered only a subset and left four
  new `~/.agents` links absent.
- Choice: reuse the catalog and vendor scope manifest in the daily deployer and
  checker; keep Grok on native `~/.agents` discovery.
- Rejected options: full tracked Codex/Grok harness trees, per-runtime skill
  copies, and plugin installation.
- Rationale: a single source plus explicit link ownership prevents drift
  without duplicating harness configuration.
- Consequences: new runtime link surfaces must be added to both scope cleanup
  and validation.

### Remove only exact inactive vendor targets
- Context: adversarial review found that switching from `personal` to `work`
  could leave an old personal vendor link active.
- Choice: inspect the raw `readlink` target and remove it only when it exactly
  equals a tracked inactive vendor directory.
- Rejected options: broad pruning, canonicalized-path deletion, or deleting
  same-name files and external links.
- Rationale: exact ownership is safer than aggressive cleanup.
- Consequences: an equivalent but differently spelled target may remain and be
  reported manually; user-owned paths are never inferred as managed.

### Record MCP assignments without deploying live config
- Context: local name-only introspection disproved the old Claude-single-store
  documentation.
- Choice: track the sanitized union plus explicit assignments for Claude, Pi,
  Codex, and Grok; keep native live stores local.
- Rejected options: generating templates from full live files, restoring a
  Codex config tree, and claiming Linear availability across runtimes.
- Rationale: the repository needs an accurate portable inventory without
  expanding its secret boundary.
- Consequences: inventory changes require a reviewed manual update to the
  template, strategy, and ADR record.

## Accepted Drift
- Original plan: create/verify links but add no new pruning.
- Implemented reality: exact inactive-vendor symlinks are removed from all four
  managed surfaces.
- Why accepted: fresh adversarial review identified a real work/personal scope
  leak; the fix is bounded by raw target equality and preservation tests.

- Original check: canary `session-handoff` directly.
- Implemented reality: use the canonical `runtime-skill-canary` skill.
- Why accepted: `session-handoff` has no documented canary response; its link
  is covered by the zero-issue checker, while the canonical canary proves lock,
  source, link, and response integrity.

## Review Evidence
- Plan adversary: initial `CHALLENGED`, then `READY` after operation ordering,
  measurable zero-drift, no-harness, and Grok/personal isolation checks were
  folded into `PLAN.md`.
- Fresh-context review `claude-fresh-20260812-1`: `GO WITH NOTES`; EOF-safe TSV
  parsing accepted, other concerns adjudicated against the actual code/tests.
- Cross-model code-diff adversary `claude-code-diff-20260812-final`:
  `GO WITH NOTES`; accepted inactive-scope cleanup and required raw-target plus
  cross-runtime invariant documentation. No blocker remains.
- Simplification: no change; one shared catalog helper owns vendor selection,
  deploy/check remain explicit, and no generic runtime harness layer was added.

## Validation Evidence
- `bash tests/deploy-agent-workflow-smoke.sh && bash tests/fix-links-smoke.sh && bash tests/install-smoke.sh`:
  - result: passed; includes shared/work selection, personal exclusion, stale
    exact-target removal, external-link preservation, second apply, and
    zero-drift dry run.
- `bash tests/workflow-docs-smoke.sh && bash tests/runtime-skill-canary-smoke.sh`:
  - result: passed.
- `scripts/runtime-skill-canary --skill runtime-skill-canary --json`:
  - result: `offline_passed`; source, lock, agents-visible link, and documented
    canary response passed; live runtime invocation was not requested.
- `node scripts/validate-adrs . && jq -e . mcp/servers.template.json`:
  - result: passed; 16 ADR records, valid sanitized JSON.
- `scripts/deploy-agent-workflow --apply` followed by dry run and
  `scripts/check-fix-symlinks.sh --verbose`:
  - result: four `~/.agents/skills` links created; no post-apply `WOULD_*`;
    `0 issue(s), 0 unresolved`.
- `scripts/verify-agentic-infra core`:
  - result: passed; 192 Pi tests, router evaluation 53/53, guards, scenario,
    deployment, supply-chain, and contract coverage checks passed.
- `bun test pi/extensions/__tests__/`:
  - result: 192 passed, 0 failed.
- `gitleaks dir --no-banner --redact .`:
  - result: no leaks found across approximately 5.59 MB.
- `test ! -e codex && test ! -e grok && git diff --check`:
  - result: passed; no tracked full harness trees and no diff whitespace error.

## Follow-up State
- Remaining risks: live provider-backed skill invocation was not requested or
  verified; offline source/link evidence must not be presented as live proof.
- Parking lot: none for the requested work-scoped repository synchronization.
- Superseded docs/specs: ADR-0016 narrows only ADR-0011's MCP
  single-definition-store claim; ADR-0011's harness removal and ADR-0015's
  skill-only Codex boundary remain active.
- Next links: `docs/mcp-strategy.md`, `mcp/servers.template.json`,
  `docs/adr/0016-record-work-mcp-inventory-per-runtime.md`.
