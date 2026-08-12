# Implemented: Verify Mac mini Wake-on-LAN and reduce Zsh startup latency

## Metadata

- Archived: 2026-08-04
- Source plan: `PLAN.md` — Enable verified Wake-on-LAN readiness and reduce interactive Zsh startup latency
- Source plan SHA-256: `fdf32b321093a9e47ae34ff59ecd2593b79a141669c600bc0b3201dd958a9504`
- Status: IMPLEMENTED
- Commit / branch: `main` at `29f04b2` (no commit requested)

## Outcome

- Verified macOS AC power capability and state: `womp 1` is already enabled, so no redundant privileged mutation was performed.
- Reduced the 20-process interactive Zsh startup median from 100.95 ms to 63.47 ms in the final combined check (37.1% reduction); final p95 was 64.14 ms.
- Preserved Oh My Zsh’s Git plugin, Starship, tmux guard, Bun/asdf/Grok completions, Java 17, Pi wrapper, and local LLM functions.
- Created rollback backup `/Users/tonours/.zshrc.etabli-backup-20260804T1850Z` with mode `0600`.

## Context

- `pmset -g custom`: `womp 1` under AC power.
- `pmset -g cap`: Wake-on-LAN capability is present.
- Active default interface: `en1` (Wi-Fi); built-in Ethernet is `en0`.
- `/Users/tonours/.zshrc`: local regular file, not managed by this repository.
- Baseline benchmark: n=20, median 100.95 ms, p95 104.21 ms, min 98.54 ms, max 111.86 ms.
- Measured startup costs included eager Bun completion parsing, a second completion initialization, Java discovery, Starship generation, and a synchronous Keychain lookup.

## Decisions

### Treat current Wake-on-LAN state as configured

- Context: `pmset` already reported `womp 1`; noninteractive sudo was unavailable.
- Choice: verify and preserve the authoritative setting rather than write the same value again.
- Rejected options: unrelated `powernap`/sleep changes and a disruptive sleep test.
- Rationale: no privileged mutation was needed to reach the requested configuration state.
- Consequences: configuration readiness is verified, but an end-to-end sleep/magic-packet wake is not.

### Use one completion initialization

- Context: Bun completion was sourced eagerly and Grok triggered a second `compinit`.
- Choice: register Bun, asdf, and Grok completion directories before Oh My Zsh and let its single initialization autoload them.
- Rejected options: removing Oh My Zsh or weakening completion security checks.
- Rationale: removes measured duplicate work while preserving existing aliases and completion behavior.
- Consequences: zprof now reports one runtime `compinit` call.

### Cache stable generated initialization and defer optional credential I/O

- Context: the first candidate passed behavior checks but measured 81.05 ms, above the frozen 75.71 ms target.
- Choice: cache Starship’s generated Zsh initialization with resolved-binary mtime invalidation and defer the existing Freebox Keychain lookup to a one-shot `preexec` hook.
- Rejected options: writing credential values to a disk cache, dropping the environment variable, weakening the benchmark, or rewriting the shell framework.
- Rationale: the first entered interactive command still receives the token, while prompt startup avoids synchronous Keychain I/O; no credential value changed or entered repository evidence.
- Consequences: prompt-time code cannot read that variable before the first command, but the first command and subsequent shell state can.

## Accepted Drift

- Original plan/spec: completion ordering and Java fast-path were expected to meet the 25% benchmark target.
- Implemented reality: the first candidate reached 81.05 ms, so the READY plan was strengthened with Starship cache and first-command credential-timing checks.
- Why accepted: the frozen latency target and all existing checks were retained; the added changes addressed measured costs without exposing or caching credential values.

## Validation Evidence

- `zsh -n /Users/tonours/.zshrc`:
  - result: passed.
- Tmux-disabled interactive feature assertions:
  - result: Bun/asdf/Grok completions, Starship, Oh My Zsh Git alias, Java 17, Pi wrapper, local LLM functions, and tmux guard passed.
- Static completion assertions plus zprof:
  - result: no explicit second `compinit`, no eager Bun completion source, and exactly one runtime `compinit`.
- Starship cache syntax/freshness assertions:
  - result: cache exists, parses, and is not older than the resolved Starship binary.
- Token-unset first-command assertion:
  - result: first interactive command saw a non-empty Freebox token and the hook unregistered; no value was printed.
- `pmset -g custom` and `pmset -g cap`:
  - result: `womp 1` and capability present.
- Final 20-process benchmark (`FREEBOX_APP_TOKEN` unset, tmux disabled):
  - result: median 63.47 ms, p95 64.14 ms, min 62.57 ms, max 64.22 ms; target <=75.71 ms passed.
- Fresh read-only review (`github-copilot/claude-sonnet-4.6`, tools disabled):
  - result: `GO WITH NOTES`, no blockers; low fallback/redundancy notes did not affect current-machine correctness.
- Adversary code-diff review:
  - result: `GO`, no accepted correctness findings.

## Follow-up State

- Remaining risks: an actual sleep plus external magic-packet wake was not performed; classic WOL is most reliable over wired Ethernet, while this machine currently routes through Wi-Fi `en1`.
- Parking lot: move long-lived credentials out of the broadly readable shell file only under a separate secret-management task; no credential value was changed here.
- Superseded docs/specs: none.
- Rollback: restore `/Users/tonours/.zshrc.etabli-backup-20260804T1850Z`; the generated Starship cache becomes unused after rollback.
- Next links: `.workflow/macmini-wol-zsh-startup/events.jsonl` (local, gitignored run evidence).
