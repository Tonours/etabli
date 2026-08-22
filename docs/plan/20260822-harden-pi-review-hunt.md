# Implemented: Harden Pi review-hunter spawn

## Metadata
- Archived: 2026-08-22
- Source plan: `PLAN.md` — Harden Pi review-hunter spawn; Cursor hunters use Opus 5 high
- Source plan SHA-256: `61223d9e4477dbb352937255950f53f314cbdca5963a72d7c576e3fc6911b4ee`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `refactor/skill-default-load`

## Outcome
- Pi Logic hunters spawn as an official-style child: `--mode text -p --no-session --no-skills --no-extensions --no-context-files --tools read,grep --append-system-prompt <prompt> @<patchfile>`, timeout 600s.
- `scripts/pi-review-hunter` prints that argv without invoking `pi` or GNU `timeout`; exec fail-closed with `HUNTER_SPAWN_UNAVAILABLE` / `HUNTER_TIMEOUT`.
- Daily Pi: one isolated Logic child; Spec in the parent (`spec: parent`). Cursor hunters use Task `claude-opus-5-thinking-high`. Claude stays on `reviewer`.
- `GO` is forbidden when `isolation: none`. Review templates deploy via `scripts/deploy-workflow`.

## Context
- Previous isolate-review-hunt wired naive `pi -p --tools read`. Official example uses `--mode json -p --no-session` and AbortSignal; shell parents need text mode plus `@file` so NDJSON does not re-enter the parent.
- User: harden that spawn; until Pi is proven, Cursor review hunters are Opus 5 high. Do not reinstall tintinweb.

## Decisions
### Text mode for shell parents
- Context: official wrapper parses NDJSON; a bash parent would dump file reads back into context.
- Choice: `--mode text` in the skill recipe; json stays the extension's concern.
- Rejected options: raw `--mode json` stdout; vendoring the official subagent extension.
- Rationale: isolation holds for a shell-spawned child.
- Consequences: docs-smoke pins `--no-session` and `--mode text`, not json.

### Daily Pi Spec in parent
- Context: user accepted one isolated Logic hunter.
- Choice: `spec: parent` after Logic returns; Claude/Cursor still isolate Spec with the same runner/model.
- Rejected options: second Pi child; parent Logic fallback.
- Rationale: cost/latency without repeating same-session Logic self-review.
- Consequences: lead records the weaker Spec evidence class.

### Helper is etabli-local
- Context: `deploy-workflow` copies skills, not arbitrary scripts.
- Choice: argv lives in `workflow/skills/review.md` for scaffolded projects; helper + smoke stay in this repo.
- Rejected options: deploy the helper; restore tintinweb.
- Rationale: contracted argv is enough off-box.
- Consequences: smoke pins helper argv against both review.md copies.

## Accepted Drift
- Original plan/spec: `--mode json` and ~90s timeout as the official argv.
- Implemented reality: `--mode text`, 600s, `@file`, `-ne -ns -nc`, `HUNTER_TIMEOUT`, integer timeout guard, prompt+patch non-empty.
- Why accepted: folded from plan-mode Opus adversary (BLOCK → READY) and code-diff Fable notes.

## Validation Evidence
- command: `bash tests/pi-review-hunter-smoke.sh`
  - result: pass (2026-08-22)
- command: `bash tests/workflow-docs-smoke.sh`
  - result: pass (2026-08-22)
- command: `bash tests/claude-agents-smoke.sh && bash tests/claude-commands-smoke.sh`
  - result: pass (2026-08-22)
- command: `bash tests/agentic-infra-manifest-smoke.sh`
  - result: pass (2026-08-22)
- command: `bash tests/workflow-scaffold-smoke.sh`
  - result: pass (2026-08-22)
- command: `git diff --check`
  - result: clean (2026-08-22)
- review: Logic+Spec `claude-opus-5-thinking-high` GO WITH NOTES; folded (timeout integer, `-p`/`--append-system-prompt` pins, empty prompt, `hunter_model:`, hard stop).
- code-diff adversary: `claude-fable-5-thinking-high` (gpt-5.5 usage-limited). GO WITH NOTES; folded (prompt carries Axis/Intent/Standards, Cursor Spec same model, `env -u` smoke, empty-patch/missing-pi exec pins, pr-review hard stop). Cross-family vs implementer grok-4.6.
- simplify: removed 1
- quality: ran (sibling compare vs `scripts/lib/pi-paths.sh` / `tests/pi-paths-smoke.sh`); no product UI skill

## Follow-up State
- Remaining risks: live Pi hunter against a paid model is still a human canary; Spec-in-parent can rubber-stamp Intent on daily Pi.
- Parking lot: official subagent extension; live canary in CI; adversary/ship `pi -p` call sites.
- Superseded docs/specs: naive `pi -p --tools read` hunter spawn.
- Next links: previous isolate-review-hunt tree remains uncommitted underneath; do not `git add -A` without splitting it.
