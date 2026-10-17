# Implemented: first-party skills in English with third-person trigger descriptions; plan templates aligned with the spec

## Metadata
- Archived: 2026-10-17
- Source plan: `PLAN.md` — Optimize first-party skills and plan templates against skill authoring best practices; English everywhere
- Source plan SHA-256: `c33c461613876531cba4920e004c2f8321c30173162e4c9b460ef5546245d4fc`
- Status: IMPLEMENTED
- Commit / branch: `main`
- Workflow initiative: none

## Outcome
- `spec` and `write-direct` skills translated to English; `write-direct` keeps its French lexicon and before/after samples quoted, since its output is French by default.
- 35 descriptions (Pi skills, Claude commands, skills and agents, `pi/agents/Explore.md`, extras) rewritten to third person with `Use when …` and `not for …`; adapter headers, adapter-manifest hashes and `skills-lock.json` regenerated (vendor entries unchanged).
- Stale references fixed: Pi `implement`/`plan-implement` record `quality: pass|unavailable` instead of the retired `quality_completed` ledger append; spec templates point at `template-product.md`/`template-technical.md`.
- Duplicate `herdr/skills/herdr` and the tracked `pi/skills/herdr` link removed; dotfiles owns the skill.
- `PLAN_TEMPLATE.md`/`PLAN_TEMPLATE_FULL.md`: same Workflow Contract keys (Route, Role, Tier, Budget, Stop condition, Required evidence); orphan fields from the deleted `workflow/loop-patterns.md` (Pattern, Goal verifier, Context reset, Escalation) and the Large Program Manifest, role-output fields, Progress Log and Validation Plan removed; FULL gains Checks and Notes / Handoff and points its Ready Gate at `workflow/spec.md` § Minimal READY gate; Review Changes names the provenance fields the spec asks for.
- `workflow/skill-design.md` gains a Frontmatter and layout section with sources.

## Context
- Sources: Anthropic "Skill authoring best practices", Claude Code skills docs, agentskills.io specification, vault `kb/skill-catalog-context-budget-gating.md`.
- `workflow/spec.md:74-77` puts run evidence in Checks, Review Changes and Notes / Handoff; the FULL template lacked two of them.
- Code reads only `Subject`, `Status`, `Last revised` from plans (`scripts/plan-cleanup`, `scripts/lib/plan-status.mjs`).
- `tests/skill-hygiene-smoke.sh` pins the use/not shape on 21 descriptions; `scripts/workflow-adapter-sync` requires one-line descriptions.

## Decisions
### Scope
- Context: "nos skills" could include work-scope routine prompts and vendored skills.
- Choice: first-party skills, commands and agents only; contracts in `workflow/skills/` kept as is (English, no retired names).
- Rejected options: translating `claude/scopes/work/scripts/**` prompts (not skills, they emit French Slack/PR output by design); editing `vendor/**` (upstream-pinned); renaming skills to gerunds (breaks `/name` and settings maps); TOCs on contracts over 100 lines.
- Rationale: smallest change that meets the request.
- Consequences: routine prompts remain French.

### Tier
- Context: plan adversary pass 1 cited `implementation-loop.md:24` (multi-surface contract change).
- Choice: high-risk; cross-model plan and code-diff passes.
- Rejected options: standard.
- Rationale: adapters and templates are contracts read by both harnesses.
- Consequences: two plan passes, one code-diff pass.

## Accepted Drift
- Original plan/spec: stop condition "code-diff adversary has no open HIGH".
- Implemented reality: the code-diff pass returned NO-GO on two LOW items only (lexicon quoting, description length); both fixed without a second cross-model pass.
- Why accepted: user rule (fix, record, ship); no HIGH or MEDIUM.

## Validation Evidence
- `scripts/verify-agentic-infra full`:
  - result: 45/45 PASS (one earlier run hit the flaky `pi/extensions/__tests__/project-vault.test.ts:47`; untouched surface, green on reruns)
- `bun test pi/extensions/__tests__/` + typecheck:
  - result: 346 pass, 0 fail; rc 0
- `scripts/pi-skill-load-check`, `scripts/claude-skill-load-check`:
  - result: ok; Pi block 6710/7800 (was 6628)
- `scripts/workflow-adapter-sync --check`, `node pi/scripts/verify-skills-lock.mjs`, `bash tests/skill-hygiene-smoke.sh`:
  - result: clean; 30 hashes; PASS
- Reviews: Logic and Spec subagents GO WITH NOTES; Codex `gpt-6.1-sol` plan passes CHALLENGED → folded; code-diff pass 2 LOW → fixed.

## Follow-up State
- Remaining risks: description rewording may shift auto-invocation slightly; no trigger eval exists (ADR-0034).
- Parking lot: `scripts/check-fix-symlinks.sh` does not report dangling links left by retired commands or skills (7 found and removed by hand, plus a live `herdr` link repointed to dotfiles); projects receive the new plan templates at their next `scripts/deploy-workflow`; routine prompts under `claude/scopes/work/scripts/` are French.
- Superseded docs/specs: none.
- Next links: `workflow/skill-design.md`, `PLAN_TEMPLATE_FULL.md`.
