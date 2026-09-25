---
name: review
description: Review diffs for bugs, regressions, plan drift, and conventions. Use when uncommitted or branch changes need review; not for GitHub PR threads or for writing the fix.
---
<!-- GENERATED:adapter-sync:start -->
skill: review
harness: pi
canonical: workflow/skills/review.md
name: review
description: Review diffs for bugs, regressions, plan drift, and conventions. Use when uncommitted or branch changes need review; not for GitHub PR threads or for writing the fix.
pointer: Adapter for the `review` skill. Read and follow the shared contract in `workflow/skills/review.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Review

Read and follow the shared contract in `workflow/skills/review.md` and the
rubric in `workflow/review-rubric.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


## Procedure

1. Pin the patch once to a non-empty temp file; write Intent.
2. Dispatch the Logic hunter with `scripts/pi-review-hunter` when present,
   else `pi --mode text -p --no-session --no-skills --no-extensions
   --no-context-files --tools read,grep --append-system-prompt
   workflow/templates/review-logic-hunter.md @<patchfile>`. The prompt file
   is the hunter template plus `Axis: Logic`, Intent, and
   `Standards: yes|none`. Timeout 600s
   (`PI_REVIEW_HUNTER_TIMEOUT`). Spawn/nonzero → `HUNTER_SPAWN_UNAVAILABLE`.
   Timeout → `HUNTER_TIMEOUT`. Either sentinel is a hard stop. Record
   `hunter_model:` (or `hunter_model: default` when `--model` is omitted).
   Do not hunt Logic in the parent.
3. After Logic returns, run Spec in the parent (`spec: parent`), or
   `spec: n/a`.
4. Standards via `code-quality` when the diff has language/UI surface.
5. Lead filter. `isolation: isolated` only if the Logic child ran.
   `GO` forbidden if `isolation: none`.

## Rules

- Stay read-only unless the user explicitly asks for validation beyond review.
- `GO` forbidden if a runtime deciding-code row is empty or `not run`.
- End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
