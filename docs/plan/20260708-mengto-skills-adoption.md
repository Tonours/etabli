# Implemented: MengTo skill adoption for Etabli

## Metadata
- Archived: 2026-07-08
- Source plan: MengTo skill adoption for Etabli
- Status: IMPLEMENTED
- Commit / branch: `main` at `2a97637`; changes are uncommitted

## Outcome
- Added `docs/mengto-skills-analysis.md` as the adoption ledger for
  `MengTo/Skills`.
- Added three Codex-visible skills:
  - `codex/skills/browser-full-page-capture/`
  - `codex/skills/frontend-motion-performance/`
  - `codex/skills/ui-reference-capture/`
- Added `codex/skills/browser-full-page-capture/scripts/stitch-full-page-capture.mjs`
  for settled viewport capture plus `ffmpeg` stitching.
- Updated the maintained `CODEX_VISIBLE_CODEX_SKILLS` arrays in:
  - `scripts/deploy-agent-workflow`
  - `scripts/install.sh`
  - `scripts/check-fix-symlinks.sh`
- Pinned the new runtime-visible skill surface in smoke and consistency tests.

## Context
- Source inspected: https://github.com/MengTo/Skills
- GitHub API tree inspection found 73 tracked `SKILL.md` files while the
  upstream README claimed 75 skills.
- `workflow/skill-design.md` requires procedural skills, explicit invocation,
  references separated from workflow, and mechanical checks for new invariants.
- `scripts/deploy-codex` deploys tracked `codex/` files, while
  `scripts/deploy-agent-workflow`, `scripts/install.sh`, and
  `scripts/check-fix-symlinks.sh` control `~/.agents/skills` visibility.

## Decisions
### Adopt Operational Workflows, Not The Whole Library
- Context: the upstream repo is heavily weighted toward web-design style lanes.
- Choice: adopt three operational skills: full-page capture, frontend motion
  performance, and UI reference capture.
- Rejected options: import all upstream skills or expose visual style lanes as
  default runtime skills.
- Rationale: Etabli benefits from reusable browser/UI evidence workflows, but
  default routing should not become visually opinionated.
- Consequences: the new skill surface is narrow and test-pinned.

### Expose The Three Skills Through Codex-Visible Links
- Context: repo-tracked `codex/skills` files deploy into `.codex`, but current
  Codex runtime visibility also depends on `~/.agents/skills` symlinks.
- Choice: add the three skills to `CODEX_VISIBLE_CODEX_SKILLS` in the three
  bootstrap/check scripts.
- Rejected options: only add files under `codex/skills` and hope runtime
  discovery refreshes.
- Rationale: previous Etabli skill visibility work showed runtime-visible
  symlinks are the reliable deployed surface.
- Consequences: deploy and fix-links smoke tests now pin the new links.

### Keep The Capture Helper Dependency-Aware
- Context: the upstream stitched capture workflow is useful, but dependencies
  should not be installed implicitly.
- Choice: write a local helper that uses project-provided Playwright and system
  `ffmpeg`, and fails clearly when either is unavailable.
- Rejected options: add undeclared image-processing dependencies or mutate the
  local environment during capture.
- Rationale: Etabli skills should provide repeatable workflow assets without
  hidden setup side effects.
- Consequences: runtime capture still needs a project with Playwright and
  `ffmpeg`, but syntax and deployment are validated here.

## Accepted Drift
- Original plan/spec: the helper dependency note mentioned an image-processing
  package during planning.
- Implemented reality: the helper avoids that dependency and uses `ffmpeg` for
  crop/stitch operations.
- Why accepted: the plan adversary pass identified undeclared dependencies as a
  real maintainability risk.

## Validation Evidence
- `node --check codex/skills/browser-full-page-capture/scripts/stitch-full-page-capture.mjs`
  - result: passed
- `node codex/skills/browser-full-page-capture/scripts/stitch-full-page-capture.mjs --help`
  - result: passed
- `bash tests/codex-organization-smoke.sh`
  - result: passed
- `bash tests/deploy-agent-workflow-smoke.sh`
  - result: passed
- `bash tests/fix-links-smoke.sh`
  - result: passed
- `bun test pi/extensions/__tests__/`
  - result: passed, 198 tests
- `bun test pi/extensions/__tests__/settings-consistency.test.ts`
  - result: passed, 5 tests after the helper cleanup
- `scripts/workflow-event validate mengto-skills-adoption`
  - result: passed before archive, 21 events
- `git diff --check`
  - result: passed
- Plan adversary:
  - result: `READY`
  - accepted finding: avoid undeclared helper dependency
  - rejected finding: add a global skill validator in this slice
- Code-diff adversary:
  - result: `GO WITH NOTES`
  - accepted finding fixed: clamp section crop coordinates and avoid unused
    stdout pipes in the helper
  - rejected finding: live browser capture was not required because no captured
    artifact was claimed

## Follow-up State
- Remaining risks: the helper has syntax and help-path validation, but no live
  page capture fixture was added in this slice.
- Parking lot: if these skills are used often, add a small local HTML fixture
  and an opt-in capture smoke that skips cleanly when Playwright or `ffmpeg` is
  unavailable.
- Superseded docs/specs: none.
- Next links:
  - `docs/mengto-skills-analysis.md`
  - `codex/skills/browser-full-page-capture/SKILL.md`
  - `codex/skills/frontend-motion-performance/SKILL.md`
  - `codex/skills/ui-reference-capture/SKILL.md`
