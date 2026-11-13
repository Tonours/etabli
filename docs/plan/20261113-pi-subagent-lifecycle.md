# Implemented: reliable Pi subagent launch and parent-death cleanup

## Metadata
- Archived: 2026-11-13
- Source plan: `PLAN.md` - address PR #96 lifecycle review findings
- Source plan SHA-256: `125b369c3a5f720115e416d9be11f06d5d2ae77f07aa74dade833497a2d78394`
- Status: IMPLEMENTED
- Commit / branch: `679a5ed9`, `027a75c8`; `fix/pi-subagent-review`, remote PR branch `feat/pi-subagent-extension`
- Workflow initiative: pi-subagent-lifecycle

## Outcome
- Missing interpreter errors are handled before inspecting the spawned PID; a missing Pi command becomes a failed run with exit127 and its ENOENT detail.
- A small interpreter launcher watches its parent connection. EOF/disconnect kills its own detached group, including descendants; ignoring SIGTERM keeps that watchdog alive during the stop grace period.
- Actual child stdin stays ignored. IPC carries its actual exit status before launcher cleanup. The delayed registry, orphan sweep and unstable process identity hashes are removed.
- Truncated assistant output (`stopReason: length`) is reported failed with the partial text preserved.

## Decisions
- Replace deferred identity recording with direct lifetime cleanup. Pi can change process.title, so waiting longer cannot make its argv hash reliable. No release handshake or persistent replacement subsystem.
- Preserve tool names, isolation flags, existing foreground/background terminal states, independent parents and unrelated process groups.
- Work in an isolated checkout after discovering the campaign alias referenced the original mutable source worktree. C8 now uses an independent frozenfac5781d snapshot; no campaign update or deployment is part of this delivery.
- Merge current main before validation so the branch respects the retired RTK integration.

## Validation Evidence
- Original19 lifecycle tests passed while the two new regressions failed (queued spawn error and immediate parent SIGKILL). Missing interpreter reproduction also crashed Node with an unhandled ENOENT.
- Final24 lifecycle tests pass, covering Node/Bun, empty actual-child stdin, changed process.title, immediate parent death, death during SIGTERM grace, missing executable, descendants, separate parents/bystander, timeout and shutdown.
- `scripts/verify-agentic-infra core`: 15/15; 169 Pi tests, typecheck clean.
- Truncation fixture failed before the terminal-state fix and passes after it.
- Mutation: automatic probe unavailable because its documented isolation excludes detached children. Five isolated manual mutants killed: spawn error listener, stdin EOF cleanup, SIGTERM handler, actual exit code and truncation classification.
- Plan challenge: requested/effective Claude Opus5.5, P1 CHALLENGED at plan hash9b3ee98388406f9bf09ee0bc7e1ed84313666db98e4d67ff82e0939e25996f39; P2 READY at hashd8fa85543fa0c9d6aebb44c02e52eb2c88605b9b6cd9d523f7fdf36115279ea9.
- Fresh native Logic/Spec reviewers: gpt-6.1-sol. Spec complete/no findings; Logic found the MEDIUM length case, subsequently fixed and checked by the final adversary. Deciding-code table complete; Threat n/a, lifecycle internals only.
- Final adversary: user-authorized GLM5.3 via Pi after two Claude HTTP403 Cloudflare failures. GO WITH NOTES, STATUS complete, no new findings; cumulative runtime patch SHA256c4b1c5edf140a345eb98ba24bc7dde96b2039fbc4bdf62e629aa660bdb2cd75a. Native Pi session01a1d451-4cfe-7643-a013-c19a40b51599 has9 assistant envelopes, all providerzai/modelglm-5.3; this supplies effective provenance despite the null T3 executedModel field.
- simplify: registry/sweep/hash removed, no replacement persistence. quality: TypeScript/Node conventions compared with subagent-agents.ts and workflow-tools.ts; no new dependency.

## Follow-up State
- Push and GitHub CI/re-review follow this archive; no merge, deployment or live model campaign invocation performed.
- Normal Node/Bun executable names required; compiled or renamed interpreters are explicitly unsupported. Prompt scratch files may remain after a parent SIGKILL.
- IPC exit-message ordering is empirically exercised, not a platform contract; a reversed order would conservatively report failure. Existing theoretical PGID-reuse window remains; no persisted PID is ever scanned or signaled.
- Keep PR #96 open for the existing C8 validation condition. Keep the isolated fix worktree while PR is open.
