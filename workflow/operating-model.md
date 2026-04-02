# Claude + Pi Operating Model

This document explains how to run one workflow across Claude and Pi without worktree-oriented ceremony.

## Principle

Claude and Pi are runtime surfaces over the same execution contract.

Shared contract:
- `PLAN.md` is the single execution contract
- `DRAFT | CHALLENGED | READY` are the same status gates
- implementation follows ordered slices
- review stays plan-aware
- the human keeps intent, arbitration, approval, and final QA

Runtime differences are allowed at the entrypoint level, not at the workflow-contract level.

## Roles

### Main session
One session owns the task.

Responsibilities:
- clarify intent
- drive `plan-loop`
- decide when `PLAN.md` is `READY`
- arbitrate implementation direction
- run or approve final QA

The main session can be Claude or Pi.

### Scout
Use for bounded reconnaissance.

Good fit:
- map files and dependencies
- identify risks and edge cases
- collect context before planning

Default:
- read-only
- parallel-safe

### Worker
Use for bounded implementation.

Good fit:
- implement one approved slice
- run the slice checks
- keep `PLAN.md` implementation tracking current

Default:
- one worker for the active mutable checkout
- do not run multiple workers against the same mutable code at once

### Reviewer
Use for focused review.

Good fit:
- plan-compliance review
- adversarial review
- regression and edge-case scanning
- diff feedback before final QA

Default:
- read-only
- parallel-safe

## Daily execution modes

### 1. Simple mode
Use when the task is small and the path is obvious.

Flow:
1. inspect current repo state
2. run plan loop until `READY`
3. run one worker
4. review the diff
5. run focused checks
6. run manual QA
7. hand off or commit

Default staffing:
- 1 main session
- 1 worker
- optional reviewer at the end

### 2. Standard mode
Use when the task benefits from parallel support but still has one main implementation path.

Flow:
1. main session drives `plan-loop`
2. scout maps the area or validates assumptions
3. main session hardens `PLAN.md` to `READY`
4. worker implements slices in order
5. reviewer checks the current diff or previous slice while the worker runs
6. human prepares QA while review and implementation are in flight
7. worker addresses review findings
8. final checks + QA + decision

Default staffing:
- 1 main session
- 1 scout
- 1 worker
- 1 reviewer

## Zero-idle loop

The goal is not “maximum concurrency.”
The goal is to keep the human off the critical path when no arbitration is needed.

While a worker runs, the main session should do one of these:
- review the previous slice
- annotate current findings in the review inbox
- prepare manual QA scenarios
- prepare the next slice or next task
- run focused measurements

Avoid spending time watching the agent type unless the task is actively unstable.

## Kickoff protocol

For a new task:
1. inspect current repo state
2. gather minimal context directly or via `scout`
3. run `plan-loop`
4. critique until `PLAN.md` is `READY`
5. launch only the roles justified by the task

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

## Review and QA pipeline

Do not treat review as a single final wall.

Preferred pipeline:
- small implementation step
- focused review
- quick correction
- next slice

Final gate remains:
- relevant tests/type-checks pass
- review findings are addressed or consciously accepted
- manual QA is done by the human

## Runtime mapping

### Claude-first usage
Common fit:
- work tasks
- main implementation session
- focused code review
- business-domain iteration

### Pi-first usage
Common fit:
- personal environment
- local orchestration
- Neovim cockpit flow
- review inbox and tooling-heavy loops

This mapping is a convenience, not a contract. Either runtime may be the main session if it follows the same workflow contract.

## Anti-patterns

Avoid:
- implementing before `READY`
- running multiple workers on the same mutable area at once
- creating a second mandatory planning artifact
- using parallelism just to keep agents busy
- leaving `PLAN.md` stale during active work
- postponing all review until the very end
- treating startup chatter as progress instead of validated slice movement

## Minimal command set

### Shared workflow
- inspect the current repo
- `PLAN.md`
- review inbox / focused tests / manual QA

### Pi
- `/skill:plan-loop <task>`
- `/skill:implement`
- `/review`
- `/scout <task>`
- `/worker <task>`
- `/reviewer <task>`

### Claude
- `/plan-loop`
- `/implement`
- `/review`
- tracked command wrappers under `claude/commands/`

## Decision heuristic

Use the smallest mode that fits:
- obvious task -> simple mode
- one implementation path, some parallel support helps -> standard mode

If in doubt, start in standard mode.
