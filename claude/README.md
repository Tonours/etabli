# Claude

Claude Code-specific files for `etabli`.

## Installed surface

`scripts/install.sh` links:

- `CLAUDE.md` -> `~/.claude/CLAUDE.md`
- `../PLAN_TEMPLATE.md` -> `~/.claude/PLAN_TEMPLATE.md`
- `../PLAN_TEMPLATE_FULL.md` -> `~/.claude/PLAN_TEMPLATE_FULL.md`
- `../workflow/` -> `~/.claude/workflow`
- `commands/*.md` -> `~/.claude/commands/`
- `skills/*` -> `~/.claude/skills/`
- `hooks/*.mjs` -> `~/.claude/hooks/`
- `settings.workflow-hooks.json` -> `~/.claude/settings.workflow-hooks.json`
- selected shared docs from `../workflow/` -> `~/.claude/`

## Workflow

Canonical contract: `../workflow/spec.md`.

Claude commands are thin wrappers over that contract:

- `/plan` from `commands/plan-create.md`
- `/plan-loop`
- `/plan-implement`
- `/implement`
- `/review`
- `/verify-workflow`
- `/bug-check`
- `/linear-ticket-create`
- `/linear-work`
- `/pr-review`
- `/pr-qa`
- `/sec-pr`
- `/ci-fix`
- `/github-pr-review`

Additional local wrappers:

- `/adversary`
- `/commit`
- `/cross-repo-audit`
- `/linear-project-setup`
- `/spec-guide`
- `/spec-verify`

`/verify-workflow` is the Etabli workflow verifier. Keep Claude Code's native
`/verify` free for app/runtime verification.

`/adr` (from `skills/adr/`) records an Architecture Decision Record for a
decision made in the session. It is user-invoked: it reads the conversation and
the working diff, applies a three-condition test (hard to reverse, surprising
without context, real trade-off), proposes a draft for approval, then writes an
immutable `docs/adr/NNNN-slug.md` and updates a `CLAUDE.md` index. It never
writes without explicit confirmation. See `skills/adr/ADR-FORMAT.md`.

Linear commands use Linear MCP. PR review, QA, security PR audit, and CI fix use
the `gh` CLI, not the GitHub MCP/app connector, unless explicitly overridden.
`/github-pr-review` is a compatibility alias for `/pr-review`.

Optional hooks:

- `workflow-router.mjs` injects compact route context through
  `UserPromptSubmit`.
- `plan-ready-guard.mjs` blocks implementation writes and mutating Bash commands
  when a root `PLAN.md` exists but is not `READY`.
- `detect-adr-signal.mjs` runs on `Stop`. When a structural file changed and the
  last assistant message reads like a decision, it surfaces a `systemMessage`
  suggesting `/adr`. It never writes, never calls an LLM, and uses `systemMessage`
  (not `additionalContext`) so it does not resume the turn. The `/adr` skill works
  without it; the hook only lowers the cost of remembering to record decisions.
- `settings.workflow-hooks.json` is a merge fragment. It is linked for manual
  activation and is not merged into `~/.claude/settings.json` by the installer,
  because the live settings file can contain secrets. Activating it enables the
  `UserPromptSubmit`, `PreToolUse`, and `Stop` hooks above.

Use Claude Code `/goal` for till-done loops:

```text
/goal <measurable done condition, validation command, constraints, and stop limit>
```

Prefer `/goal` over a custom task continuation hook unless the done condition
requires deterministic script evaluation across every session.

Rules:

- one execution artifact: `PLAN.md`
- implement only from `Status: READY`
- no `REVIEW.md`
- review with `../workflow/review-rubric.md`

## Notes

`commands/plan-create.md` installs as `/plan` because `PLAN.md` is gitignored and case-insensitive filesystems are common.
