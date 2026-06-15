# Claude

Claude Code-specific files for `etabli`.

## Installed surface

`scripts/install.sh` links:

- `CLAUDE.md` -> `~/.claude/CLAUDE.md`
- `../PLAN_TEMPLATE.md` -> `~/.claude/PLAN_TEMPLATE.md`
- `../PLAN_TEMPLATE_FULL.md` -> `~/.claude/PLAN_TEMPLATE_FULL.md`
- `../workflow/` -> `~/.claude/workflow`
- `commands/*.md` -> `~/.claude/commands/`
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

`/verify-workflow` is the Etabli workflow verifier. Keep Claude Code's native
`/verify` free for app/runtime verification.

Linear commands use Linear MCP. PR review, QA, security PR audit, and CI fix use
the `gh` CLI, not the GitHub MCP/app connector, unless explicitly overridden.
`/github-pr-review` is a compatibility alias for `/pr-review`.

Optional hooks:

- `workflow-router.mjs` injects compact route context through
  `UserPromptSubmit`.
- `plan-ready-guard.mjs` blocks implementation writes and mutating Bash commands
  when a root `PLAN.md` exists but is not `READY`.
- `settings.workflow-hooks.json` is a merge fragment. It is linked for manual
  activation and is not merged into `~/.claude/settings.json` by the installer,
  because the live settings file can contain secrets.

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
