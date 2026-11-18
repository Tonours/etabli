# Routine run records

A routine is a scheduled job with an end. Each run of a wrapped routine leaves
the same small record under `~/.claude/state/routines/<name>/` (override the
folder with `ETABLI_ROUTINES_DIR`), so one reader can say what ran, when and
how it ended. This page is record contract v1, the `run` wrapper, and
`adopt`, `release` and `status`, which wrap existing launchd calendar jobs.

Names match `[a-z0-9-]{1,40}`. The name `fleet-improvement` and the label
`com.tonours.fleet-improvement` are reserved for a routine that writes its own
record: the wrapper refuses that name, and a folder whose manifest says
`source: native` or carries that label, whatever its name.

## Files

| File | Written by | Content |
| --- | --- | --- |
| `routine.json` | `adopt` (and a later `install`; a native writer itself) | the manifest |
| `last.json` | the holder of the run lock | the latest admitted run |
| `runs.jsonl` | the holder of the run lock | one line per ended run and per `off` or `cap` skip |
| `runs.1.jsonl` | the holder, by rename | the previous journal |
| `busy/<time>-<pid>-<random>.json` | any start that finds the lock held | one `busy` skip per file |
| `admitted` | the holder | one line `<local date> <run>` per admitted run |
| `cap` | the owner or `adopt` | an integer: most runs admitted per local day |
| `off` | the owner | stops this routine; `off` in the parent folder stops all |
| `run.lock` | the wrapper, once | an empty regular file, never removed or renamed |

`go.<run>` and `summary.<run>` are short-lived files of one run; the next
holder deletes any it finds.

### `routine.json`

`v`, `name`, `label`, `tz`, `slots` (a list of `{weekday, hour, minute}`,
`weekday` null for a daily slot), `adopted`, `source` (`adopt`, `install` or
`native`), `origin` and `command` (absent for `native`). The wrapper only reads
this file, for `source` and `label`.

### `last.json`

`v`, `name`, `run` (`<UTC start>-<pid>-<random>`, never reused), `state`
(`running`, `ok`, `failed`), `pid`, `pid_born`, `started`, `cmd_pid`,
`cmd_born`, `ended`, `exit`, `signal`, `summary`. Times are UTC,
`2026-11-18T01:21:40Z`. `pid_born` and `cmd_born` are what
`LC_ALL=C TZ=UTC ps -o lstart= -p <pid>` prints, single-spaced
(`Wed Nov 18 01:21:40 2026`): the second the kernel recorded at the birth of
the process. A reader tells a live process from a reused pid by comparing it.
`exit` is the command's exit status (128+n when a signal ended it); `signal`
is the signal the wrapper passed on (`TERM`, `HUP`; an `INT` is passed as
`TERM`), else null. `summary` is at most 200 bytes of plain text.

The file is written three times, each time through `last.json.<pid>.tmp` and a
rename: `running` before the command's process exists (`cmd_pid`, `cmd_born`,
`ended`, `exit`, `signal` null), `running` again with `cmd_pid` and `cmd_born`
before that process is let into the command, then the end record.

### `runs.jsonl` and `busy/`

Journal lines carry `v`, `name`, `kind` (`run` or `skip`) and:

- a run: `run`, `state`, `started`, `ended`, `exit`, `signal`, `summary`;
- a skip: `reason` (`off` or `cap`) and `time`; a `cap` skip caused by a clock
  set back also has `"clock":true`.

The journal is only appended to, one write per line, and renamed to
`runs.1.jsonl` once it reaches 250 lines, replacing the previous one. A `busy`
skip is written without the run lock, so it never touches the journal: it is
its own file in `busy/`, `{v, name, kind: "skip", reason: "busy", time}`, written
under a temporary name then renamed. The file name starts with the time in
microseconds. Each start that writes one deletes the oldest files beyond the
100 newest.

### `admitted` and `cap`

A run is admitted when the lock is taken, the routine is not `off` and the
count of today's lines is under `cap` (no `cap` file, no cap). An interrupted
run counts, a skip does not. Lines dated before today are dropped when a run is
admitted. A line dated after today means the clock went back: with a `cap`, the
start is skipped as `cap` with `clock`, no line is dropped, until the date
catches up or `admitted` is deleted.

## The wrapper

```
claude/scopes/work/scripts/routine/routine.sh run <name> -- <command...>
```

Order: run lock (else a `busy` skip) → `off` → cap → `admitted` → `running` →
command → end record → rotation → unlock. The command gets the arguments,
environment, stdin, stdout and stderr it had without the wrapper, plus
`ROUTINE_SUMMARY`, the path of a file whose first line becomes `summary`
(passed through `iconv -c -f UTF-8 -t UTF-8`; quotes, backslashes and control
characters removed). The wrapper exits with the command's status.

| Exit | Meaning |
| --- | --- |
| the command's | the command ran (128+n when a signal ended it) |
| 75 | `busy`: another run holds the lock |
| 0 | `off` or `cap` skip |
| 74 | the lock or the folder could not be set up; nothing run, nothing recorded |
| 2 | refused: invalid or reserved name, native folder, malformed call |

`adopt` and `release` use the same codes (see below); `status` exits 0.

### Lock

A kernel lock (`flock`, exclusive, non-blocking) on `run.lock` through
descriptor 9, taken with `/usr/bin/perl` since macOS has no `flock` command.
The command inherits descriptor 9, so the lock lasts while the wrapper or the
command lives and is gone when both are, however they ended: there is no owner
file, no stale lock and nothing to clear by hand. At its normal end the wrapper
unlocks, so a process the command left in the background does not hold the next
run back. A wrapper killed leaves the lock to its command until it ends.

### Start and signals

The command runs in a background subshell that waits for `go.<run>` while the
wrapper is alive (same pid and same birth second), so a wrapper killed before
`go` leaves no command behind. The wrapper records the subshell's identity in
`last.json`, then creates `go.<run>`; the subshell `exec`s the command and keeps
that pid and birth.

`TERM` and `HUP` are passed to the command as the same signal, `INT` as `TERM`.
The wrapper then keeps waiting for the command and ignores further signals
while it writes the end record: `ok` when the status is 0, else `failed`.

## Adoption

```
routine.sh adopt <label> [--name <name>] [--cap <n>]
routine.sh release <label>
routine.sh status
```

`adopt` rewrites `~/Library/LaunchAgents/<label>.plist` so launchd starts
`/bin/bash <routine.sh> run <name> -- <original command...>`, reloads the job,
and writes the manifest. `release` puts the saved original back. The name
defaults to the last dot component of the label. The default `cap` is the most
slots on one local day plus 2; an existing `cap` file is kept.

A plist is adopted only if it is a simple calendar job: no `Program`,
`KeepAlive`, `RunAtLoad` true, `StartInterval`, `Month` or `Day`, and no entry
between 01:00 and 02:59. Weekday 7 is stored as 0 and equal entries are merged.
The job must be loaded, not running, and have no slot in the next 10 minutes; both
are read again right before the job is booted out (under 5 minutes). The
reserved name and label, a name bound to another label, and a label bound to
another name are refused.

Exit codes of `adopt` and `release`: 0 done; 2 refused, nothing changed; 1
failed (the original is put back) or a leftover waits for the next command; 75
another adopt, release or settling holds the lock; 74 the lock or the folder
could not be set up. `status` prints one line per routine and a `lock:` line
telling whether the Perl lock works (exit 74 if not).

### How a change stays safe

Every `adopt` and `release` holds a kernel lock on `adopt.lock` in the routines
folder (descriptor 9, inherited by `launchctl`, so a killed command whose
`launchctl` still runs keeps it). Files are staged as `*.next`, then published
in a fixed order: the origin `plist.before.<id>` and the `cap`, then the
wrapped plist swap, then the commit, a rename of `routine.json.next` over
`routine.json` (release: `routine.json` to `routine.released.json`). `pending`
(kind and id) and `plist.prev` (the plist in place before the swap) are written
first and deleted last. A failure before the commit restores `plist.prev` and
reloads the job. If the restore fails, `adopt.failed` is left, with the manual
commands printed.

Any later `adopt` or `release` first settles every folder holding a `pending`:
a committed change only has its leftovers deleted, without calling launchd; an
uncommitted one is put back, unless the job is loaded with the plist already
equal to `plist.prev`. The job is never booted out for that while it runs or a
slot is under 10 minutes away: the command then exits 2 and the folder stays
`incomplete`.

### States shown by `status`

| State | Meaning |
| --- | --- |
| `adopted` | manifest present, plist wrapped (loaded or not) |
| `released` | `routine.released.json` only |
| `unwrapped` | manifest present but the plist was rewritten by hand; `adopt` wraps it again and takes the hand-written plist as the new origin (the old one is kept); `release` refuses it (exit 2) so a hand rewrite is never lost |
| `incomplete` | a `pending` file waits for settling |
| `broken` | `adopt.failed` is present: the restore failed |
| `native` | `source: native`, written by its own routine |

## What adoption changes for launchd

Nothing else about the job changes: same label, same schedule, same log files,
same environment.

- The main process of the job is now the wrapper, not the command. The command
  is its child.
- A stop sent to the job (`launchctl kill`, `bootout`, a logout) reaches the
  wrapper first. The wrapper passes `TERM` and `HUP` on, and `INT` as `TERM`, so
  the command gets the signal one step later. It then waits for the command and
  does not exit before it.
- A command that a signal ended no longer shows as a signal. The wrapper exits
  with the shell's 128+n (143 for `TERM`), and launchd sees an exit code. The
  record says the same: `exit` 143, and `signal` `TERM` when the wrapper passed
  it on.
- A `KILL` sent to the wrapper alone leaves the command running, and the lock
  with it, until the command ends.
- The job runs `/bin/bash <routine.sh> run <name> -- <command...>`. A tool that
  rewrites the plist and drops that prefix makes the job `unwrapped`, and the
  records stop.

Assumption A1: `Nice` and `LowPriorityIO` set on the job still apply to the
command, since it is a child of the wrapper and inherits both. This is not yet
proved. Check it on the first adopted run of a job that sets them: `ps -o nice=
-p <command pid>` must print the value from the plist. If it does not,
`release` that job.

## A routine that writes its own record (`native`)

It owes the same files in the same format, each through a temporary file and a
rename in the folder: the manifest; `last.json` in state `running` before its
work, with `pid` and `cmd_pid` both its own pid and both births; the end record
before its process exits or gives up whatever keeps a second run out. Before any
write it reads the manifest already in its folder and writes nothing when that
manifest has another `source` or another label. It needs no journal, no `cap`
and no `run.lock`.

## Test hooks

Read only when set, for the smoke test: `ROUTINE_TEST_PERL` (replaces
`/usr/bin/perl` in the lock check), `ROUTINE_TEST_PS` (replaces `ps`),
`ROUTINE_TEST_HOLD=<point>:<file>` (wait at `busy`, `identity`, `go`, `after-go`
or `end`, and in `adopt` and `release` at `staging`, `staged`, `unloaded`,
`verified`, `committed` or `prev-deleted`, until the file exists; `<file>.reached`
says it got there). Also `ROUTINE_TEST_FAIL` (comma list: `mv:<origin|cap|commit|swap>`,
`rm:<released|prev|pending>`, `stage-next`, `stage-manifest`) and `ROUTINE_TEST_CLOCK`
(a file holding `weekday hour minute`). `ROUTINE_PLISTBUDDY`, `ROUTINE_PLUTIL`,
`ROUTINE_LAUNCHCTL`, `ROUTINE_LAUNCHAGENTS_DIR`, `ROUTINE_UID` and `ROUTINE_TZ` replace
the tools, folder, user id and time zone.
