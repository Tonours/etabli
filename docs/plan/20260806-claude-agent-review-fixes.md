# Implemented: Fix Claude agent hardening review findings

## Metadata

- Archived: 2026-08-06
- Source plan: `PLAN.md`
- Source plan SHA-256: `d181735784701ff18e99b34dfc4d094ecd5c10a8b9670c7eeadc8e7339d70c7c`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`
- Reviewed commits: `f1d96a7`, `b6f20fc`

## Outcome

- Hardened the read-only Bash classifier: `sed`, `sort`, and mutating `find`
  actions are denied, including `rtk` wrappers and quoted `find -exec` tokens.
- Aligned the shared orchestration contract around one writer at any instant:
  Claude may use one foreground-or-awaited worker for a bounded READY step;
  the current Pi profile remains parent-only while subagent support is unknown.
- Removed mutation-capable `Bash` pre-approval from source-read-only Claude
  commands and documented that `allowed-tools` grants permission rather than
  enforcing a sandbox.
- Installer, deployer, and repairer now prune only broken Claude-agent symlinks
  whose targets are inside this repo's legacy `claude/agents/` directory or a
  current `claude/scopes/*/agents/` directory.
- `scout` and `reviewer` now resolve the memory contract from the workspace,
  then the installed `~/.claude/workflow/` fallback, or report it unavailable.
- Repaired the three stale Playwright agent links in the live Claude install;
  the post-check reports zero issues.

## Context

- The original guard allowed `sed -n 'w ...'` and
  `sort --compress-program=...`, so prose-level read-only intent could be
  bypassed through pre-approved Bash.
- Shared workflow sources disagreed about whether one bounded implementation
  worker was allowed, leaving parent/worker write sequencing ambiguous.
- The repair checker verified current agents but ignored removed managed agents,
  leaving three broken Playwright symlinks under `~/.claude/agents`.
- Globally installed scout/reviewer prompts depended only on a workspace-relative
  memory-contract path.

## Decisions

### Prefer conservative denial to partial shell-language parsing

- `sed` is denied because its program language can write or execute without an
  in-place flag.
- `sort` is denied because it may create temporary files or execute a compression
  helper.
- `find` remains available for inspection, but exact mutating action tokens are
  rejected after shell tokenization.

### Define managed links by target provenance

- A stale link is removable only when it is a symlink, targets this checkout's
  `claude/agents/` directory, and its target no longer exists.
- Basename matching and broad cleanup were rejected because they could remove a
  personal agent or an unrelated link.

### Keep permission pre-approval semantics explicit

- Source-read-only commands no longer pre-approve `Write`, `Edit`, or bare
  `Bash`; they may still request an ordinary session permission when their body
  needs a read-only shell or `gh` operation.
- The actual shell boundary remains the scoped hook used by `scout` and
  `reviewer`; no OS sandbox is claimed.

## Accepted Drift

- The first plan adversary runner produced no verdict and was stopped after 150
  seconds. A supervised same-model plan adversary returned `GO WITH NOTES`; its
  three accepted strengthenings were encoded in tests.
- The final Claude adversary attempt failed authentication. The independent
  OpenRouter Gemini review succeeded and returned `GO` with no actionable
  finding, so no degraded final-review claim is needed.
- Concurrent commit `f28836b` became HEAD during implementation and added four
  agent-visible frontend skills without updating the Pi settings-consistency
  expected list. Core validation exposed the stale fixture; this archive includes
  the test-only alignment while preserving that commit's runtime surface.

## Validation Evidence

- Focused Claude hook, agent, command, deploy, symlink, installer, workflow, and
  runtime-capability smokes: passed.
- `node --check` for the hook, `bash -n` for changed shell scripts, and
  `git diff --check`: passed.
- `bun test pi/extensions/__tests__/settings-consistency.test.ts`: 6 passed.
- `scripts/verify-agentic-infra core`: passed, including 192 Pi tests, router
  evaluation 53/53, agent scenarios, guard matrices, deployment, supply-chain,
  and workflow-contract coverage.
- `scripts/check-fix-symlinks.sh --fix --verbose`, followed by the read-only
  check: three stale managed links removed; final summary zero issues.
- Final parent diff review and read-only
  `openrouter/google/gemini-3.1-pro-preview` adversary: `GO`, no actionable
  findings.

## Follow-up State

- Remaining risk: the scoped Bash hook is deterministic policy, not an OS-level
  sandbox. New shell commands must remain denied until explicitly classified.
- No commit, push, PR, or external write-back was performed.
- The working tree contains the completed implementation and this archive for
  user review.
