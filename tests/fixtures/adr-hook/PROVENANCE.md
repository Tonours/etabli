# adr-hook fixtures

`real-blocked-stop.jsonl` is not hand-written. It is the `hook_blocking_error`
attachment line as Claude Code **actually wrote it** to `transcript_path` when this
hook blocked a Stop, captured verbatim from a real `claude -p` run and trimmed to the
two keys the hook reads (`type`, `attachment`).

- Claude Code 2.1.247, macOS, 2026-08-27
- The hook under test, loaded with `--plugin-dir`, blocking a Stop in a temp repo
  with an uncommitted `package.json` and a committed ADR in `docs/adr/`
- `blockingError.command` keeps the literal `${CLAUDE_PLUGIN_ROOT}` — the harness
  records the command **unexpanded**, which is why the hook matches on the filename
  rather than on a resolved path
- `blockingError.blockingError` is the reason text as it stood at capture time
  ("changed in this turn"), which `MODEL_INSTRUCTION` has since reworded. The matcher
  never reads that field — only `type`, `hookEvent` and `blockingError.command` — so it
  is left stale on purpose rather than hand-edited, which would break the capture claim
  above. Expect it to differ from the current instruction; that is not harness drift.

`alreadyNudgedThisSession` is only as good as this shape, and no committed fixture can
detect a harness that changes it: CI would keep testing this record and stay green while
production silently re-blocks every turn. What this file buys is narrower and worth
stating plainly:

- the suite tests the shape Claude Code really wrote, not one invented to match the code
- the capture recipe is written down, so the shape can be re-verified after a Claude Code
  upgrade rather than trusted forever
- a drifted harness shows up as the nudge firing every turn, which the Risks section of
  the plan archive names as the expected symptom

Re-capture it the same way when Claude Code is upgraded.
