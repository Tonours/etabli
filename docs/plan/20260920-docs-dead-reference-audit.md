# Implemented: docs synced with the tree and dead references removed

## Metadata
- Archived: 2026-09-20
- Source plan: `PLAN.md` — full documentation sync with the current tree, plus a dead-reference audit (docs, config keys, orphan scripts)
- Source plan SHA-256: `d38c27fe0c7fdf3c1a57151c6d72db7dac5862292e16cd65fef0e258e1247ac9`
- Status: IMPLEMENTED
- Commit / branch: uncommitted working tree on `main` at plan time (README.md itself was synced earlier in commit `5d073154`)

## Outcome
- `docs/README.md` now indexes every root doc: `symlink-layout.md` and
  `claude-token-budget.md` under Start here, `self-improvement-privacy-20260915.md`
  under History.
- `claude/README.md` RTK bullet rewritten: documents the native `rtk hook claude`
  wiring (machine-local `~/.claude/settings.json`, not tracked) instead of a
  phantom patched `rtk-rewrite.sh` that exists nowhere.
- `pi/settings.json` dead `prompts: ["prompts"]` key removed (target dir never
  existed in git nor at `~/.pi/prompts`); Pi starts clean.
- Audit verdicts: no tracked script deleted — `dev-spawn` kept as manual
  personal launcher; `router-eval(.mjs)`, `tmux-clipboard.sh` confirmed
  referenced; lean-ctx mentions are dated history or a negative smoke assertion.

## Context
- `claude/README.md:198-204` (pre-edit): described `rtk-rewrite.sh` tracked in
  `claude/hooks/` + a `check-fix-symlinks.sh --fix` restore rule; `find` proved
  no rtk file in tree, none at `~/.claude/hooks/`, no git deletion record.
- `~/.claude/settings.json` (local): `PreToolUse(Bash) -> "rtk hook claude"` —
  the actual mechanism; `scripts/lib/claude-settings-sync.mjs` only syncs
  `skillOverrides`, `permissions.defaultMode`, two scalars, so hooks stay
  machine-local.
- `pi/extensions/__tests__/settings-consistency.test.ts:13`: parses
  `pi/agent/settings.json` only — root settings key removal is untested surface;
  covered instead by JSON validity + `pi --version` + group `pi`.
- md link scan + orphan-script scan across tracked files; vendored trees,
  `tests/fixtures/`, ADRs, plan archives excluded as intentional.

## Decisions
### Keep `scripts/dev-spawn`
- Context: only script with zero references outside `scripts/` and `.workflow/`.
- Choice: keep, record verdict.
- Rejected options: delete as dead code.
- Rationale: self-described manual tmux launcher (local + VPS); unreferenced by
  design in a personal dotfiles repo; deletion is a user decision, not a fact.
- Consequences: future audits should not re-flag it without user input.

### Do not edit `claude/RTK.md`
- Context: loaded into every Claude session via `@RTK.md` in `claude/CLAUDE.md`.
- Choice: leave as-is.
- Rejected options: rewrite or delete.
- Rationale: its hook claim ("commands automatically rewritten by the Claude
  Code hook") is true on wired machines and it never mentions the phantom
  script; only `claude/README.md` was stale.

## Accepted Drift
- Original plan/spec: Slice 3 checks listed only `pi --version` + group `pi`.
- Implemented reality: JSON-parse validity check added first.
- Why accepted: check strengthening after adversary pass (check-freeze allows
  strengthen-only).

## Validation Evidence
- command: `scripts/verify-agentic-infra shell-docs`
  - result: SUMMARY: 75/75 checks passed
- command: `scripts/verify-agentic-infra pi`
  - result: SUMMARY: 6/6 checks passed
- command: `pi --version`
  - result: 0.85.1 (startup smoke after settings edit)
- command: `node -e 'JSON.parse(...pi/settings.json)'`
  - result: valid
- command: index-parity grep (`ls docs/*.md` basenames vs `docs/README.md`)
  - result: no unindexed doc
- command: md link scan (tracked md, excluding vendor/fixtures/scopes templates)
  - result: no dead link
- Review: Logic hunter (pi-child, fresh context) `No findings.` + complete
  deciding-code table, `Verdict: GO`; Spec hunter in parent `No findings.`
  (`spec: parent`); code-diff adversary double-sample same-family: second
  pi-child adversary pass `No findings.` `adversary verdict: GO`
  (`same-family-pass: logic-pi-child + adversary-pi-child`, `hunter_model:
  default`); lead `Verdict: GO`.

## Follow-up State
- Remaining risks: none identified; the RTK bullet describes machine-local
  wiring that a fresh machine will not have until rtk/settings are set up there.
- Parking lot: none.
- Superseded docs/specs: none.
- Next links: root `PLAN.md` deleted after this archive (`scripts/plan-cleanup
  --archive`).
