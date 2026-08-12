# Implemented: Claude scoped-script deployment parity

## Metadata
- Archived: 2026-08-12
- Source plan: Restore Claude scoped-script deployment parity
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome
- `deploy-agent-workflow` now deploys every top-level script entry from each active Claude scope.
- `check-fix-symlinks.sh` now detects and repairs missing or wrong scoped-script links.
- Existing smokes pin both work-scope deployment and shared-scope isolation; no new workflow or test harness was added.

## Context
- `claude/scopes/work/scripts/`: six top-level entries were added upstream but were only linked by the full installer.
- `scripts/deploy-agent-workflow`: the daily scoped deploy path omitted scripts while already handling commands, skills, and agents.
- `scripts/check-fix-symlinks.sh`: the local alignment report could not observe the omitted surface.
- `scripts/workflow-retrospect --json`: 261 historical observations, zero confirmed recurring issue at the configured threshold, so no contract/process change was justified.

## Decisions
### Extend existing active-scope loops
- Context: scope selection and link helpers already existed in both tools.
- Choice: enumerate top-level `scripts/` entries beside agents and reuse `link_path` / `check_link`.
- Rejected options: a new script manifest, a new checker, or a generalized deployment abstraction.
- Rationale: the smallest change restores parity with `scripts/lib/install-main.sh` and keeps remediation messages consistent.
- Consequences: future active-scope script files and directories are deployed and verified automatically.

### Preserve local scope policy
- Context: `/Users/tonours/.etabli-scope` was absent during the run.
- Choice: test `ETABLI_SCOPE=work` only in disposable homes and leave the real scope unchanged.
- Rejected options: writing `work` into the local scope file or deploying employer-specific scripts implicitly.
- Rationale: activating a machine scope is a separate policy decision, not part of repository parity.
- Consequences: real local behavior remains shared-only until explicitly configured.

## Accepted Drift
- Original plan/spec: none.
- Implemented reality: exactly the four planned files changed; no accepted drift.
- Why accepted: not applicable.

## Validation Evidence
- command: `bash tests/deploy-agent-workflow-smoke.sh`
  - result: pass; all six work-script entries linked and shared-only isolation preserved.
- command: `bash tests/fix-links-smoke.sh`
  - result: pass; an incorrect file link and a missing directory link were repaired.
- command: `scripts/verify-agentic-infra all`
  - result: pass through the full deterministic profile.
- command: `git diff --check`
  - result: pass.
- review: same-context supervised diff review and code-diff adversary both returned `GO`; no correctness finding remained.

## Follow-up State
- Remaining risks: shellcheck was unavailable; Bash syntax and repository shell smokes passed instead.
- Parking lot: local `work` scope activation remains a separate explicit decision.
- Superseded docs/specs: none.
- Next links: `claude/README.md`, `scripts/lib/install-main.sh`.
