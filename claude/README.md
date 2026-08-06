# Claude

Claude Code-specific files for `etabli`.

## Installed surface

`scripts/install.sh` links:

- `CLAUDE.md` -> `~/.claude/CLAUDE.md`
- `../PLAN_TEMPLATE.md` -> `~/.claude/PLAN_TEMPLATE.md`
- `../PLAN_TEMPLATE_FULL.md` -> `~/.claude/PLAN_TEMPLATE_FULL.md`
- `../workflow/` -> `~/.claude/workflow`
- the same plan templates and `workflow/` are also linked under
  `~/.pi/agent/` and `~/.agents/` so Pi and shared-agent (Grok and future
  harness) relative fallbacks resolve
- `scopes/<scope>/commands/*.md` -> `~/.claude/commands/`
- `scopes/<scope>/skills/*` -> `~/.claude/skills/`
- `scopes/<scope>/agents/*.md` -> `~/.claude/agents/`
- `hooks/*.mjs` -> `~/.claude/hooks/`
- `settings.workflow-hooks.json` -> `~/.claude/settings.workflow-hooks.json`
- selected shared docs from `../workflow/` -> `~/.claude/`

Re-run `scripts/install.sh` any time to refresh links; it is idempotent. When
links look stale or broken (missing command, drift after an update), run
`scripts/check-fix-symlinks.sh` to validate and repair the installed surface.

## Scopes

Commands, skills and agents live under `claude/scopes/<scope>/`:

| Scope | Holds | Deployed |
|---|---|---|
| `shared` | Anything that does not name an employer or a private project | Always |
| `work` | Employer-specific surfaces (employer stack, its repos, its conventions) | Only where the machine declares it |
| `personal` | Private-project surfaces | Only where the machine declares it |

A machine declares one scope in `~/.etabli-scope`, containing exactly `work` or
`personal`. `ETABLI_SCOPE` overrides it for one run. No file and no variable
means `shared` alone, which is the safe default: a new machine never receives
another context's surfaces by accident. An unrecognised value fails the deploy
with exit 2 rather than deploying a partial surface.

Put a surface in `shared` only if it would still make sense at a different
employer. A skill that names a repo, a product, or an internal service belongs
in `work`.

## Workflow

Canonical contract: `../workflow/spec.md`.

Claude commands are thin wrappers over that contract:

- `/plan` from `commands/plan-create.md`
- `/plan-loop`
- `/plan-implement`
- `/ship`
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

Recurring-work commands (from the 2026-07 usage audit; manual-only):

- `/pr-feedback` — fetch, triage, and resolve review feedback on your own PR
- `/pre-commit` — final pass before committing: review, sweep, targeted tests
- `/tests-iso` — add tests indistinguishable from the existing suite
- `/front-quality` — review → React best practices → react-doctor chain
- `/ui-debug` — repro-first UI debugging, one hypothesis per measurement
- `/recap` — evidence-based session/day recap (standup or Slack format)

Custom agents stay bounded:

- `scout` — read-only reconnaissance for one unfamiliar area;
- `worker` — one implementation step from a `READY` plan;
- `reviewer` — fresh-context, findings-first diff review.

`scout` and `reviewer` use an agent-local `PreToolUse` hook to allow only proven
read-only Bash/Git commands. `worker` is the only writing agent and never spawns
another agent.

Playwright QA is packaged as three skills, not extra agents:
`playwright-agentic-testing`, `playwright-test-generation`, and
`playwright-failure-dossier`.

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

- `plan-ready-guard.mjs` blocks implementation writes and mutating Bash commands
  when a root `PLAN.md` exists but is not `READY`; it also composes the
  plan-commit guard so Bash has one PreToolUse process.
- `plan-commit-guard.mjs` denies `git add`/`git commit` calls that would stage
  or commit a root `PLAN*.md`; plans are session artifacts, archives belong in
  `docs/plan/`. Running git manually bypasses it deliberately.
- `read-only-agent-guard.mjs` is wired directly by `scout` and `reviewer`; it
  denies Bash that is not proven read-only even when the optional settings
  fragment is not active.
- `detect-adr-signal.mjs` runs on `Stop`. When a structural file changed and the
  last assistant message reads like a decision, it surfaces a `systemMessage`
  suggesting `/adr`. It never writes, never calls an LLM, and uses `systemMessage`
  (not `additionalContext`) so it does not resume the turn. The `/adr` skill works
  without it; the hook only lowers the cost of remembering to record decisions.
- `settings.workflow-hooks.json` is a merge fragment. It is linked for manual
  activation and is not merged into `~/.claude/settings.json` by the installer,
  because the live settings file can contain secrets. Activating it enables the
  session-wide READY, ledger, ADR, and outcome hooks; the read-only agent hook is
  scoped from agent frontmatter instead.

Use Claude Code `/goal` for till-done loops:

```text
/goal <measurable done condition, validation command, constraints, and stop limit>
```

Prefer `/goal` over a custom task continuation hook unless the done condition
requires deterministic script evaluation across every session.

For Pi/Claude orchestration parity, use `../workflow/skills/orchestration.md`.
Claude parity is through `/goal`, slash commands, hooks, and smoke tests; Task*
state is Pi-only unless the active Claude runtime exposes an equivalent
primitive.

Rules:

- one execution artifact: `PLAN.md`
- implement only from `Status: READY`
- no `REVIEW.md`
- review with `../workflow/review-rubric.md`

## Notes

`commands/plan-create.md` installs as `/plan` because `PLAN.md` is gitignored and case-insensitive filesystems are common.
