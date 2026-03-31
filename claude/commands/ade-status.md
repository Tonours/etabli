---
description: Read the exported ADE snapshot for the current worktree and summarize it
allowed-tools: [Read, Bash]
---

# ADE Status

Read the exported ADE snapshot for the current cwd and return a concise summary.

## Steps

1. Determine the current working directory.
2. Build the snapshot path using this exact sanitization rule:
   - replace every run of characters outside `[A-Za-z0-9._-]` with `_`
   - path = `~/.pi/status/<sanitized-cwd>.ade.json`
3. Read the snapshot file.
4. If the snapshot file is missing:
   - say that no ADE snapshot is exported for the current cwd
   - show the expected path
   - suggest opening Neovim in that worktree and running `:ADEStatus` or `:ADEDoctor`
5. If the snapshot file exists but is invalid:
   - report that the ADE snapshot is invalid
   - show the expected path
   - include the parse/validation error if available
6. If the snapshot is valid, summarize only:
   - plan status
   - next action
   - review line + whether it is `stored` or `live`
   - runtime phase/tool/model if present
   - handoff state
   - mode + whether it is explicit or default
   - warnings, if any
7. Keep the output short and operational.

## Rules

- Do not recompute ADE logic from source files.
- Do not refresh review state.
- Do not edit any files.
- Treat `nextAction` as a hint, not an automation instruction.
