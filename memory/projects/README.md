# Project Memory

Project memory is a minimal file-based cache for durable project context.

## What belongs here

- durable facts worth reusing
- decisions already made
- recurring pitfalls
- current focus for an active project

## What does not belong here

- transient scratch notes
- generic repo docs already tracked elsewhere
- secrets
- sensitive client context that should stay local
- session-by-session handoff text

## Tracking rule

This repo tracks:
- this README
- the `_template/` directory
- the local `.gitignore`

This repo does not track real `memory/projects/<repo>/...` entries by default.
Create them locally from `_template/` when needed.

## Suggested layout per project

- `memory/projects/<repo>/README.md`
- `memory/projects/<repo>/decisions.md`
- `memory/projects/<repo>/pitfalls.md`
- `memory/projects/<repo>/current-focus.md`

## Usage rule

Prefer short bullets.
Update only when the information is likely to matter in a future session.

## Magic docs rule

Use `pi-magic-docs` only for `memory/projects/<repo>/current-focus.md` by default.

- keep the rest of the project-memory files manual
- let Pi refresh only `current-focus.md` when it has actually touched that file in-session
- do not use any project-memory file for session-by-session handoff or plan execution state
