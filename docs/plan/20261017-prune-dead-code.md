# Implemented: dead code, event ledger and editor bootstrap removed; satellites migrated

## Metadata
- Archived: 2026-10-17
- Source plan: `PLAN.md` — Hunt dead and duplicated code/docs, drop the event ledger, slim install and onboarding
- Source plan SHA-256: `7bfeb0d73a2d1e72b4da2c9400c6862a69e2b212edf3c6527bd96754e766b22e`
- Status: IMPLEMENTED
- Commit / branch: `main`, etabli `c96d1e82..a717801e`; dotfiles `4af5598`, `409bb5b`; anthonyguimard `7625ed3`, `36b532a`, `1f104dd`; kibun `7c720ca`, `661ea15`, `7ca6ab4` (no remote, local only); saas-lab `50fc8ea`, `8ea9420`, `f7d4eda` (anthonyguimard and saas-lab rebased onto `origin/main` before push; pre-rebase hashes in the plan body: `20fcd95`/`ad4092d`/`48afa2d`, `e8bb9ab`/`3f78596`/`d4a372c`) (oh-ca-va and dotfiles scaffold migration applied without commit)
- Workflow initiative: none

## Outcome
- Installer test code moved out of `scripts/lib/install-main.sh` into `tests/install-smoke.sh` (sourced-return guard); deploy live-check switch renamed `ETABLI_SKIP_LIVE_CHECKS`.
- Retired link surfaces (Codex/Devin/`.agents`, retired `~/.local/bin` scripts, legacy damage-control) and their checks deleted; `RETIRED_HOOK_COMMANDS` kept.
- Editor tooling (Neovim, lazygit, Nerd Font, editor LSPs, hunkdiff) moved to dotfiles `scripts/install-editor`; README quick start is 3 commands.
- One no-comments detector: `workflow/runtime/no-comments-guard.mjs`, a one-pass lexer per language family (clike, python, ruby, shell, sql, lua) with string, regex, heredoc and shell-substitution handling; the Claude hook is a thin adapter; parity table checks both entry points.
- Event ledger removed (≈3800 lines: `workflow-event`, ledger libs, jq, `plan-review-check`, tests). Handoff lives in `PLAN.md` § Notes / Handoff, adversary provenance in § Review Changes.
- `workflow/agent-quick-card.md` folded into `workflow/spec.md`; `docs/README.md` folded into README; `claude/README.md` 308 → 129 lines; `CONTEXT.md` → `GLOSSARY.md` (Scaffold, Surface retirée).
- Small dead code: unused exports, `!autoproject`, `tests/adr-skill-e2e.sh`, `extras/skills/grill-me`.
- `scripts/deploy-workflow --prune` (backs up every `RETIRED_FILES` copy, unindexes tracked ones, physical-root confinement, refuses staged retired files) and `--refresh-tracked` (overwrites tracked scaffold docs except `AGENTS.md`, `docs/project-context.md`, scripts, symlinks, dirty files).
- Satellites migrated: anthonyguimard, kibun, saas-lab committed; oh-ca-va and dotfiles applied without commit; `scripts/plan-cleanup` + its lib tracked in the three committed satellites so clean clones run `--status`.

## Context
- `scripts/deploy-workflow`: never overwrote tracked files and never deleted retired copies, so every satellite still cited the ledger and the quick card.
- pi-lens `docs/dependencies.md`: TS/YAML/JSON/CSS/HTML servers, prettier and intelephense are auto-installed; lua-language-server is editor-only.
- Adapter bodies are hand-written; `workflow-adapter-sync` only stamps headers and checks a body hash.

## Decisions
### Ledger removed, evidence kept in PLAN.md
- Context: the ledger was contract-mandatory for autonomous runs but ≈3800 lines to maintain.
- Choice: delete it; Checks, Review Changes (model, `shasum -a 256 PLAN.md` at dispatch, verdict), Notes / Handoff and the archive SHA-256 carry the evidence.
- Rejected options: keep a slim ledger.
- Rationale: user decision (grill); the archive identity check in `plan-cleanup` already binds the record to the plan.
- Consequences: provenance is prose, not machine-validated.

### Full satellite migration
- Context: byte-match prune would have left adapted copies citing deleted files.
- Choice: `--force --refresh-tracked --prune` with backups and explicit-pathspec commits on clean Mac mini projects only.
- Rejected options: byte-match prune only.
- Rationale: user chose "migration complète" (adversary plan pass 2 #1).
- Consequences: anthonyguimard's custom `docs/agent-workflow.md` replaced by the template (history keeps it); four dirty projects skipped.

### Single lexer for no-comments
- Context: two detectors disagreed; the shared one judged fragments and missed multiline strings.
- Choice: one shared lexer, families per extension, verdict table shared by Pi and Claude.
- Rejected options: keep Claude-specific allowances in the hook.
- Rationale: one verdict per case, one place to fix.
- Consequences: a heuristic lexer, not a parser; ten confirmation passes each found narrower edge cases (see Accepted Drift).

## Accepted Drift
- Original plan/spec: stop condition "cross-model code-diff adversary GO".
- Implemented reality: eleven cross-model passes (`gpt-6.1-sol` via Codex, read-only); the loop was closed after pass 11 by user decision with a BLOCK verdict: the last MEDIUM (pattern `(case)`) was fixed in a717801e, which no cross-model pass confirmed.
- Why accepted: every HIGH (3, pass 1) was confirmed CLOSED by a later cross-model pass; later passes found only MEDIUM/LOW edge cases of the heuristic lexer, each fixed with a parity and Pi case red on the previous commit; on 100 tracked shell/Ruby/SQL/Python files the final lexer drops only heredoc-data false positives and adds only real comments versus `fa62a3d6`.

## Validation Evidence
- `scripts/verify-agentic-infra full`:
  - result: 45/45 PASS (after a717801e)
- `scripts/verify-agentic-infra core`:
  - result: 15/15 PASS
- `bun test pi/extensions/__tests__/` + `bun run typecheck`:
  - result: 345 pass, 0 fail; typecheck exit 0
- `bash tests/claude-hooks-smoke.sh`:
  - result: ok (no-comments parity table, 45 cases checked against both entry points)
- `scripts/workflow-adapter-sync --check`:
  - result: clean
- AC greps (ledger/quick card/retired names; editor tooling):
  - result: only `RETIRED_FILES` entries and their smoke; editor grep empty
- `git diff --shortstat c96d1e82`:
  - result: 68 files, +1315 −6069 (net −4754)
- Satellite clean clones `node scripts/plan-cleanup --status`:
  - result: rc 0 in anthonyguimard, kibun, saas-lab
- pi-lens diagnostic on a scratch `.ts` edit; dotfiles `install-editor` real run 0, without brew 1; `nvim --headless +qa` 0 (v0.12.6).

## Follow-up State
- Remaining risks: no-comments lexer limits (Ruby `%q`/heredocs, Lua long brackets, SQL block comments, exotic shell grammar); generic names in `RETIRED_FILES` (opt-in, dry-run listed, backed up); other machines keep stale retired links until converged.
- Parking lot: broken LaunchAgent `com.etabli.herdr-claude-relaunch`; ignored `github-copilot/auth.db*` in the checkout; skipped dirty projects chantier-proof-change-orders, galerieclient, lea-folio, steam-demo-brief still carry the ledger scaffold.
- Superseded docs/specs: `workflow/agent-quick-card.md`, `workflow/events.md`, `docs/README.md`, `CONTEXT.md`.
- Next links: `workflow/spec.md`, `workflow/plan-archive.md`, worktree backups `/Volumes/Crucial/work/archives/etabli-worktrees-20261017`.
