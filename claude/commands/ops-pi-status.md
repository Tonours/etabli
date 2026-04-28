---
description: Read Pi/Neovim shared OPS companion data from Claude Code
argument-hint: [today|projects]
allowed-tools: [Read, Bash]
---

# OPS Pi Status

Read shared OPS companion data for the current cwd.

## Your task

1. Determine what data to read based on the argument:
   - `today` or no argument: read the current OPS task and TillDone files
   - `projects`: read recent/favorite projects

2. Read the appropriate files:
   - TillDone state: `~/.pi/status/<sanitized-cwd>.tilldone-ops.json`
   - OPS task: `~/.pi/status/<sanitized-cwd>.task.json`
   - Projects: `~/.pi/projects.json`

3. Sanitize cwd using the same rule as Pi: replace runs of characters outside `[A-Za-z0-9._-]` with `_`

4. Format and return a concise summary:
   - For TillDone: active task, remaining tasks, total tasks
   - For OPS task: title, lifecycle state, plan status, next action
   - For projects: favorites and recent projects with visit counts

5. If files don't exist, explain what's missing and how to generate the data (e.g., "Run Pi in this cwd to generate TillDone state")

## Rules

- Only read, never write
- Handle missing files gracefully
- Keep output concise and actionable
- Show the sanitized path being read for debugging
