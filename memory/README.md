# Memory

This directory documents the minimal local-memory pattern for `etabli`.

## Goal

Improve session continuity without adding an external memory system or a heavy knowledge base.

## Rule

Track the memory contract and templates in git.
Keep real per-project memory local by default.

## Structure

- `memory/projects/README.md`
- `memory/projects/_template/`
- `memory/projects/<repo>/...` for real local entries

Use project memory for durable facts only.
Use `.pi/handoff.md` or `.pi/handoff-implement.md` for short-lived session continuation.
