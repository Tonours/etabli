# Implemented: Fleet routines, interactive workflow checks and Durable run gates

## Metadata

- Archived: 2026-11-19
- Source plan: `PLAN.md`
- Source plan SHA-256: `2341a27a1e9618081f51fdb383d0cb09094675d6ce1e9476e9519c7ba5b79fc2`
- Status: IMPLEMENTED
- Branches: Etabli `fix/durable-run-gates`, Fleet `feat/routines-integration` at `ee0da7b`
- Risk tier: high-risk

## Outcome

- Fleet merged the existing routines branch with `main`. Routines and authorized handovers are both available in agent context. The terminal and dashboard show run state and missed slots. Slack incident and recovery delivery is covered by mock transport. [Fleet PR](https://github.com/Tonours/fleet/pull/216)
- Claude Code, Codex and Pi each opened the intended skill and reached the expected stop points in fresh PTYs. The review path captured the actual diff before delegation. The implementation path read the on-disk DRAFT and stopped. The six trees matched their starting state. [Interactive proof](../workflow-assurance.md#interactive-follow-up)
- Durable stores the submitted route separately and preserves it across promotion and restart. A root with an active DRAFT or CHALLENGED plan can discover files and use plan tools. Native writes, edits and non-discovery Bash wait for READY. A plan edit restores the gate.

## Decisions

- Run documents retain the current schema with an optional admission route. A historical run already promoted without that field keeps its previous matching behavior. Future promotion stores the original route atomically.
- Durable reuses the Bash discovery classifier with ordinary Git fetch disabled. Discovery still passes the existing invocation guard. GitHub reads and Git's optional stat refresh remain possible under that policy. The gate covers native code tools. The execution host controls OS isolation.
- The interactive check used disposable repos and disabled delegation. The first ambiguous attempts were fixture permission issues. Valid reruns reproduced neither miss, so no skill instructions changed.
- The Mac mini hosted the fixture because `macbook-work` was unreachable. The plist explicitly set scratch `HOME`, record and LaunchAgents directories. `RunAtLoad` stayed off. The wrapper was copied from `f29d01d2` and verified on both machines.
- Fleet `main` advanced from `e9c6938` to `075de8c` during validation. A second merge kept the two adjacent `routines` and `handovers` fields. A separate test-only commit increased an existing Node fixture's startup budget after the same failure reproduced on clean `main`. The rollback guide now distinguishes databases by the schema supported by the earlier copy.

## Validation Evidence

- Durable hosted fixtures failed first for retry after promotion and mutation from DRAFT. A further probe found that the shared discovery policy permitted fetch before the Durable option excluded it. `bun test durable/__tests__/workflow.test.ts` now passes all 9 tests, including concurrent retries after reopen, conflicting inputs, and discovery and code mutations across DRAFT, READY and CHALLENGED.
- `scripts/verify-agentic-infra durable` passed, including all 357 tests. The first full pass hit a wall-clock fixture failure. A full sequential rerun on the same patch passed. The `pi` group passed 5/5 after a complete sequential retry. The `shell-docs` group passed 48/48 on Ubuntu with Bash 5.2.21, Node 22.22.0 and Bun 1.3.14 after the local smoke fixture stopped progressing.
- The automated mutation probe reported `unavailable (Linux has no sandbox-exec)`. The hosted before/after probes above exercised the three regressions.
- On macOS, `cargo test --locked -p fleet --test routines --test board --test slack --test config --test review_watch --test asks --test thread_handover --test storage` passed all 825 tests on the Rust tree at `cb0891a`. `cargo fmt --check`, `cargo clippy --locked --all-targets -- -D warnings` and `cargo build --release --locked` passed. The later test and documentation commits leave that Rust tree identical.
- The isolated launchd job produced records for exits 0 and 3. The final Fleet Rust tree read both and projected them into JSON and terminal views. An injected clock verified missed slots. The service disappeared after bootout and the default record-store fingerprint matched. The scratch job and build files were removed.
- `node --test scripts/*.test.mjs scripts/daily-improvement/*.test.mjs` passed on Ubuntu with Node 24.19.0. 351 passed and the existing case-insensitive filesystem case skipped.

## Review

- Plan approved by Claude Opus 5.5 (effective) at SHA-256 `0083150fdd3169a8453b6180840da3c342d365a53e0a8fd48e93897c2443ef29` after strengthening planner discovery and launchd isolation.
- Etabli code on `f29d01d2`, patch `4cedf41ba0693a73ec8922bf34f6ef24f3c0d05e4152ea527b02c26852def60b`. Logic GO, Spec no findings, Threat GO WITH NOTES and cross-family Claude Opus 5.5 GO WITH NOTES. The first pass's fetch and legacy matching findings were resolved. Simplify: clean.
- Fleet code on `e9c6938` with later base `075de8c`. Cross-family Claude Opus 5.5 gave GO WITH NOTES to the initial integration and second merge, and GO to the Node fixture delta. The second merge review's rollback documentation note was folded.

## Follow-up State

- Routine activation and any production deployment are separate from this run. No upgrade of the live Fleet daemon, real Slack send or Durable watch rollout was required for validation.
