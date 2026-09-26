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
- `scopes/<scope>/scripts/*` -> `~/.claude/scripts/`
- `hooks/*` (`.mjs` + `.sh`) -> `~/.claude/hooks/`
- `settings.workflow-hooks.json` -> `~/.claude/settings.workflow-hooks.json`
- `statusline-command.sh` -> `~/.claude/statusline-command.sh` (shows context as `ctx:<N>k` input tokens of the last API call, from `current_usage` then `total_input_tokens`, yellow from 150k and red from 300k, with a percentage fallback)
- selected shared docs from `../workflow/` -> `~/.claude/`

Re-run `scripts/install.sh` any time to refresh links; it is idempotent. When
links look stale or broken (missing command, drift after an update), run
`scripts/check-fix-symlinks.sh` to validate and repair the installed surface.

## Scopes

Commands, skills, agents and scripts live under `claude/scopes/<scope>/`:

| Scope | Holds | Deployed |
|---|---|---|
| `shared` | Anything that does not name an employer or a private project | Always |
| `work` | Employer-specific surfaces (employer stack, its repos, its conventions) | Only where the machine declares it |
| `personal` | Private-project surfaces | Only where the machine declares it |

A `shared` surface can still be withheld from one scope when something else on
that machine owns its name: `SCOPE_SHADOWED_SKILLS` in
`scripts/lib/install-main.sh` holds `<scope>:<skill>` pairs, currently
`work:adr`.

A machine declares one scope in `~/.etabli-scope`, containing exactly `work` or
`personal`. `ETABLI_SCOPE` overrides it for one run. No file and no variable
means `shared` alone, which is the safe default: a new machine never receives
another context's surfaces by accident. An unrecognised value fails the deploy
with exit 2 rather than deploying a partial surface.

The same active scope gates vendored skills linked into Pi, Claude, and Codex.
Grok receives only catalog entries explicitly marked `agents_visible` through
`~/.agents/skills`; personal vendor directories are never copied there.

`scripts/` holds the local cron routines (`routines/`, `sessions-report*`) and
`claude-bin.sh`, which resolves the `claude` binary for non-interactive
contexts where no shell profile is loaded. Their launchd plists stay outside
this repo, in `~/Library/LaunchAgents/`: linking the scripts installs them but
does not schedule them.

Put a surface in `shared` only if it would still make sense at a different
employer. A skill that names a repo, a product, or an internal service belongs
in `work`.

### Contracts, commands, and skills

Five names share a `workflow/skills/<name>.md` contract and a
`scopes/*/commands/<name>.md` command: `bug-check`, `pr-qa`, `pr-review`,
`sec-pr`, and `review`. That is not drift to clean up.

- the **contract** is the cross-runtime source of truth — Pi reads it too
  (`pi/skills/pr-review/SKILL.md`), and Pi cannot see Claude skills;
- the **command** is the thin `/name` entry point;
- a **Claude skill** exists only when Claude's procedure goes further than
  the contract. Today that is `bug-check`, `pr-qa`, and `sec-pr` under
  `scopes/work/skills/`. `review` and `pr-review` have Pi skills instead.

Change the contract when the rule is true for every runtime. Change the skill
when only that runtime's procedure moves. `tests/workflow-contract-coverage-smoke.sh`
enforces that every contract stays referenced somewhere.

The `personal` row in the scope table is the deploy gate. Personal vendor
skills (AdonisJS) arrive through `vendor/`, not `claude/scopes/personal/`.

## Workflow

Canonical contract: `../workflow/spec.md`.

Claude commands are thin wrappers over that contract:

- `/plan-loop`
- `/plan-implement`
- `/ship`
- `/implement`
- `/review`
- `/verify-workflow`
- `/bug-check`
- `/linear-ticket-create`
- `/linear-work`
- `/linear-project-setup`
- `/pr-review`
- `/pr-qa`
- `/sec-pr`
- `/ci-fix`
- `/github-pr-review`
- `/adversary`
- `/spec-guide`

Custom agents stay bounded:

- `scout` — read-only reconnaissance for one unfamiliar area;
- `worker` — one implementation step from a `READY` plan;
- `reviewer` — fresh-context, findings-first diff review.

`scout` and `reviewer` use an agent-local `PreToolUse` hook to allow only proven
read-only Bash/Git commands. `worker` is the only writing agent and never spawns
another agent.

Command `allowed-tools` entries are permission pre-approvals, not a sandbox.
Source-read-only commands therefore avoid pre-approving `Write`, `Edit`, or bare
`Bash`; the enforced shell boundary belongs to `scout` and `reviewer`.

Load only a matching skill that the active Claude surface actually exposes.
Prefer an exposed project skill when the task is about its codebase; otherwise
use a scope-gated vendor skill such as `ember-employer-suite` (work) or
`adonisjs-suite` (personal) when the machine declares that scope. UI/CSS skills
sit on the `extras/` shelf and are not deployed by default. Skill selection is not a
mandatory first step on `/plan-loop`, `/plan-implement`, or `/ship`; when no
matching skill is exposed, the route uses its local-source fallback instead of
silently skipping the phase. See `vendor/README.md` for the manifest and sync
command.

`scout`, `worker`, and `reviewer` declare `Skill` and pick the domain skill
themselves when the brief matches. There is no hook that suggests a skill —
selection is the model's, per ADR-0014. There is no additional global skill
router.

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

It is **not deployed on a `work` machine**: there `/adr` comes from the
`employer@employer` plugin (`employer/claudine`), which owns the same name.
`SCOPE_SHADOWED_SKILLS` in `scripts/lib/install-main.sh` lists that exclusion —
a shared skill named there is skipped for the listed scope and its installed
link removed. The two skills are not interchangeable: this one writes
`docs/adr/NNNN-slug.md`, the plugin's writes `docs/adr/YYYY-MM-DD-slug.md`. So a
`/adr` run inside this repo on a work machine produces a date id that its own
`scripts/validate-adrs` rejects; record etabli ADRs from a `personal` machine,
or write the file by hand in the numbered form.

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
  fragment is not active. Inspection reaches the remote: `gh` is allowed for an
  allowlisted set of read commands (`api`, `pr view|diff|list|checks|status`,
  `issue view|list`, `repo view`, `run view|list`, `search`, `auth status`) and
  refused the moment a flag could mutate it (`--method` other than GET, `-X`,
  `-f`/`-F`/`--raw-field`/`--field`, `--input`) — a review agent that cannot
  read the pull request it was dispatched to review is useless. `awk` is allowed
  for an inline program only, since single quotes hide `system()`, a `print |`
  pipe and a `>` redirect from the pipeline splitter; `-f` stays refused because
  the program then lives in a file this check cannot read. `sed` and `sort`
  remain refused outright. Executables are matched on their basename, so
  `/bin/bash -n` is judged like `bash -n`, and `;`/newline sequence read-only
  segments the way `&&` already did.
- `detect-adr-signal.mjs` runs on `Stop`. When a structural file changed and the
  last assistant message reads like a decision, it surfaces a `systemMessage`
  suggesting `/adr`. It never writes, never calls an LLM, and uses `systemMessage`
  (not `additionalContext`) so it does not resume the turn. The `/adr` skill works
  without it; the hook only lowers the cost of remembering to record decisions.
- `no-comments-guard.mjs` runs on `PreToolUse` for `Edit|Write|MultiEdit`. It
  denies a write that adds code comments to source files and names the
  offending line, per the `~/work/CLAUDE.md` no-comments rule (lint pragmas, `@ts-expect-error`-style directives, and shebangs are
  exempt). It ships in `settings.workflow-hooks.json`. It cannot see files
  written through `Bash`, so write code with `Edit`/`Write`.
- RTK command rewriting runs through the native `rtk hook claude`
  subcommand wired as `PreToolUse(Bash)` in the local
  `~/.claude/settings.json`; that wiring is machine-local, not tracked here
  (`scripts/lib/claude-settings-sync.mjs` syncs only skill overrides,
  permission mode, attribution, and the two skip prompts scalars). The installer ensures
  the binary itself (`scripts/lib/install-main.sh`); there is no patched
  `rtk-rewrite.sh` and no link rule to restore. With `bypassPermissions`
  active, no exit-3 ask-rule patch is needed.

## Autonomous mode

Claude Code runs without permission prompts on this machine. The tracked
fragment `settings.skill-overrides.json` carries the convention next to the
skill map, and `scripts/lib/claude-settings-sync.mjs` (run by the installer)
propagates it into `~/.claude/settings.json`:

- `permissions.defaultMode: "bypassPermissions"` — merged key-by-key, local
  `allow`/`deny` lists are never touched;
- `skipDangerousModePermissionPrompt: true`, `skipAutoPermissionPrompt: true`;
- `attribution: { commit: "", pr: "" }`: no `Co-Authored-By` trailer on
  commits and no generated-with line in PR bodies.

The sync accepts only whitelisted keys (`skillOverrides`, `permissions.defaultMode`,
`attribution.commit`/`attribution.pr`, the two skip flags), so no secret can leak into the tracked fragment. The
`--dangerously-skip-permissions` zsh alias is machine-local (`~/.zshrc` is not
managed here); `defaultMode` alone covers every launcher, including `-p` runs,
crons, and `claude-bin.sh`.
- `settings.workflow-hooks.json` is a merge fragment. It is linked but not
  merged into `~/.claude/settings.json` by the installer, because the live
  settings file can contain secrets. Activate it with
  `scripts/claude-hooks-merge --dry-run` (review) then
  `scripts/claude-hooks-merge`: the merge only adds the fragment's hook
  entries (backup first, refuse on conflict or invalid JSON, byte-idempotent
  reruns) and never reads live secrets back into the repo. Verify with
  `scripts/claude-hooks-check`. Activating it enables the session-wide READY,
  ledger, ADR, and outcome hooks; the read-only agent hook is scoped from
  agent frontmatter instead.

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

## PR autoreview

`scopes/work/scripts/pr-autoreview/` reviews the user's own PRs on the four
employer repos. A `pre-push` hook detaches a background runner; the runner waits
for nothing, checks that an open PR authored by `Tonours` exists for the pushed
branch, and reviews it against `profiles/<repo>.md` plus the repo's own
`CLAUDE.md` and the `~/work/brain` knowledge base.

It currently runs in break-in mode: findings go to Slack `#routines` only,
nothing is posted to GitHub. The mode lives in `prompt.md`.

Guards: PR younger than 30 days, author must be `Tonours`, one pass per
`repo#pr@headSha`, kill switch at `~/.claude/state/pr-autoreview.off`.

The hook entry points (`~/.huskyrc`, `~/.config/husky/init.sh`) and the two
generated `.husky/pre-push` files are local only — `~/.gitignore_global` keeps
the latter invisible to git. Run `pr-autoreview/install.sh` to wire a machine.
