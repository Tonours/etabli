# Subagent B — symlink/install verification (verbatim findings)

Agent: general-purpose, model sonnet. Read-only.

## INSTALLED_AND_RESOLVING
Commands (~/.claude/commands/) — all resolve to /Volumes/Crucial/work/etabli/claude/commands/:
adversary, bug-check, ci-fix, commit, cross-repo-audit, github-pr-review, implement,
linear-project-setup, linear-ticket-create, linear-work, plan-implement, plan-loop,
plan (-> plan-create.md), pr-qa, pr-review, review, sec-pr, spec-guide, spec-verify,
verify-workflow.

Hooks (~/.claude/hooks/) — all resolve:
detect-adr-signal.mjs, plan-ready-guard.mjs, workflow-router-lib.mjs, workflow-router.mjs.

Settings:
~/.claude/settings.workflow-hooks.json -> etabli/claude/settings.workflow-hooks.json (resolves).

## UNMANAGED_REAL_FILES
Commands: code-review.md (3.7K), commit.md.bak.20260703-090415 (634B), design-review.md (5.1K), learn.md (487B), proto.md (3.9K).
Hooks: format-local.sh (3.0K), herdr-agent-state.sh (3.0K).

## DANGLING
none.

## MISSING_VS_EXPECTED
- `verify` from CODEX_VISIBLE_PI_SKILLS: no verify.md symlink; only verify-workflow.md exists
  (also absent on repo side). NOTE: deploy dry-run marks this as intentional
  ("stale Claude command verify.md absent" -> OK).

Present (13/14): plan-loop, plan-implement, adversary, implement, bug-check,
linear-ticket-create, linear-work, pr-review, pr-qa, sec-pr, ci-fix, github-pr-review.

## SETTINGS_WIRED
no — ~/.claude/settings.json defines a hooks block (PreToolUse/PostToolUse/UserPromptSubmit/Stop)
but references NONE of the managed hooks (workflow-router, plan-ready-guard, detect-adr-signal)
nor settings.workflow-hooks.json. Active hooks are only herdr-agent-state.sh and format-local.sh
(unmanaged) plus "rtk hook claude". Confirmed by direct grep: 0 occurrences.

## VERDICT
INSTALL_PARTIAL — all managed surfaces present as resolving symlinks, but (1) `verify` naming
gap is intentional mapping to verify-workflow, and (2) the 4 managed workflow hooks are not
wired into active settings.json so they will not fire despite being deployed.
