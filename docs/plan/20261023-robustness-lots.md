# Implemented: etabli robustness, speed and efficiency, lots 1-6 of the 2026-10-22 audit

## Metadata
- Archived: 2026-10-23
- Source plan: `PLAN.md` — etabli robustness, speed and efficiency, lots 1-6 of the 2026-10-22 audit (68 points)
- Source plan SHA-256: `f0ecdf47e947faac38f0b99e9fe2678b3c4d1313d884e28099b16636e5e9d0e9`
- Status: IMPLEMENTED
- Commit / branch: eight runs fast-forwarded into `main`, `c20c7e5c..e262565d` (R0 `test/validation-surface` a54989ac, R1 `fix/guard-supply-chain` 8b986188, R2 `fix/pr-review-robustness` 00bb472f, R3 `fix/atomic-settings-writes` 70ef4936, R4 `fix/version-drift` 9883f9ec, R5 `perf/guard-hot-path` 226b8dc2, R6 `test/ci-suite-speed` ea1d318e, R7 `refactor/contract-diet` b42e8ec0, then ee8ea3bd and `fix/hunter-notice-race` e262565d)
- Workflow initiative: none

## Outcome
- R0: `core` no longer needs the network, the fix-links smoke runs on a repo copy, `shell-syntax` covers `claude/`, and no check passes vacuously.
- R1:
  - The read-only Bash guard denies every probe shape: `awk`, `sed` and `sort` are denied outright; a guard error or malformed stdin blocks.
  - A tracked pre-push hook and a CI job run a sha256-pinned gitleaks and fail closed.
  - Pi packages are pinned with identity matching.
  - `update-vendor-skills --commit` is gone, rtk installs from a pinned commit, and a Unicode scan rejects hidden characters while keeping U+00A0 and U+202F.
- R2:
  - PR review approves only after a complete council with valid markers.
  - Retries split deterministic from transient failures.
  - Every `claude -p` pass goes through one capped helper with usage logging.
  - The delta pass is read-only and skips on an identical `git patch-id`.
  - The validator leaves bypass on E1 evidence.
  - Signals and launchd neither orphan nor kill a review.
  - The codex path is deleted.
- R3: every settings writer is atomic with bounded timestamp backups. One failing sync no longer hides the other. Link, exclude and argument edge cases are safe. etabli's own `.workflow/` is gone.
- R4:
  - One pinned Pi; the managed install is removed, freeing 495 MB.
  - bun 1.3.14 and Node 22.22.0 are pinned in CI, and the rtk version is logged.
  - One DNS order, and the installer keeps personal models.
  - Scaffold drift is classified STALE or EDITED and refreshed without `.bak`.
  - The dead scaffold payload is retired, and 615 identical satellite backups are deleted.
- R5:
  - The comment lexer is linear: a 160k one-line write went from 15.4 s to about 40 ms.
  - Ruby and `caseDepth` are removed, with identical verdicts on a 1,214-file corpus.
  - A hung rtk no longer stalls a tool call.
  - The Pi rtk runtime shrank by 539 lines, extensions use the session cwd, and the statusline makes one git call.
- R6: CI has job timeouts and the version-bump pins. The scaffold, PR-review and hooks suites are split or batched, so `full` went from a 33.2 s median to 19.3 s (58 %). The `pi-review-hunter` watchdog is fail-closed.
- R7:
  - One no-pause rule; an eight-row route table with first-match precedence; duplicated rules have one home.
  - Read-only agents drop the memory step and end on `STATUS: complete|truncated`; the adversary runs with `omitClaudeMd`.
  - `prototype`, `review` and `wizard` are demoted: the Claude index went from 5,085 to 4,364 characters, the Pi block from 7,110 to 6,308.
  - The global instructions became `claude/claude-global.md`, so sessions reading `claude/` no longer reload them as nested memory.
  - The installer shows failed steps and exits nonzero.

## Context
- `scripts/verify-agentic-infra` runs `workflow/runtime/agentic-infra-checks.tsv` through a FIFO semaphore; `core` is 12 checks, `full` 39.
- `pi -p` hangs on an open stdin; every scripted call feeds it `/dev/null`.
- Non-interactive bash prints a job notice for a background job killed by a signal other than INT, TERM or PIPE. If SIGCHLD is handled before `wait`, the notice prints outside `wait 2>/dev/null` (CI run 39944302049). `pi-review-hunter` now holds stderr on `/dev/null` from the kill through the status capture.
- `printf | grep -q` under `pipefail` can return 141 when grep exits between printf's writes; tests use `grep ... >/dev/null`.
- `deploy-agent-workflow --apply` stops at the first failing Claude skill load check, before the `CLAUDE_CONFIG_DIR` root. Any ungoverned live skill therefore leaves the second root stale.

## Decisions
### Eight sequential runs, one plan
- Context: 68 audit points across guards, PR automation, settings, versions, hot paths, tests and contracts.
- Choice: R0 to R7 in order, each in its own worktree and branch, under a T1/T2/D1/D2 review budget; a rebase invalidates review evidence (D1, D28).
- Rejected options: one branch per lot without a shared plan, or one large branch.
- Rationale: R0 makes later checks real; each review stays bounded.
- Consequences: R1 merged on a user decision while `blocked` after D2 (D37); R4 needed one extra review round on a user decision.

### Delete before adding
- Context: the user constraint "no new feature, prefer deletion".
- Choice: remove the codex path, ruby and `caseDepth`, the managed Pi install, the dead scaffold payload, `update-vendor-skills --commit` and the contract duplicates. P36 (NotebookEdit guard) is dropped (D24); the link prune is kept (D25).
- Consequences: R5 alone was +351/-887 and R7 +244/-360.

### Accepted without a code change
- D11 `localeCompare` ordering, D14 the statusline keeps untracked files, D36 the Homebrew bootstrap keeps its moving ref.
- D42 to D44: lexer edge cases.
- D45: `SECONDS` truncation in `pi-review-hunter` (fail-closed near the limit).

### Governance of the `fleet` skill
- Context: a personal `fleet` skill linked at 2026-10-23 12:13 from `/Volumes/Crucial/work/fleet` was ungoverned and made `--apply` fail. In R7 that failure left the `CLAUDE_CONFIG_DIR` `CLAUDE.md` link stale after the rename.
- Choice: list `fleet` in `claude/machine-local-skills.json` and set it `on` in both live maps, which keeps its pre-R7 visibility.
- Rejected options: `--fix`, which would make it user-invocable-only and change behavior without the user.
- Consequences: the Claude index stays under the 4,912 gate (4,364). The user can demote it in one line.

## Accepted Drift
- R1: S1.2 was skipped, and the D2 folds merged unreviewed (D37).
- R3: APFS renames over a symlink are not atomic for concurrent readers, so readers tolerate a vanished link (`readLinkOrNull`).
- R4:
  - The custom-default step stays.
  - Only the 8 deploy-removed model ids moved to `retired_pi_models`.
  - The three retired exclude lines stay in `scripts/deploy-workflow`.
- R5: `appendCode` bounds the code tail; the parity rows for deleted code are removed.
- R6:
  - The hunter watchdog and `pi-skill-load-check` stdin fixes were outside the R6 list.
  - The PR-review signals smoke is split.
  - The coolify DMI pin moved to `skill-hygiene`.
- R7:
  - Two `etabli-only` hits remain in code comments that the no-comments hook forbids editing.
  - `PINNED_ON` lives in `scripts/lib/claude-skill-load-check.mjs`.
  - `mcp/servers.template.json` needed no edit.
  - The failure summary, the nonzero exit and the generic hunter timeout in `review.md` are review folds.
- Bookkeeping: AC-5 to AC-35 were ticked only at archive time. A read-only audit mapped them to the run notes. AC-9, AC-12, AC-15, AC-16 and AC-26 were closed by static checks on main e262565d.

## Validation Evidence
- command: `scripts/verify-agentic-infra full` on main e262565d
  - result: 39/39 PASS (baseline at planning 34 checks, 26.9 s; R6 median 19.3 s)
- command: `scripts/verify-agentic-infra core`
  - result: 12/12 PASS on main ee8ea3bd, also offline since R0
- command: `bun test pi/extensions/__tests__/`
  - result: 62 pass
- command: `scripts/deploy-agent-workflow --apply` then `--check` on main
  - result: rc 0, 0 issues; both `CLAUDE.md` links point at `claude/claude-global.md`
- command: `gitleaks git --no-banner --redact .`
  - result: rc 0, no leaks, 3.95 s
- command: `scripts/deploy-workflow --check` on the nine satellites
  - result: rc 0 on 8; kibun skipped for its root `PLAN.md` (D18)
- command: CI `agentic-infra` on main
  - result: run 39945852750 green on e262565d
- command: `claude -p` session reading `claude/RTK.md`
  - result: 0 `nested_memory` records (11 older transcripts recorded one for `claude/CLAUDE.md`)
- Review provenance: each run used Logic and Spec `reviewer` hunters (claude-opus-5-5) plus codex-cli `gpt-6.1-sol`. Patch hashes, sessions and verdicts per round are in the source plan's Notes; the hash above identifies it.

## Follow-up State
- Remaining risks:
  - The macbook-work legs are unmeasured: the first real watcher and autoreview run (R2), and the Q1 census for `worker`, `spec`, `bug-check`, `employer-backend-suite` and the D10 caps.
  - A post-R7 `scout` ended without the `STATUS:` line in a session that loaded agents before the merge; it was not rechecked.
- Parking lot (report only):
  - `fleet` governance choice.
  - zsh `pi()` `--tui-mode` bug.
  - The deepseek warning.
  - The live Pi settings dead keys (`lastChangelogVersion`, `tasksTillDone`, `rtk.dangerousCommandBypass`).
  - oh-ca-va's 3 retired copies.
  - The obvault LaunchAgent PATH.
  - kibun scaffold refresh once its `PLAN.md` closes.
- Superseded docs/specs: `claude/CLAUDE.md` (now `claude/claude-global.md`).
- Next links: `docs/adr/`, `workflow/spec.md`.
