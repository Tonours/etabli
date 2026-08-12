---
name: session-handoff
description: Create a compact, evidence-backed resume pack for an active coding or agent session. Use before pausing, changing runtime, handing work to another agent or person, or resuming a long task when the next action, completed validations, blockers, changed paths, and do-not-redo items must be recovered without rereading the transcript.
---

# Session Handoff

Use `scripts/session-handoff` as the preferred read-only projection of the
current `PLAN.md`, active Etabli event ledger, and Git state.

```bash
scripts/session-handoff
scripts/session-handoff --json
scripts/session-handoff --run <ledger-slug>
```

## Workflow

1. Resolve the active run from `.workflow/.active-run.json` or require an
   explicit `--run` when selection is unavailable or ambiguous.
2. Generate the pack from current artifacts. Do not use conversation memory as
   the source of truth.
3. Check that the pack names the objective, verified current state, decisions,
   completed slices, validation evidence, blocker, next action, and do-not-redo
   items.
4. Label unavailable Git, plan, ledger, or validation evidence explicitly.
5. Keep the result to one screen. Link to source artifacts instead of copying
   logs or transcript content.

This skill is distinct from `/recap`: recap summarizes a period from Git/GitHub;
handoff transfers the restart state of one active run. Do not create a second
progress file, archive a task, mutate the ledger, or claim completion.
