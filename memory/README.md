# Memory

This directory documents the minimal local-memory pattern for `etabli`.

## Goal

Improve session continuity without adding an external memory system or a heavy knowledge base.

## Magic docs fit

`pi-magic-docs` complements this memory pattern.

Use it only to keep `memory/projects/<repo>/current-focus.md` fresh when Pi actually reads or edits that file during a session.
Do not treat it as a replacement for project memory selection, `PLAN.md`, or handoff files.

## Rule

Track the memory contract and templates in git.
Keep real per-project memory local by default.

## Structure

- `memory/projects/README.md`
- `memory/projects/_template/`
- `memory/projects/<repo>/...` for real local entries

Use project memory for durable facts only.
Use `.pi/handoff.md` or `.pi/handoff-implement.md` for short-lived session continuation.
Magic docs are upkeep help for `current-focus.md`, not a second memory backend.
