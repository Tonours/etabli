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
