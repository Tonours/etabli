# Implemented: one skill tree served to Claude and Pi, dead code and stale docs pruned

## Metadata
- Archived: 2026-10-17
- Source plan: `PLAN.md` — Prune remaining dead code and stale docs, then serve one skill tree to both Pi and Claude
- Source plan SHA-256: `91b4b026cd975734c0cb0244fa4f885dc05acfbf312445d9e7f2fa14f444d8ca`
- Status: IMPLEMENTED
- Commit / branch: main, base `625cf755`
- Workflow initiative: none

## Outcome
- First-party skills live once in `skills/<scope>/<name>/SKILL.md` (11 `shared`, 7 `work`), catalogued in `workflow/runtime/skill-surface.tsv` with source `etabli`; Claude links every active-scope row, Pi only `pi_core=1` rows (ADR-0037, amends ADR-0006).
- Retired: `pi/skills/`, `claude/scopes/*/skills/`, every Claude command (`claude/scopes/*/commands/`), `scripts/lib/vendor-surfaces.sh`, `pi/agent/subagents.json`, `pi/models.local.example.json`, the ignored `local:etabli-workflow` Pi package entry, three dead prune helpers and the 22-name stale command list.
- `pi/AGENTS.md` moved to `workflow/agent-rules.md`; `claude/CLAUDE.md` imports it relatively, Pi still reads it as `~/.pi/agent/AGENTS.md`.
- `scripts/claude-skill-load-check` derives known/expected skills from the catalogue and active scopes, so shared, work and personal machines all pass; `pi/scripts/verify-skills-lock.mjs` fails on an uncatalogued skill.
- Deploy and `check-fix-symlinks.sh --fix` prune stale links into retired roots and every repo `commands/*` link; skill-dir collision backups land in `<surface>.bak/`; a failed backup aborts instead of replacing the entry.

## Context
- Pi parses `local:etabli-workflow` as a missing local path and returns silently, so its keeper list duplicated the catalogue `pi_core` column without effect.
- Claude skills accept `argument-hint` and `allowed-tools`; Pi ignores unknown frontmatter keys, so one SKILL.md serves both.
- Relative `@` imports in `CLAUDE.md` resolve from the link target (live memory probe lists `workflow/agent-rules.md`).
- In Bash, `errexit` does not apply inside `$(…)`, and a caller-side `|| return 1` suspends it inside the callee.

## Decisions
### One tree instead of per-runtime adapters
- Context: the same adapters existed as Pi skills and Claude commands with drifting wording.
- Choice: one SKILL.md per skill, scope applied on both runtimes.
- Rejected options: link `pi/skills/` into Claude (two layouts survive); generate commands from skills (generator plus drift check).
- Rationale: deletion test; the vendor record path already deployed skills to both surfaces.
- Consequences: a `personal` Pi loses the `work` Linear and `bug-check` skills; Linear skills are `user-invocable-only` on Claude.

### C1 gate kept
- Context: the live index hit 4900 against the 4892 alert once commands became skills.
- Choice: trim the `adversary` and `spec` descriptions (index 4776) instead of re-pinning 4912/4892.

### In-repo links are disposable
- Context: `--fix` moved `pi/extensions/node_modules` aside, leaving `.bak` links in the checkout that broke `pi-typecheck`.
- Choice: `managed_surface_link_is_disposable` covers links into or inside the normalized checkout path; `..`, `.` and `//` segments are never treated as the checkout's own.

## Accepted Drift
- Original plan/spec: AC-7 called for recalibrating the C1 gate.
- Implemented reality: gate unchanged, two descriptions trimmed.
- Why accepted: same bound held with less context.

## Validation Evidence
- command: `scripts/verify-agentic-infra full`
  - result: 36/36 checks passed
- command: `cd pi && bun test extensions/__tests__/ && bun run typecheck`
  - result: 61 pass, 0 fail; tsc exit 0
- command: `node pi/scripts/verify-skills-lock.mjs`
  - result: Verified 29 skill hashes
- command: `scripts/deploy-agent-workflow --apply`, then `--dry-run`, `scripts/check-fix-symlinks.sh`, both load checks
  - result: apply exit 0; dry-run idempotent; 0 issues; Claude index 4776 / 3936; Pi load check ok; no repo link left in either `commands/`
- command: `claude -p --output-format stream-json --verbose --max-turns 1 "Reply with OK only."` init event
  - result: `.skills` and `.slash_commands` hold every expected name
- review: Logic and Spec reviewers GO WITH NOTES (notes folded or rejected with evidence); codex `gpt-6.1-sol` code-diff adversary CHALLENGED x3 (two backup-safety HIGHs and a path-escape HIGH fixed with regressions), then READY on pass 4.

## Follow-up State
- Remaining risks: other machines keep dangling skill links and retired command links until their next `scripts/deploy-agent-workflow --apply`; record matching by path suffix prunes a same-layout link from another clone by design.
- Parking lot: README pins Pi `1.0.3` while `1.1.0` is installed here.
- Superseded docs/specs: ADR-0006 amended by ADR-0037.
- Next links: `docs/adr/0037-serve-one-skill-tree-to-both-runtimes.md`
