# Harness context efficiency

This is a dated measurement snapshot from 2026-09-04. It explains why the
repository keeps hot-path instructions short. It is not a current CI result;
run `scripts/workflow-context-budget` and `scripts/verify-agentic-infra core`
for current values.

## Measurements

| Surface | Before | Intermediate | After | Change |
| --- | ---: | ---: | ---: | ---: |
| Claude description index (characters) | 6,141 | 5,250 | 4,290 | -30.14% |
| Pi projected skill block (characters) | 8,635 | 6,838 | 6,578 | -23.82% |
| Pi active tool descriptions and schemas (characters) | 65,101 | — | 31,353 | -51.84% |
| Codex rendered catalog (UTF-8 bytes) | 19,164 | — | 18,691 | -2.47% |

These populations are separate. Their percentages must not be added. The
measurements estimate prompt size, not billed tokens or model quality.

## Current behavior captured by the snapshot

- Pi loads workflow tools lazily. `load_workflow_tools` activates the Task and
  delegation groups only when requested.
- Pi keeps the Adonis suite discoverable and masks its specialist descriptions
  in the default settings. A direct `--skill` request still works.
- Claude descriptions and two shared descriptions were shortened without
  changing skill names or bodies.
- The Pi router preserves the requested thinking effort instead of forcing a
  higher value on selected routes.

The native probes under `.workflow/token-economy/` record the inputs and output
files used for the snapshot. They do not contact a model provider.

## Session hygiene

Added 2026-09-24 after the trace measurements in
`docs/research/20260924-skill-reliability-token-economy.md` §11. Median Claude
calls replayed 204k tokens, and 4 of 403 sessions compacted.

- **Pi.** `pi/extensions/session-hygiene.ts` calls `ctx.compact()` when an
  interactive (`tui`) session settles idle with at least 180k context tokens.
  - Its summary instructions keep the plan, ledger run, modified files, frozen
    checks, open findings and next action.
  - It never runs in print, RPC or JSON mode.
  - It blocks tree navigation, fork and session switch while its compaction is
    in flight.
  - It stops for the session when a compaction leaves the estimate above the
    threshold, or after two consecutive failures. "Nothing to compact" is not counted as a
    failure.
  - Tune with `ETABLI_PI_COMPACT_AT_TOKENS`; disable with
    `ETABLI_PI_AUTO_COMPACT=off`.
  - Limit: a single long run is not bounded until it settles. Pi's native
    compaction near the window still applies.
- **Claude Code.** Hooks cannot run `/compact` or `/clear`.
  - `claude/statusline-command.sh` shows `ctx:<N>k`, the input tokens of the
    last API call (`current_usage`, then `total_input_tokens`): yellow from
    150k, red from 300k, percentage fallback.
  - `claude/CLAUDE.md` carries compact instructions with the same state to keep.

## Skill block (Pi)

Added 2026-09-24 (tranche 2, `docs/plan/20260924-guards-active.md`).
`scripts/pi-skill-load-check` caps the model-facing skill block at 7 190
characters; the live run measured 19 947 before the fix and ~6 600 after.
Specialist skills leave the prompt via `disable-model-invocation: true`,
which hides them from the prompt but keeps `/skill:name` working (a deny
entry would unload them entirely — verified against Pi's resource loader).
Repo skills carry the flag in `pi/skills/*/SKILL.md`; installed copies and
package skills are stamped by `scripts/pi-dmi-stamp` (idempotent,
`--check`, absent-tolerant). The flag is also honored by Claude Code,
Cursor and VS Code, so hiding is consistent across harnesses; no workflow
skill is flagged. Reinstalling an npm skill package wipes its stamp:
`scripts/verify-agentic-infra core` (row `guards-active`) and
`pi-dmi-stamp --check` detect it, re-stamping heals it.

## Limits

The Codex population was partial, so no global catalog budget was adopted. The
pstack compact mode measured larger than the default and was not enabled. A
future runtime-read probe would be needed to compare declared surfaces with
files actually opened during a session.

## Reproduce

```bash
scripts/claude-skill-load-check
scripts/pi-skill-load-check
scripts/workflow-context-budget --json
scripts/verify-agentic-infra core
```

Use `scripts/workflow-context-budget --ratchet` only after a reviewed trim.
Ratcheting lowers a ceiling; it never raises one silently.
