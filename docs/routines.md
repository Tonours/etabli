# Routine run records

A routine is a scheduled job with an end. Each run of a wrapped routine leaves
the same small record under `~/.claude/state/routines/<name>/` (override the
folder with `ETABLI_ROUTINES_DIR`), so one reader can say what ran, when and
how it ended. This page is record contract v1 and the `run` wrapper; adoption
of existing launchd jobs is described when it ships.

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

`adopt`, `release` and `status` exit 2 with "not implemented" until they ship.

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
or `end` until the file exists; `<file>.reached` says it got there).
