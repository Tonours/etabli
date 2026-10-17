# Implemented: prune refuses project-owned paths, lexer covers SQL/Lua/Ruby blocks, four projects migrated

## Metadata
- Archived: 2026-10-17
- Source plan: `PLAN.md` — Close the residual risks of the dead-code pruning run (prune safety, lexer limits, skipped projects)
- Source plan SHA-256: `0dcfb69005f1111c8310e62c7b4da01808bf535d477b8bb96001a306a25db4fc`
- Status: IMPLEMENTED
- Commit / branch: `main`, etabli `9a3b68a4..ec002663`; galerieclient `ed46bec`, `6776417`, `4fe7124`; lea-folio `bf73fbe`, `a7d8b56`, `2287808`, `629e840`; chantier-proof-change-orders `ddd5ae9`, `7c0d9a1`, `a22da16`; steam-demo-brief `29ebc7b`, `a8f6540`, `ccdad70`; anthonyguimard `aea9904`; kibun `92c5bcc`; saas-lab `b73b605`
- Workflow initiative: none
- Pushed hashes after rebase on origin/main: galerieclient `f75bda9`, `767ff30`, `f031db6`; lea-folio `3866404`, `eb3c2bd`, `a4f4024`, `dc1d022`; chantier `231896b`, `6db5717`, `73d7b61`; steam `9549ad2`, `3bbcfde`, `6dfbd82`; anthonyguimard, saas-lab unchanged; kibun has no remote (local only)

## Outcome
- `scripts/deploy-workflow --prune` moves a retired path only when it is a non-empty regular file whose blob exists in etabli's object database; project-authored, empty, symlinked or directory paths are CONFLICT unless `--prune-foreign` (requires `--prune`).
- Staged retired paths (edit, add, deletion with the file kept, unborn HEAD) refuse the whole run before any write, compared with `--no-textconv --no-ext-diff`; already-pruned paths awaiting commit do not block a rerun.
- Tracked retired paths missing from the worktree are unindexed (`WOULD_UNINDEX` / `UNINDEX`); `git rm -r --cached --sparse` covers directories and sparse checkouts.
- No-comments lexer: SQL nested `/* */` and `$tag$` strings, Lua long comments and strings, Ruby `=begin`/`=end`, heredocs and `%` literals after a code boundary, character literals; limits documented in `claude/README.md` Hooks.
- Scaffold archive template (`workflow-scaffold/templates/docs/plan.md`) now matches `plan-cleanup` (`PLAN.md` source line + SHA-256); refreshed in nine projects.
- chantier-proof-change-orders, galerieclient, lea-folio, steam-demo-brief migrated off the event ledger; all four track the current `scripts/plan-cleanup` + lib.
- Done before the plan: LaunchAgent `com.etabli.herdr-claude-relaunch` and herdr plugin links repointed to dotfiles; stray `github-copilot/` moved to `archives/etabli-github-copilot-20261017` (0700).

## Context
- `RETIRED_FILES` sources are not always the destination path (`workflow/verification/*` shipped from `workflow-scaffold/templates/verification/*`), so per-path history lookup misclassified etabli copies.
- CI checks out etabli shallow; smoke fixtures use `git show HEAD:<path>` blobs, not history.
- lea-folio had hardened its own ledger copies and `scripts/package.json` (`"type": "commonjs"`) for the old CJS `plan-cleanup`.

## Decisions
### Object-database gate
- Context: generic retired names could prune project files.
- Choice: blob must exist in etabli's object database; empty files and non-regular paths are foreign.
- Rejected options: per-path `git log` blob list (misses template sources).
- Rationale: simplest check that refuses project-authored content.
- Consequences: a project file byte-identical to any etabli blob counts as shipped (backed up, never lost); a shallow or git-less etabli checkout makes every copy foreign (fail-closed).

### lea-folio foreign copies pruned
- Context: 10 retired copies were project-hardened ledger and skill files.
- Choice: `--prune-foreign` after review; the CI flock smoke of `scripts/workflow-event` removed in the same commit.
- Rejected options: keep the hardened ledger.
- Rationale: nothing outside `workflow/` used them except that CI step.
- Consequences: history and `.bak.*` copies keep them.

### Targeted edits beyond refresh
- galerieclient clean seed `docs/project-context.md`: one `scripts/workflow-event` reference removed.
- Project-local helpers never shipped by etabli and used only by retired files moved to `.bak.*` (galerieclient `scripts/workflow-measurement-integrity.cjs`; lea-folio 7 `scripts/lib/workflow-event-*`).

## Accepted Drift
- Original plan/spec: stop condition "cross-model code-diff adversary GO".
- Implemented reality: three cross-model passes (Budget cap), each NO-GO; pass 1 HIGH (textconv) confirmed closed in pass 2; passes 2–3 found only MEDIUM/LOW lexer boundary cases and project fixes, each fixed with a case red on the previous commit; the pass-3 fixes (`ec002663`) have no cross-model confirmation.
- Why accepted: user rule of 2026-10-17 (fix the last MEDIUM, record the rest, ship); no HIGH open.

## Validation Evidence
- `scripts/verify-agentic-infra full`:
  - result: 45/45 PASS on `ec002663`
- `bun test pi/extensions/__tests__/` + typecheck:
  - result: 346 pass, 0 fail; exit 0
- `bash tests/workflow-scaffold-smoke.sh && bash tests/claude-hooks-smoke.sh`:
  - result: ok; new cases red on the pre-fix commits; deploy and lexer mutants killed
- Corpus (386 files: 200 Homebrew rb, 99 sh, 53 sql, 33 lua, 1 py) vs `9a3b68a4` guard:
  - result: 36 files changed; 22 lost lines all string/heredoc bodies; gains are SQL block comments, a Lua long comment, two Ruby comments a heredoc apostrophe used to hide
- Retired-name grep (frozen pattern in the source plan) in the four projects:
  - result: empty; dirty user paths byte-identical before/after
- Clean clones `node scripts/plan-cleanup --status`:
  - result: rc 0 in galerieclient, lea-folio, chantier, steam; lea-folio `--archive` round trip from the template rc 0
- Logic + Spec review: GO WITH NOTES, folded

## Follow-up State
- Remaining risks: heuristic lexer limits (shell grammar beyond handled constructs, Ruby `#{}` comments, ambiguous Ruby heredoc/`%` positions); object-database gate residuals above.
- Parking lot: chantier/steam keep older tracked `workflow/router-template.md` and `scripts/validate-adrs`; galerieclient `.gitignore` tracks `PLAN.md` in HEAD; kibun has no remote.
- Superseded docs/specs: none.
- Next links: `docs/plan/20261017-prune-dead-code.md`, `scripts/deploy-workflow --help`, `claude/README.md`.
