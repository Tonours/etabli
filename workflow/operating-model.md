# Claude + Pi Operating Model

This document explains how to run one workflow across Claude and Pi with minimal idle time.

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
- choose whether work stays single-threaded or becomes parallel
- arbitrate between alternative implementations
- decide keep / discard / merge
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
- one worker per worktree / isolated scope
- never use multiple workers on the same file cluster without explicit isolation

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

## Worktree rule

Use worktrees to isolate parallel work.

Use a separate worktree when:
- comparing two or more implementation options
- testing a risky optimization candidate
- splitting clearly disjoint approved slices
- separating active implementation from review or measurement work

Do **not** parallelize workers inside one mutable working tree.

## Daily execution modes

### 1. Simple mode
Use when the task is small and the path is obvious.

Flow:
1. open/create worktree
2. run plan loop until `READY`
3. run one worker
4. review the diff
5. run focused checks
6. run manual QA
7. merge or hand off

Default staffing:
- 1 main session
- 1 worker
- optional reviewer at the end

### 2. Standard mode
Use when the task benefits from parallel support but has one main implementation path.

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

### 3. Option-compare mode
Use when the right implementation is unclear and comparison is cheaper than debate.

Flow:
1. main session creates one shared `PLAN.md`
2. define explicit comparison gates before code changes
3. create isolated worktrees per option
4. run one worker per option worktree
5. review and measure each option independently
6. keep one option or discard all
7. merge only the chosen path

Default staffing:
- 1 main session
- 2-3 workers in separate worktrees
- 1 reviewer

Best fit:
- performance work
- local architecture choices
- risky refactors with clear success metrics

## Zero-idle loop

The goal is not “maximum concurrency.”
The goal is to keep the human off the critical path when no arbitration is needed.

While a worker runs, the main session should do one of these:
- review the previous slice
- annotate current findings in the review inbox
- prepare manual QA scenarios
- prepare the next slice or next task
- compare alternative worktree outputs
- run focused measurements

Avoid spending time watching the agent type unless the task is actively unstable.

## Kickoff protocol

For a new task:
1. `cw new ...` or `cw open ...`
2. gather minimal context directly or via `scout`
3. run `plan-loop`
4. critique until `PLAN.md` is `READY`
5. choose the execution mode
6. launch only the roles justified by the task

Never implement from `DRAFT` or `CHALLENGED`.

If you want a lighter scripted kickoff, use:
- `scripts/cw-mode simple <repo|path> "<task>"`
- `scripts/cw-mode standard <repo|path> "<task>"`
- `scripts/cw-mode option-compare <repo|path> "<task>"`

This wrapper still uses `cw` underneath. It only creates/reuses the expected worktrees and prints the next Claude/Pi steps.

If you want to feed the launcher into shell aliases or later wrappers, add `--print-shell` to emit shell-safe exports for the created worktrees.

If you just want a lightweight tmux jump command, add `--print-tmux` to emit a short attach/select snippet for the main target.

If you want short daily shell functions, source `scripts/cw-mode-aliases.sh`. It provides thin wrappers: `cws`, `cwstd`, `cwcmp`, and `cwtmux`. `scripts/install.sh` now adds this sourcing line to Bash/Zsh rc files for convenience.

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
- worktree coordination
- review inbox and tooling-heavy loops

This mapping is a convenience, not a contract. Either runtime may be the main session if it follows the same workflow contract.

## Anti-patterns

Avoid:
- implementing before `READY`
- running multiple workers on the same area without isolation
- creating a second mandatory planning artifact
- using parallelism just to keep agents busy
- leaving `PLAN.md` stale during active work
- postponing all review until the very end
- treating startup chatter as progress instead of validated slice movement

## Minimal command set

### Shared workflow
- `cw new <repo> <task> [prefix]`
- `cw open <repo> [branch|path|name]`
- `cw pick <repo>`
- `scripts/cw-mode <simple|standard|option-compare> <repo|path> "<task>"`
- `scripts/cw-mode <mode> <repo|path> "<task>" --print-shell`
- `scripts/cw-mode <mode> <repo|path> "<task>" --print-tmux`
- `source scripts/cw-mode-aliases.sh`
- `cws|cwstd|cwcmp <repo|path> "<task>"`
- `cwtmux <mode> <repo|path> "<task>"`

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
- real uncertainty, measurable comparison, isolated worktrees available -> option-compare mode

If in doubt, start in standard mode.
