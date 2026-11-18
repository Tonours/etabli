# Implemented: local gates green again, batched-reads rule shipped, read-only guard blocks on stall

## Metadata
- Archived: 2026-11-18
- Source plan: `PLAN.md` — green local gates again (Pi skill block, Pi runtime test), ship the batched-reads rule, make the read-only agent guard fail closed on timeout
- Source plan SHA-256: `2b1f4690fadb66b6b287d126d354410fe73fc6f10dddfa95235bee94df981b72`
- Status: IMPLEMENTED
- Commit / branch: #116 `9e19a581` (fix/pi-skill-gate), #117 `a03558c5` (perf/claude-batch-reads), #118 `41202915` (fix/pi-runtime-test), #119 `a8d9fb9a` (fix/agent-guard-timeout)
- Workflow initiative: agent-gates

## Outcome
- `scripts/verify-agentic-infra core` is 17/17 on this machine again (was 15/17).
- The live Pi skill block is 7316 chars, under the 7800 gate (was 9927). `scripts/pi-dmi-stamp` stamps `reverse-any-video` and `style-sampling`, and a B1 failure names `scripts/pi-dmi-stamp --home ...` as its repair.
- The installed-loader test resolves a compiled `pi` launcher through its sibling `package.json`, rejects a non-Pi package and a failing `--version`, and reports a version mismatch.
- `claude/claude-global.md` tells Claude to batch independent reads and searches.
- `adversary`, `reviewer` and `scout` run their read-only guard with `timeout: 10` and `onFailure: block`; `tests/claude-agents-smoke.sh` pins both keys.

## Context
- A hyperframes reinstall on 2026-11-17 reset the DMI stamps and added two skills; stamping the four known names alone left 8228 chars.
- Pi 1.5.2 from mise is a compiled binary with no `cli.js` and no `loader.js`; the old test only knew script launchers.
- A Claude Code command hook that times out is non-blocking by default (600 s); `onFailure: block` (2.1.295+) turns a stall into a block. Experiment E1 (`claude -p --agents`, guard wrapped in `sleep 20`) showed `timed out; blocking because onFailure is "block"`; the control ran.
- Project-agent frontmatter hooks are skipped in untrusted folders under `-p`; `--agents` JSON definitions run them.

## Decisions
### Stamp list over the Pi deny-list
- Context: six specialist skills overflowed the block.
- Choice: add names to `ROOT_NAMES` in `scripts/pi-dmi-stamp`.
- Rejected options: Pi settings deny-list.
- Rationale: keeps `/skill:name`, no settings deploy.
- Consequences: a reinstall resets the stamps; the B1 message now names the repair.

### Compiled fixtures clone the running bun binary
- Context: copies of macOS system binaries do not execute.
- Choice: `copyFileSync(process.execPath, ..., COPYFILE_FICLONE)` with `Bun.version` as the matching control.
- Rejected options: `/usr/bin/true`, `/usr/bin/printf`, `/bin/echo` copies.
- Rationale: runs on Linux, macOS and CI.
- Consequences: none beyond a cloned binary per fixture in a temp dir.

### Session hooks out of scope
- Context: `claude/settings.workflow-hooks.json` guards have the same fail-open shape.
- Choice: left as is.
- Rationale: they guard the writer session, lower harm, settings-sync surface.
- Consequences: a separate plan if wanted.

## Accepted Drift
- Original plan/spec: AC-3 named a `/usr/bin/true` fixture and `2 pass`.
- Implemented reality: five fixtures on a cloned `bun`, 7 pass; the `--version` status check removed in simplify came back on the cross-model adversary's round-2 BLOCK.
- Why accepted: the adversary showed the earlier fixtures passed for the wrong reason on macOS and survived removal of the comparison.
- Original plan/spec: S4 touched agent frontmatter and the smoke only.
- Implemented reality: `claude/README.md` also names the stall case and the 2.1.295 floor (Logic and Threat low findings).
- Why accepted: docs must match the enforced contract.

## Validation Evidence
- command: `scripts/verify-agentic-infra core` at `a8d9fb9a`
  - result: 17/17
- command: `scripts/pi-skill-load-check` live
  - result: `pi-skill-load-check: ok`, `model_block_chars=7316`
- command: `cd pi && bun test extensions/__tests__/installed-extension-loader.test.ts`
  - result: 7 pass on Linux (compiled) and on `macbook-work` (script)
- command: `bash tests/claude-agents-smoke.sh`
  - result: fails before S4, ok after; 9 hand mutants killed
- command: review per slice
  - result: GLM Logic, Spec (and Threat on S4) hunters plus a `openai/gpt-6.1-sol` diff adversary; S1 GO, S2 GO WITH NOTES after BLOCK, S3 GO WITH NOTES, S4 GO; CI green on all four PRs

## Follow-up State
- Remaining risks: mutation probe unavailable on Linux (hand mutants instead); on a compiled install the loader test uses the repo-pinned loader; a future hyperframes reinstall resets the stamps; the `pr-review-flow-smoke` watchdog once outlived its finished group (17 min hang, passed on rerun).
- Parking lot: session-hook `onFailure` hardening.
- Superseded docs/specs: none.
- Next links: re-measure token usage on 2026-11-25 with `~/.cache/etabli-usage-measure/`; the `macbook-work` pull meets its local `claude/claude-global.md` edit.
