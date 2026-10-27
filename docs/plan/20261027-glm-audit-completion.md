# Implemented: checked, bounded completion for headless security-audit-glm runs

## Metadata
- Archived: 2026-10-27
- Source plan: `PLAN.md` — checked, bounded completion for headless security-audit-glm runs
- Source plan SHA-256: `3074636fc0f3d29acb7dee3b0124b47ea076682e3e4b1e6192c8770ed1f0057c`
- Status: IMPLEMENTED
- Commit / branch: fix/audit-run-completion, base 2b7b3721, commits 90eeceaf, 4eddd14d, 4e0c2885, c38fdec6, 5e417a74 (cumulative diff sha256 `9c84967444ac2cabc88ce3ed0d5972137bf3ab2710221015a4357ed470737bfe`)
- Workflow initiative: none

## Outcome
- `scripts/security-audit-glm --print` succeeds (exit 0) only when Claude exits 0 and this invocation's own run directory holds the seven upstream files as regular non-empty files, `run-metadata.json` says `complete` with the requested profile, both vendored validators pass, the ledger is non-empty with no `planned`/`in_progress` unit, and every `candidate` unit has at least one fingerprint with a record in `findings.json`.
- Distinct exit codes: 0 complete; 1-2 refused before launch; 3 declared incomplete (reason and `REPORT.md` present); 4 missing or invalid reports; 5 Claude failed; 124 deadline; 129/130/143 HUP/INT/TERM. Every failure prints the run directory and the failed predicate.
- `--print` needs a budget (`--timeout SECONDS` or `SECURITY_AUDIT_GLM_TIMEOUT`, at most 8 digits) and node, jq and perl. The prompt carries the absolute deadline and a 90 % wrap-up time asking for the upstream `incomplete` terminal state.
- Output ownership: the default run directory is `~/security-audit-skill/<repo>/run-N`, allocated by exclusive mkdir; an explicit `--out` must not exist and is created exclusively. Dry-run allocates nothing.
- One inline Perl supervisor runs Claude: it leaves the launcher's process group before it forks Claude into a group of its own, takes signals as idempotent USR1 stop requests, sends TERM to Claude's group once (stop request, deadline, or Claude's exit with descendants left) and KILLs it 10 s later. It keeps supervising if the launcher is KILLed.
- Interactive mode keeps `exec`, no deadline and no checks.

## Context
- vendor/cloudflare/skills/security-audit/SKILL.md: two terminal states, complete with both validators passing, or `run_status: "incomplete"` with a reason.
- VALIDATION-AND-REPORTING.md:147: `complete` only when every ledger candidate has an independent final disposition.
- HUNTING.md:219: duplicates are consolidated by root cause and recorded in the unit, with no machine-readable merge relation.
- validate-coverage-ledger.cjs accepts `planned`/`in_progress` units and an empty ledger, and no validator reads `run-metadata.json`; the launcher adds those state checks.
- Before this change the launcher ended with `exec claude`, so a zero exit without any report counted as success (reproduced with a fake Claude).
- Bash starts asynchronous jobs with INT ignored and, without job control, with stdin from /dev/null.

## Decisions
### Bind reports to the invocation by an exclusive directory
- Context: a naive glob could accept an older run's reports; metadata identity fields are model-written.
- Choice: the launcher creates the run directory and names it in the prompt; explicit `--out` must not exist.
- Rejected options: comparing `run_id`/`target` (user decision); accepting an existing empty `--out` (two launches could share it, T2).
- Rationale: ownership comes from a filesystem operation the model cannot fake.
- Consequences: reruns need a new path; refusals leave the existing path untouched.

### Per-unit candidate rule
- Context: upstream records merged duplicate fingerprints in the unit without saying which were merged.
- Choice: each `candidate` unit needs at least one fingerprint with a final record.
- Rejected options: every fingerprint must have a record (rejects every legitimate merge); no cross-check (accepted a candidate with no record at all, T1 high).
- Rationale: the strongest predicate the artifacts support; cross-model reviewer accepted the residual in D1.
- Consequences: necessary, not sufficient; can return a conservative 4 when a merge or a Phase 5 fingerprint change is not relinked in its unit.

### One isolated supervisor instead of per-stop watchdogs
- Context: successive watchdog designs failed review: a group signal killed the watchdog (T2), repeated signals restarted the grace (D1), a signal before the new watchdog's `setpgrp` left no KILL (D2).
- Choice: the supervisor is the only process spawned after the traps, and it isolates itself before Claude exists.
- Rejected options: restarting a dead watchdog (a killed but unreaped watchdog still answers `kill -0`, so the launcher blocks in `wait`); a Node supervisor (user decision).
- Rationale: removes the race structurally and removes state (`stop_group`, `WATCHDOG`, `SWEEPING`).
- Consequences: 0.1 s polling, about 36,000 cheap iterations per hour.

## Accepted Drift
- Original plan/spec: reuse the sandbox's watchdog pattern; explicit `--out` accepted when absent or empty; candidate finalization not cross-checked.
- Implemented reality: inline Perl supervisor in the sandbox's style; `--out` must not exist; per-unit candidate rule; launcher-shared state made concurrency-safe (skill link kept correct, `settings.json` replaced atomically), a pre-existing race exposed by concurrent launches under /bin/bash 3.2.
- Why accepted: each change answers a review finding and is covered by a smoke check that fails on the earlier launcher.

## Validation Evidence
- command: `bash tests/security-audit-glm-smoke.sh` and `/bin/bash tests/security-audit-glm-smoke.sh`
  - result: 57/57 on 5e417a74 on both (baseline 19); shellcheck clean. Each check added after review fails against the launcher it fixed.
- command: `node --test` on the two upstream validator test files
  - result: 65/65, vendor unchanged.
- command: `scripts/verify-agentic-infra core` and `full`
  - result: 11/12 and 39/41 on 5e417a74; pi-tests and pi-audit fail identically on main 2b7b3721.
- command: live `scripts/security-audit-glm <toy> --profile quick --print --timeout 3600` (90eeceaf)
  - result: exit 0 after 1591 s with the sandbox; run_status complete, 7 files, ledger 3 candidate + 2 covered, 2 confirmed (including the planted injection) + 1 needs_validation; matches manual inspection; no container or process left; the later candidate rule also holds on it.
- command: real-binary probes with an invalid key (no billed call)
  - result: on 5e417a74, exit 124 at a 20 s budget under a pseudo-terminal, supervisor and Claude in separate background groups in state `S`, nothing left.
- command: race probe, 40 launches each hit by a TERM to the launcher's group 0-300 ms after start
  - result: 40 x exit 143, no TERM-ignoring descendant left; after a launcher SIGKILL the supervisor still ended Claude at deadline plus grace.
- Reviews: plan adversary passes 1 (claude-opus-5-5, CHALLENGED), 2 (gpt-6.1-sol, CHALLENGED), 3 (gpt-6.1-sol, READY); code rounds T1, T2, D1, D2 (each folded), then a user-granted T3: Logic and Spec hunters GO WITH NOTES, code-diff adversary gpt-6.1-sol (session 01a17c21-1a1c-7a30-9cb8-efd9f6b74816) GO WITH NOTES with no findings.

## Follow-up State
- Remaining risks: per-unit candidate rule is necessary not sufficient; a credential error costs the whole budget (Claude retries until the deadline); a caller ignoring SIGCHLD would make the supervisor spin; an unsignalable descendant ends supervision early; independently detached processes are out of reach; the sandbox preflight has no bound of its own; the live audit predates the supervisor, so TERM reaching real sandbox containers through it is not re-observed.
- Parking lot: smoke checks for early-signal replay, a signal during the validators, a relative `--print --out`, a forced run-N collision and the launcher-SIGKILL case; usage wording for `--print --dry-run`, which still needs a budget.
- Superseded docs/specs: none.
- Next links: Later Live Pilot in the source plan (compare a few similar assigned audits for interventions and human time before changing workflow contracts).
