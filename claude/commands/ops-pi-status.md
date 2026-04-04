---
description: Read Pi extensions data (TillDone, metrics, projects) from Claude Code
argument-hint: [today|summary|projects]
allowed-tools: [Read, Bash]
---

# OPS Pi Status

Read shared workflow data from Pi extensions for a unified view.

## Your task

1. Determine what data to read based on the argument:
   - `today` or no argument → Read today's TillDone and metrics
   - `summary` → Read last 7 days summary
   - `projects` → Read recent/favorite projects list

2. Read the appropriate files from `~/.pi/status/` and `~/.pi/metrics/`:
   - TillDone state: `~/.pi/status/<sanitized-cwd>.tilldone-ops.json`
   - OPS task: `~/.pi/status/<sanitized-cwd>.task.json`
   - Daily metrics: `~/.pi/metrics/<YYYY-MM-DD>.json`
   - Projects: `~/.pi/projects.json`

3. Sanitize cwd using the same rule as Pi: replace runs of characters outside `[A-Za-z0-9._-]` with `_`

4. Format and return a concise summary:
   - For TillDone: active task, remaining tasks, total tasks
   - For metrics: sessions today, total time, phase breakdown
   - For projects: favorites and recent projects with visit counts

5. If files don't exist, explain what's missing and how to generate the data (e.g., "Run Pi in this cwd to generate TillDone state")

## Rules

- Only read, never write
- Handle missing files gracefully
- Keep output concise and actionable
- Show the sanitized path being read for debugging
