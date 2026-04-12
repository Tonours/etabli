# Claude + Pi Operating Model

This document explains the simplified workflow shared across Claude and Pi.

## Principle

Claude and Pi stay runtime surfaces over the same execution contract:

- `PLAN.md` is the single execution contract
- `DRAFT | CHALLENGED | READY` are the same status gates
- implementation follows ordered slices
- review stays plan-aware
- the human keeps intent, arbitration, and final QA

The repo now prefers one main session over orchestration layers.

## Default flow

1. inspect current repo state
2. gather the minimum context directly
3. run `plan-loop` until `PLAN.md` is `READY`
4. implement from that plan
5. review the diff
6. run focused checks
7. do manual QA
8. commit or continue

Never implement from `DRAFT` or `CHALLENGED`.

## Slice protocol

For each implementation slice:

1. mark the active slice in `PLAN.md`
2. load only the needed context
3. make the smallest change that advances the slice
4. run slice-local checks
5. summarize the validated outcome in `PLAN.md`
6. decide: continue, correct, or replan

If new facts invalidate the plan, update `PLAN.md` first and restore `READY` before continuing.

## Review and QA

Preferred pipeline:

- small implementation step
- focused review
- quick correction
- next slice

Final gate remains:

- relevant tests or type-checks pass
- review findings are addressed or consciously accepted
- manual QA is done by the human

## Pi command set

- `/skill:plan-loop <task>`
- `/skill:plan-implement <task>`
- `/skill:implement`
- `/review`

## Claude command set

- `/plan-loop`
- `/implement`
- `/review`

## Anti-patterns

Avoid:

- implementing before `READY`
- creating a second mandatory planning artifact
- leaving `PLAN.md` stale during active work
- postponing all review until the very end
- treating startup chatter as progress instead of validated slice movement
