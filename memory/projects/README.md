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
