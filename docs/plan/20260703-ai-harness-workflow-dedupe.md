# Implemented: AI Harness Workflow Skill Dedupe

## Metadata
- Archived: 2026-07-03
- Source plan: AI harness workflow skill dedupe architecture
- Status: IMPLEMENTED
- Commit / branch: `main`, uncommitted at archive time

## Outcome
- Recentered duplicated Pi, Claude, and Codex Linear/GitHub/CI/review behavior
  into shared `workflow/skills/*.md` contracts.
- Reduced matching Pi, Claude, and Codex skills to source-resolution adapters
  with harness-specific rules only.
- Updated scaffold and Codex deployment so shared workflow skill contracts are
  discovered dynamically and linked into `$CODEX_HOME/workflow/skills/`.
- Added smoke-test guards for adapter contract delegation and exact duplicate
  adapter bodies.

## Context
- `docs/workflow-duplication-audit.md`: existing audit identified drift across
  harness skills and byte-identical Pi/Codex `linear-work` copies.
- `workflow/skills/orchestration.md`: existing shared-contract layer defined
  harness capability labels and delegation rules.
- `scripts/deploy-codex`: previously deployed only files under `codex/`, so
  Codex shared contracts needed explicit deployment handling before Codex
  adapters could become thin.
- `scripts/deploy-workflow`: previously hardcoded three workflow skill
  contracts, which would make future shared contracts easy to forget.

## Decisions
### Shared Contracts
- Context: repeated behavior existed across Pi skills, Claude commands, and
  Codex Linear skills.
- Choice: add shared contracts for `bug-check`, `ci-fix`,
  `linear-project-setup`, `linear-ticket-create`, `linear-work`, `pr-qa`,
  `pr-review`, `review`, and `sec-pr`.
- Rejected options: keep Pi/Codex `linear-work` byte-identical; delete all
  fallbacks regardless of deployment needs.
- Rationale: contracts reduce token load and maintenance points while preserving
  harness-specific source resolution.
- Consequences: behavior updates now land in `workflow/skills/`, with adapters
  acting as runtime entrypoints.

### Codex Contract Deployment
- Context: Codex global skills may run outside a workflow-scaffolded repo.
- Choice: have `scripts/deploy-codex` link root `workflow/skills/*.md` into
  `$CODEX_HOME/workflow/skills/`.
- Rejected options: track duplicate copies under `codex/workflow/skills/` or
  make Codex adapters depend only on the active repo.
- Rationale: links preserve global Codex autonomy without introducing tracked
  duplicate contract files.
- Consequences: Codex smoke tests now assert deployed shared contracts exist.

### Dynamic Contract Discovery
- Context: hardcoded contract lists in scaffold/deploy scripts create a new
  drift point each time a shared contract is added.
- Choice: discover `workflow/skills/*.md` dynamically in `deploy-workflow` and
  test every discovered contract in scaffold smoke.
- Rejected options: extend the hardcoded list manually.
- Rationale: future contracts become one-file additions instead of multi-file
  deployment edits.
- Consequences: ordering is sorted and covered by smoke tests.

## Accepted Drift
- Original plan/spec: "0 duplication" in the user request.
- Implemented reality: interpreted as zero unguarded behavior duplication.
  `codex/workflow/ticket-template.md` remains a byte-guarded deployment
  fallback copy.
- Why accepted: removing that fallback would make global Codex ticket drafting
  less self-contained; the copy is explicitly guarded by smoke tests.

## Validation Evidence
- `bash tests/workflow-docs-smoke.sh`
  - result: passed
- `bash tests/workflow-scaffold-smoke.sh`
  - result: passed
- `bash tests/deploy-agent-workflow-smoke.sh`
  - result: passed
- `bash tests/codex-organization-smoke.sh`
  - result: passed
- `scripts/audit-codex-organization`
  - result: passed
- `bun test pi/extensions/__tests__/`
  - result: passed, 168 tests
- `bash tests/claude-hooks-smoke.sh`
  - result: passed
- `bash tests/workflow-autonomous-plan-loop-smoke.sh`
  - result: passed
- `git diff --check`
  - result: passed
- Duplicate adapter hash scan
  - result: no exact duplicate harness adapter bodies found

## Follow-up State
- Remaining risks: exact semantic parity between old long adapters and new
  shared contracts is protected by review and smoke assertions, not by runtime
  replay of each skill.
- Parking lot: the embedded `PLAN.md` fallback in Pi/Claude `plan-loop` remains
  intentionally duplicated and byte-guarded.
- Superseded docs/specs: `docs/workflow-duplication-audit.md` now describes the
  shared-contract architecture instead of the old Pi/Codex `linear-work` copy.
- Next links:
  - `workflow/skills/`
  - `tests/workflow-docs-smoke.sh`
  - `scripts/deploy-codex`
  - `scripts/deploy-workflow`
