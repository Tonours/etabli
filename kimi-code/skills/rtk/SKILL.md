---
name: rtk
description: >
  Token-optimized shell output via the `rtk` proxy. Compresses build, test, git,
  gh, lint, and search output so less context is burned on verbose CLI noise.
  Always available: if rtk has no filter for a command it passes it through
  unchanged, so it is always safe. Trigger when the user asks to save tokens,
  compact output, reduce noise, use rtk, or when running long-output build/test/
  git/gh commands.
---

# RTK — token-optimized commands

`rtk` (installed at `~/.local/bin/rtk`) is a CLI proxy that filters and
summarizes command output before it reaches the context window. This is the
kimi-code equivalent of pi's `rtk` extension: here it is opt-in per command
(kimi-code has no auto-rewrite hook), so **you must prefix commands yourself**.

## Golden Rule

**Always prefix commands with `rtk`.** If rtk has a dedicated filter, it uses
it (often 60–95% fewer tokens). If not, the command runs unchanged — rtk is
always safe.

```bash
# Wrong
git add . && git commit -m "msg" && git push

# Right — prefix every command in a chain
rtk git add . && rtk git commit -m "msg" && rtk git push
```

If unsure whether a command is supported, probe with `rtk rewrite`:

```bash
REWRITTEN=$(rtk rewrite "my-command") && echo "$REWRITTEN"   # exit 0 + rewrite if supported
rtk rewrite "my-command" || echo "no rtk equivalent"         # exit 1 if unsupported
```

`rtk rewrite` is idempotent and never fails a run — fall back to the raw
command when it prints nothing.

## Commands by workflow

### Build & compile
```bash
rtk tsc               # TypeScript errors grouped by file/code
rtk lint              # ESLint/Biome violations grouped by rule
rtk next build        # Next.js build with route metrics
rtk pnpm install      # compact install output
rtk pnpm list         # compact dependency tree
rtk pnpm outdated     # compact outdated packages
```

### Test — failures only
```bash
rtk test <cmd>        # generic wrapper, failures only
rtk jest              # jest failures only
rtk vitest            # vitest failures only
rtk playwright test   # playwright failures only
```

### Git (all subcommands pass through)
```bash
rtk git status        # compact status
rtk git log           # compact log (works with all git flags)
rtk git diff          # compact diff
rtk git show          # compact show
rtk git add/commit/push/pull   # ultra-compact confirmations
```

### GitHub
```bash
rtk gh pr view <num>  # compact PR view
rtk gh pr checks      # compact PR checks
rtk gh run list       # compact workflow runs
rtk gh issue list     # compact issue list
```

### Files & search
```bash
rtk ls                # token-optimized listing
rtk tree              # token-optimized tree
rtk read <file>       # read with intelligent filtering
rtk grep              # compact grep, grouped by file
rtk find              # compact find output
rtk diff              # condensed diff (changed lines only)
```

### Logs & diagnostics
```bash
rtk err <cmd>         # run command, show only errors/warnings
rtk log <cmd>         # filter and deduplicate log output
rtk wc                # word/line/byte count, compact
rtk env               # environment variables, sensitive masked
```

## When NOT to use rtk

- Output you must inspect verbatim (exact bytes, encoding issues, binary).
- Interactive prompts / TUIs (`rtk` is non-interactive).
- Commands whose exit behavior you assert on (still safe, but no savings).

## Probes and savings

```bash
rtk gain              # show cumulative token savings + history
rtk config            # show or create the rtk config file
```

## Discipline

- Prefix proactively for build/test/git/gh/lint — the common noisy cases.
- Don't wrap tiny commands (`pwd`, `echo`) — overhead exceeds the gain.
- If a command misbehaves under `rtk`, drop the prefix and retry raw; report
  the regression rather than working around it silently.
