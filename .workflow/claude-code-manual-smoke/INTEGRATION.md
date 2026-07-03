# Claude Code Manual Smoke — Integration Report

Scenario: realistic smoke test of the Etabli Claude Code workflow.
Date: 2026-07-03. Repo: /Volumes/Crucial/work/etabli.
Scope guardrail: no push, no secret access, changes only under `.workflow/claude-code-manual-smoke/`.

## Delegation mode — REAL NATIVE SUBAGENTS (not simulated fallback)

The Agent tool was exposed in this Claude Code surface (types: claude, Explore,
general-purpose, Plan, ...). Two real subagents were spawned via the Agent tool
and ran concurrently with the two local commands in a single message block:

- Subagent A — `general-purpose`, model `opus` — docs accuracy review.
- Subagent B — `general-purpose`, model `sonnet` — symlink/install verification.

Raw findings captured verbatim in `subagent-A-docs.md` and `subagent-B-install.md`.
No fallback `.workflow` simulation was needed.

## Accepted (verified proofs)

| Proof | Source | Evidence |
|---|---|---|
| `deploy-agent-workflow --dry-run` passes | local | exit 0; 454 `OK` lines; sections Codex/Pi/Claude; `SUMMARY dry-run complete`; no error line (`evidence/deploy-dry-run.log`) |
| `claude-hooks-smoke.sh` passes | local | exit 0; asserts route output of `workflow-router.mjs` on ~10 fixtures (review/answer/implement/plan-implement/linear-ticket-create + `PLAN.md not proven READY` guard). Not a trivial pass (`evidence/hooks-smoke.log`) |
| Docs internally consistent | Subagent A | CLAUDE.md / README / orchestration.md agree on routes, artifacts (PLAN.md only), hooks, Pi/Claude parity. No Pi-only primitive wrongly attributed to Claude. Verdict DOCS_CONSISTENT |
| Symlinks resolve | Subagent B + direct | 20 commands + 4 hooks + `settings.workflow-hooks.json` all symlink to etabli and resolve. Zero dangling |
| Fragment is valid + complete | direct | `settings.workflow-hooks.json` parses; defines workflow-router (UserPromptSubmit), plan-ready-guard (PreToolUse Write|Edit|MultiEdit|Bash), detect-adr-signal (Stop) |

## Rejected (claims that did not hold)

- Subagent B flagged "`verify` command MISSING vs CODEX_VISIBLE_PI_SKILLS". REJECTED
  as a defect: deploy dry-run marks `stale Claude command verify.md absent` as `OK`
  by design — Claude intentionally exposes `/verify-workflow` and does NOT shadow
  Claude Code's native `/verify` (CLAUDE.md). `verify` in the skills list is the
  Pi/Codex surface name; Claude maps it to `verify-workflow`.

## Conflicts (inter-doc omissions, not factual contradictions)

From Subagent A — unilateral omissions in CLAUDE.md vs README, no contradiction:
- `/adr` skill + `detect-adr-signal.mjs` hook documented in README but absent from
  CLAUDE.md's route list.
- Local commands (`/adversary`, `/commit`, `/cross-repo-audit`,
  `/linear-project-setup`, `/spec-guide`, `/spec-verify`) in README, not in CLAUDE.md.
- `/github-pr-review` alias listed in README, not referenced in CLAUDE.md.

Decision: acceptable — CLAUDE.md is an adapter that defers to README/spec for
detail. Log as doc-completeness follow-up, not a blocker.

## Decisions

1. Delegation: use real native subagents (Agent tool available). Done.
2. `verify` gap: intentional mapping to `verify-workflow`. No action.
3. Doc omissions: track as low-priority doc sync; out of smoke scope.
4. Unwired hooks (see Remaining Risks): flagged for user decision; not auto-fixed
   (would require editing `~/.claude/settings.json` — outside allowed scope).

## Final evidence

- `evidence/run.env` — timestamps, repo, home.
- `evidence/deploy-dry-run.log` — 454 OK, exit 0.
- `evidence/hooks-smoke.log` — `claude hooks smoke test: ok`, exit 0.
- `subagent-A-docs.md`, `subagent-B-install.md` — verbatim subagent findings.
- Direct grep: 0 occurrences of managed hook names in active `settings.json`.

## Remaining risks

1. **Managed workflow hooks are NOT wired into the active `~/.claude/settings.json`.**
   The fragment `settings.workflow-hooks.json` is deployed and valid, but
   `settings.json` only wires `herdr-agent-state.sh`, `format-local.sh`, and
   `rtk hook claude`. Consequence: in THIS session, `workflow-router`,
   `plan-ready-guard`, and `detect-adr-signal` are dormant — route enforcement,
   PLAN.md READY guard, and ADR detection do not fire. Requires user decision:
   merge the fragment into `settings.json` (manual or via a deploy `--apply`
   enhancement). This is the single most important follow-up.
2. Unmanaged real files coexist with managed symlinks in `~/.claude/commands/`
   (`code-review.md`, `design-review.md`, `learn.md`, `proto.md`) and
   `~/.claude/hooks/` (`format-local.sh`, `herdr-agent-state.sh`). Not a defect —
   user-owned surfaces — but they are outside deploy control and could drift.
3. Doc completeness: CLAUDE.md omits `/adr` and several local commands present in
   README. Low priority.

## Verdict: GO

All three explicit success criteria are met:
1. Real native subagents were used (Agent tool, opus + sonnet), not simulated.
2. Accepted proofs enumerated above (dry-run, smoke, docs, symlinks, fragment).
3. `deploy-agent-workflow --dry-run` (exit 0) + `claude-hooks-smoke.sh` (exit 0).

Caveat (does not flip the smoke verdict): the workflow hooks are deployed but not
live-wired in this session. If the question were "is the Etabli workflow ACTIVE
here-and-now", the answer would be NO-GO until the fragment is merged into
`settings.json`. For the smoke-test scope (delegation + deploy + hooks runnable +
docs), the result is GO with one required follow-up decision (risk #1).
