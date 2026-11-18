---
status: accepted
date: 2026-11-18
tags: [routines, launchd, observability]
affected_components: [claude/scopes/work/scripts/routine, docs/routines.md, tests]
---

# Routines leave a standard run record

Each run of a scheduled routine leaves the same small record under `~/.claude/state/routines/<name>/`: a manifest, the latest run, a bounded journal and the skips. The format is written down in docs/routines.md as record contract v1, with three `source` values (`adopt`, `install`, `native`) and one reserved name, so that a reader such as Fleet can say what ran, when and how it ended, and report a routine that fails or stops running. A bash 3.2 wrapper, `routine.sh run`, writes the record for a command it starts without changing what that command receives; `adopt` and `release` put it in front of an existing launchd calendar job and take it out again, byte for byte. A routine with its own code writes the same files itself. The wrapper takes a kernel lock through Perl, since macOS has no `flock` command, so a dead run never leaves a lock to clear. Rejected: a wrapper that alerts by itself (it cannot report a routine that never starts), `launchctl print` alone (it gives a run count and no time), and a `mkdir` lock with an owner file (it needs a takeover rule). The cost accepted: an adopted job has the wrapper as its main process, so a stop reaches the command one step later and a signal shows as an exit code 128+n.
