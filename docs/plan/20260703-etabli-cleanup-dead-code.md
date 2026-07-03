# Implemented: Etabli dead-code and duplication cleanup

## Metadata
- Archived: 2026-07-03
- Source plan: Etabli dead-code, duplication, and docs cleanup
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome
- Removed two stale, unreferenced docs that contradicted or lagged current
  workflow state:
  - `docs/pi-agentic-workflow-loop-plan.md`
  - `docs/workflow-scaffold-best-practices-audit.md`
- Updated `docs/workflow-duplication-audit.md` into the current duplication and
  cleanup inventory across Pi, Claude, Codex, and shared workflow contracts.
- Added anti-drift guards for intentional duplicates:
  - root and Codex ticket templates must stay byte-identical;
  - Pi and Codex `linear-work` skills must stay byte-identical;
  - `CODEX_VISIBLE_PI_SKILLS` and `CODEX_VISIBLE_CODEX_SKILLS` must stay
    synchronized across install, deploy, and symlink-check scripts.
- Linked the current duplication audit from `README.md`.

## Cleanup Inventory

### Confirmed and changed
- `docs/pi-agentic-workflow-loop-plan.md`: removed. Evidence: no references
  outside itself; current-state contradictions included "There is no dedicated
  `verify` skill" while `pi/skills/verify/SKILL.md`, `pi/agent/settings.json`,
  `workflow/spec.md`, and `docs/workflow-101.md` all define the verifier route.
- `docs/workflow-scaffold-best-practices-audit.md`: removed. Evidence: no
  references outside itself; it still described already-fixed scaffold surface
  and regression-test gaps as current recommendations. Current contracts live
  in `workflow/spec.md`, `workflow-scaffold/templates/docs/agent-workflow.md`,
  `workflow/plan-archive.md`, and smoke tests.
- `codex/workflow/ticket-template.md` + `workflow/ticket-template.md`: retained
  as intentional deployed fallback duplication; guarded by
  `tests/workflow-docs-smoke.sh`.
- `codex/skills/linear-work/SKILL.md` + `pi/skills/linear-work/SKILL.md`:
  retained as intentional deployed-surface duplication; guarded by
  `tests/workflow-docs-smoke.sh`.
- `CODEX_VISIBLE_*` skill lists in `scripts/install.sh`,
  `scripts/deploy-agent-workflow`, and `scripts/check-fix-symlinks.sh`:
  retained as bootstrap-local lists; guarded by
  `pi/extensions/__tests__/settings-consistency.test.ts`.

### Proxy-supported and retained
- `tests/adr-skill-stress.sh`: no path references, but its header marks it as
  manual, OAuth/cost-bearing, and out of CI; implemented ADR plan archives cite
  the manual ADR test surface.
- Repeated ADR fixture status files and fixture ADR docs: exact duplicate hashes
  are expected golden fixtures.
- Repeated CAD/CAD-adjacent `LICENSE` files: exact duplicate hashes are license
  copies bundled with independent skills.
- `codex/hooks/README.md`: no direct path reference, but it is colocated with
  tracked `codex/hooks.json` and deployed by `scripts/deploy-codex`.

### Unknown / left untouched
- `.workflow/`: ignored local packet evidence, 65 files / about 884K during
  this cleanup. It is not tracked and was left intact because deleting local
  workflow evidence is a separate local-state cleanup decision.
- `docs/command-backlog.md`: unreferenced backlog note, but not contradicted by
  current source-of-truth files. Left as parking-lot material rather than
  deleted speculatively.
- Codex skill directories with low or zero path references: retained because
  `codex/skills/` is a discovery/deployment surface, and lack of repo-internal
  references is not proof that a personal skill is unused.

## Context
- `AGENTS.md` identifies the repo as the dotfiles/control-plane source for
  Codex, Claude Code, Pi, workflow scaffold, scripts, tests, and local skills.
- `workflow/spec.md` requires one active root `PLAN.md`, implementation only
  from `Status: READY`, adversary review before implementation, focused checks,
  implemented-plan archive, then root `PLAN.md` cleanup.
- `scripts/audit-codex-organization` requires the tracked `codex/` tree to stay
  free of runtime state, secrets, and local absolute paths.
- Pre-existing worktree changes in installer/symlink scripts added
  `goal-prompt-rewriter` as a Codex-visible Codex skill. This cleanup preserved
  those changes and added a consistency guard around their duplicated lists.

## Decisions

### Delete stale docs instead of adding warning banners
- Context: both removed docs were unreferenced and described old work as if it
  were still active.
- Choice: delete them and record the supersession in the current duplication
  audit.
- Rejected options: keep with a historical banner; move under `docs/plan/`.
- Rationale: the repo already has implemented-plan archives for history; these
  two docs were neither source of truth nor active archive records.
- Consequences: current docs are smaller; historical context remains represented
  by source-of-truth docs and implemented archives.

### Guard intentional duplicates instead of forcing symlinks
- Context: `scripts/deploy-codex` links files from the tracked `codex/` tree
  into `$CODEX_HOME`, and Codex needs a self-contained fallback ticket template
  plus skill files.
- Choice: keep the duplicate deployed files, but add byte-equality tests.
- Rejected options: symlink `codex/` files back to root/Pi sources; remove the
  Codex copies.
- Rationale: symlinks inside `codex/` would make the deployed Codex surface less
  self-contained and harder to audit.
- Consequences: duplication remains explicit and test-guarded.

### Guard bootstrap list duplication without sourcing a shared shell file
- Context: install, deploy, and symlink-check scripts need the same
  `CODEX_VISIBLE_*` lists, but they run in bootstrap contexts where adding a
  sourced helper file would increase failure modes.
- Choice: parse and compare the lists in the existing Bun settings consistency
  test.
- Rejected options: extract a shared shell file; leave the lists unguarded.
- Rationale: the guard catches drift with low runtime risk.
- Consequences: changing a visible skill list now requires updating all three
  scripts consistently.

## Accepted Drift
- Original plan/spec: "merge duplicated things when defensible."
- Implemented reality: exact deployed duplicates were not physically merged when
  the deployment contract needs self-contained Codex files.
- Why accepted: the safer cleanup is a parity guard plus documentation. Physical
  merging would add symlink/deploy complexity without reducing runtime risk.

## Validation Evidence
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed; `workflow docs smoke test: ok`
- command: `bun test pi/extensions/__tests__/settings-consistency.test.ts`
  - result: passed; 5 pass, 0 fail, 19 expectations
- command: `bash tests/codex-organization-smoke.sh`
  - result: passed; `codex organization smoke test: ok`
- command: `bun test pi/extensions/__tests__/`
  - result: passed; 168 pass, 0 fail, 401 expectations
- command: `bash tests/install-smoke.sh`
  - result: passed; `install smoke test: ok`
- command: `bash tests/deploy-agent-workflow-smoke.sh`
  - result: passed; `deploy agent workflow smoke test: ok`
- command: `bash tests/fix-links-smoke.sh`
  - result: passed; `fix-links smoke test: ok`
- command: `git diff --check`
  - result: passed with no output
- command: `scripts/deploy-codex --dry-run`
  - result: passed; ended with `SUMMARY      dry-run complete`

## Follow-up State
- Remaining risks: none blocking. The remaining unreferenced docs/skills are
  either archives, colocated READMEs, parking-lot notes, manual test surfaces,
  or personal skill discovery surfaces.
- Parking lot: decide separately whether ignored `.workflow/` local artifacts
  should be cleaned, archived, or left as local session evidence.
- Superseded docs/specs:
  - `docs/pi-agentic-workflow-loop-plan.md`
  - `docs/workflow-scaffold-best-practices-audit.md`
- Next links:
  - `docs/workflow-duplication-audit.md`
  - `workflow/spec.md`
  - `workflow/skills/orchestration.md`
