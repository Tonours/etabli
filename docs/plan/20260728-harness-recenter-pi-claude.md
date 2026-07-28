# Implemented: Recenter the Etabli harness on Pi and Claude

## Metadata
- Archived: 2026-07-28
- Source plan: Recenter Etabli harness on pi + claude (root PLAN.md, READY after adversary fold)
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`
- Decision record: `docs/adr/0011-remove-the-codex-and-kimi-code-harnesses-and-recenter-on-pi-and-claude.md` (supersedes ADR-0004)

## Outcome
- Removed the Codex harness surface: `codex/` (99 files), `scripts/deploy-codex`,
  `scripts/audit-codex-organization`, `tests/codex-organization-smoke.sh`,
  `docs/codex-organization.md`, `docs/codex-app-subagents.md`.
- Removed the Kimi Code surface: `kimi-code/`, `scripts/deploy-kimi-code`.
- Migrated all 31 unique Codex skills to `pi/skills/` via `git mv` (48 skill
  dirs total). Dropped: 3 `linear-*` forks (near byte-identical to the
  canonical pi adapters), `codex-dynamic-workflows` (harness-specific
  orchestration), `agents/openai.yaml` metadata.
- Consolidated the skill catalog: `skill-surface.tsv` column renamed
  `codex_visible` -> `agents_visible`, the 4 previously codex-sourced skills
  now `source=pi`, 27 migrated packs cataloged opt-in
  (`pi_core=0, agents_visible=0, locked=0`); `skills-lock.json` regenerated and
  verified (20 locked hashes).
- Kept the Pi model portfolio intact: `openai-codex/*` council models and
  `kimi-coding/k3` fallback are model providers, not harness surfaces.
- Kept the shared `~/.agents` surface, now sourced exclusively from
  `pi/skills/`; home links redeployed and verified (4 stale timestamped
  backups removed).
- Replaced the cross-model adversary runner in `claude/commands/` with
  `pi -p --model openai-codex/gpt-5.6-sol --tools read`; router suggestion in
  `claude/hooks/workflow-router-lib.mjs` updated accordingly.
- Removed `runtimes.codex` from `workflow/runtime-capabilities.json` and
  `codex-organization-smoke` from the CI core manifest; updated all coupled
  smokes (capabilities, dual-runtime matrix, manifest, docs, contract
  coverage, deploy-agent-workflow, fix-links, obvault-routing, efficiency,
  real-agent-scenarios).
- Added MCP consolidation base: `mcp/servers.template.json` (sanitized,
  `${VAR}` placeholders), `docs/mcp-strategy.md` (Claude user scope = live
  store, Pi imports via `claude-code`, project scope for project servers,
  Linear MCP gap documented), and sourced research in
  `docs/skills-mcp-consolidation-research.md`.

## Key decisions
- Migrate every unique skill (user decision 2026-07-28) rather than only the
  cataloged four; packs stay opt-in via the catalog.
- Keep both model families and `~/.agents` (user decisions 2026-07-28).
- Template + doc for MCP rather than a sync script: two harnesses and a
  working native import make a sync layer unjustified.
- Dormant, not deleted: `scripts/workflow-metrics` and
  `scripts/workflow-telemetry-recover` remain as historical Codex session
  recovery tooling, marked dormant in `workflow/events.md`.
- Historical whitelist preserved: `docs/plan/*`, ADR-0004 (marked superseded),
  dated audits, telemetry fixtures, and model-ID mentions are provenance, not
  active surface.

## Validation
- `scripts/verify-agentic-infra core` — exit 0
- `scripts/verify-agentic-infra full` — exit 0
- `bun test pi/extensions/__tests__/` — 221 pass
- `cd pi && bun run verify:skills` — 20/20 hashes verified
- `scripts/deploy-agent-workflow --dry-run` and `--apply` — OK
- `scripts/check-fix-symlinks.sh` — 0 issues
- `scripts/research-proof-check docs/skills-mcp-consolidation-research.md` — ok
- `scripts/validate-adrs .` — ok
- Adversary plan pass: CHALLENGED -> folded (1 blocker, 8 HIGH) -> READY
- Fresh-context review + adversary code-diff pass: GO WITH NOTES, accepted
  fixes folded (skill-dir-relative script paths, stdin separator)
- Ledger: `.workflow/harness-recenter-pi-claude/events.jsonl`, validated with
  `scripts/workflow-event validate harness-recenter-pi-claude --profile autonomous-completed`
