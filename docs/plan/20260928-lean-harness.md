# Implemented: lean harness — guard escapes closed, adversary ledger data, Claude session state, pointer removed, two cost experiments settled

## Metadata
- Archived: 2026-09-28
- Source plan: `PLAN.md` — lean harness — 7 slices (read-only guard, action pin, adversary ledger data, Claude session state, simplifications, capsule screening, Jev pilot)
- Source plan SHA-256: `a29e3040debabc8e403238ad31798c6fce18e5f5997665912bc69d6cc3fe1e71`
- Status: IMPLEMENTED
- Commit / branch: `refactor/lean-harness` (worktree `/Volumes/Crucial/work/etabli-lean-harness`), base `5c6d3fb`, reviewed head `9e51dac`; not pushed, merged or deployed
- Workflow initiative: `lean-harness`, closed as documented `blocked`. Every slice is done and F1 is clean, but core stays at 25/26 until the new SessionStart hook is wired into the live Claude home. This run was not allowed to do that (see Accepted Drift).

## Outcome
- Read-only Bash guard (`workflow/runtime/workflow-router-core.mjs`, shared by the Claude read-only agent hook and the Pi and Claude DRAFT mutation guard):
  - executables given by a relative path are denied; absolute system-bin paths are kept;
  - `rg --pre`/`--hostname-bin` are denied;
  - gh short clusters carrying `X`, `f` or `F` are denied;
  - `uniq` takes at most one operand after its options or `--`;
  - the command word must equal the first parsed shell word, which closes quote splicing;
  - outside single quotes, unquoted `$` expansions, braces and backslash-newline continuations are denied;
  - unquoted globs are denied except for plain readers;
  - command substitution was already refused upstream by `splitReadOnlyPipeline`, and still is.
- `tailscale/github-action` is pinned to `6cae46e2d796f265265cfcf628b72a32b4d7cade # v3.3.0`. `tests/supply-chain-smoke.sh` scans every workflow and fails on tracked absolute symlinks.
- `scripts/workflow-event append` refuses a new `adversary_completed` in three cases: `model_provenance` is incomplete, the verdict is outside its mode's canon, or an accepted finding is not `{finding, blocking}`. History still validates.
- Claude `SessionStart` (`compact|resume`) runs the hook `claude/hooks/session-state.mjs`. It re-injects the root plan headline and the session-handoff pack: done, pending, decisions, validations, blocker, next action and do-not-redo. The text starts with `COMPACT_INSTRUCTIONS` from the router core. Pi's compaction now uses the same constant, and `claude/CLAUDE.md` carries it verbatim, pinned by a bun test. `autoMemoryEnabled: false` is tracked in `claude/settings.skill-overrides.json` and synced.
- Simplifications:
  - the Pi route-contract pointer is removed (the message and its contract evidence), and `route_decided` now dedupes by route;
  - the duplicate `router-parity` core row is removed, and a test pins one row per target;
  - the worker doc row is fixed;
  - `pi/extensions/pi-mobile-bridge.ts` is now a relative symlink.
- Experiments are archived in `docs/research/20260928-lean-harness-experiments.md`:
  - P5: pointer removed;
  - P6: screening negative, saving of at most 1.45 %;
  - P7: inconclusive, A kept, adapter deleted.

## Context
- `tests/guards-active-smoke.sh` has a live branch that compares the live Claude `settings.json` with the repo hook fragment. Any new fragment hook therefore stays red in core until it is deployed.
- Each code-diff adversary round found another shell-level bypass of the read-only guard:
  - T1: quote splicing, `$` and brace expansion, and `uniq --`;
  - T2: a backslash-newline continuation inside an option.
  A probe also showed `uniq A*` overwriting a file through glob expansion.
- PreCompact output cannot change the compaction instructions. SessionStart `additionalContext` on `compact|resume` can re-inject state.

## Decisions
### Fail-closed shell hazards instead of a shell parser
- Context: the guard trusted basenames and a few flags, but shell expansion can reshape argv after the check.
- Choice: deny a segment in any of these cases:
  - its command word differs from the first parsed word;
  - it carries an unquoted expansion, a brace or a continuation;
  - it has a glob and the command is argv-sensitive or not a plain reader.
- Rejected options: emulating bash expansion (large and never complete); allowlisting more flags per command.
- Consequences: harmless idioms such as `rg $HOME`, `git diff *` and `find *` are now denied. That fails closed, which the plan accepts.

### Tighten appends, never re-judge history
- Choice: `append` enforces provenance, a canon verdict and `{finding, blocking}` findings. `validate` keeps accepting both historical families.
- Consequences: the census diff is clean on a sealed copy of 130 ledgers (118 OK, 12 quarantined, no flip).

### One source for the compact instructions
- Choice: the router core exports `COMPACT_INSTRUCTIONS`. Pi's compaction and the Claude SessionStart hook both use it, and `claude/CLAUDE.md` carries the same sentence, pinned by a test.
- Rejected options: a PreCompact hook, which cannot change the instructions; a second copy inside the hook.

### Claude auto memory off
- Choice: `autoMemoryEnabled: false` in the Etabli fragment.
- Rationale: no reason to keep it was found. Etabli's durable memory is the vault plus the ledger handoff, and auto memory would be a second store that nobody reviews.

### Experiments keep A, except the Pi pointer
- P5: the pre-registered keep rule was not met, so the pointer was removed. The pointer era has only 2 sessions.
- P6: the screening is negative. The zero-size capsule bound is far below the 20 % threshold, so the capsule was never written.
- P7: no admissible B rule was found, so B = A. The held-out set is below its floor, so the result is inconclusive and the adapter was deleted.

### Live-branch conflict
- Choice:
  - keep the hook in the canonical fragment;
  - weaken no check and add no parallel fragment;
  - prove the deployed state on a disposable copy of the Claude home;
  - print the deploy commands instead of running them.

## Accepted Drift
- Original plan/spec: core all PASS after every slice (AC8), and a `completed` ledger that passes the autonomous-completed profile (AC9).
- Implemented reality:
  - from slice 4 on, core is 25/26, and the only red check is the `guards-active` live branch (`not wired: SessionStart/compact|resume … session-state.mjs`);
  - the same check passes against a disposable copy of the live Claude home after `scripts/claude-hooks-merge`;
  - the ledger closes `blocked`, with a handoff that names the deploy.
- Why accepted: the goal forbids deploys and live `~/.claude` mutation and asks for the deploy command to be printed instead. Weakening the live check and splitting the fragment were both rejected.

## Validation Evidence
- command: `bun test pi/extensions/__tests__/`
  - result: 354 pass / 0 fail at `9e51dac` (357 at the start; the pointer tests were removed with the pointer)
- command: `scripts/verify-agentic-infra core`
  - result: 27/27 at the start. At `9e51dac` it is 25/26 out of 26 labels, and only the `guards-active` live branch fails.
- command: `LIVE_HOME=/tmp/lean-harness/deployed-home bash tests/guards-active-smoke.sh`
  - result: `PASS: guards-active fixture + live assertions`, with `claude-hooks-check: ok, all fragment hooks wired`
- command: `bash tests/dual-runtime-guard-matrix-smoke.sh`, `bash tests/claude-hooks-smoke.sh`, `bash tests/supply-chain-smoke.sh`, `bash tests/workflow-event-smoke.sh`
  - result: exit 0 each
- command: `scripts/workflow-ledger-census --dir /tmp/lean-harness/ledgers diff .workflow/lean-harness/census-baseline.tsv`
  - result: clean
- command: `scripts/token-bench --check`, plus a comparison with the frozen start (`dacc77bf…e936`)
  - result: exit 0 and nothing above the start. plan-implement 66502 → 66424, implement 61149 → 61071, ship 94337 → 94259; the other routes are equal.
- command: `git diff --shortstat 5c6d3fb..HEAD -- scripts pi/extensions ':(exclude)pi/extensions/__tests__' claude/hooks workflow/runtime`
  - result: 11 files, +124/−152 (net −28), with 0 untracked lines. The whole diff is 31 files, +454/−300.
- Reviews:
  - Plan: 4 Codex gpt-6-astra passes, CHALLENGED three times, then READY.
  - Code T1: Spec GO; Logic GO WITH NOTES; Codex BLOCK. The 3 high and 1 medium findings were accepted and folded.
  - Code T2: Spec GO; Logic GO; Codex BLOCK. The 1 high finding was accepted and folded.
  - D1: clean.
  - F1 on `410de8a1…1134` @ `9e51dac`: clean. Spec GO. Logic BLOCK, rejected: its one high finding on command substitution was disproved by a probe in which all 8 inputs were denied. Codex GO (thread `01a0e5ae-824b-79e0-b6ca-dddb5a44c8a0`).
- Budget: 16 of 30 paid runs; 28 of 2,000 Jev calls, costing 0.00045 $.

## Follow-up State
- Remaining risks:
  - until the deploy, the live Claude home has neither the SessionStart hook nor `autoMemoryEnabled: false`;
  - the P5 removal rests on only 2 pointer-era sessions;
  - the P6 capsule was never tested on quality;
  - P7 needs 15 or more held-out runs with an eligible point and priced provenance.
- Parking lot: none
- Superseded docs/specs: none
- Next links:
  - `docs/research/20260928-lean-harness-experiments.md`;
  - deploy: `git -C /Volumes/Crucial/work/etabli merge --ff-only refactor/lean-harness && /Volumes/Crucial/work/etabli/scripts/deploy-agent-workflow`;
  - then `/Volumes/Crucial/work/etabli/scripts/claude-hooks-merge --dry-run`, a review, the real merge, and `scripts/verify-agentic-infra core`.
