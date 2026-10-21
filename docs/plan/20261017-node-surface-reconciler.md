# Implemented: agent surfaces reconciled from one Node manifest, growth rule, link-only tier clause

## Metadata
- Archived: 2026-10-17
- Source plan: `PLAN.md` — Reconcile agent surfaces from one Node manifest, add a growth rule, proportion the tier for link-only changes
- Source plan SHA-256: `fe64cf5448da45b04a95732411f2de917f4a4908553861997fd97d7b9014abde`
- Status: IMPLEMENTED
- Commit / branch: main, base `5b1359d9`
- Workflow initiative: none

## Outcome
- `scripts/lib/surfaces.mjs` builds one desired-state manifest consumed by `scripts/deploy-agent-workflow` (Node ESM; `--dry-run`, `--apply`, `--check [--fix] [--verbose]`, `--home`), so deploy and check can no longer disagree (ADR-0038).
- `scripts/check-fix-symlinks.sh` is a 5-line wrapper over `--check`; `fix-links` unchanged. `claude-skill-load-check`, `claude-hooks-check`, `claude-hooks-merge` read scope, catalogue and config dir from `surfaces.mjs`.
- Deleted: `scripts/lib/{managed-surfaces,skill-catalog,etabli-scope,claude-config-dir}.sh`, three smokes ported to `tests/surfaces.test.mjs` (23 node:test cases), installer `install_script`.
- Checkout membership is physical (`realpathSync.native`, component-wise resolution, indeterminate = foreign); `--home`/`HOME` resolved the same way.
- `AGENTS.md` `## Growth`: weekly-use bar, ~50-line throwaway measurement first, review date in a new subsystem's ADR, prefer deletion. `workflow/skills/implementation-loop.md`: etabli-only clause making link-reconciliation-only changes standard with one cross-model code-diff pass.

## Context
- `fs.realpathSync` (JS) collapses `..` lexically before resolving; `realpathSync.native` follows the kernel. `path.join`/`path.resolve` do the same lexical collapse, so raw paths go through `physicalPath` before any join.
- asdf shims resolve Node from `HOME`; fixtures that replace `HOME` put the real Node directory first on PATH, and the installer runs the deployer through `NODE_CMD`.
- `codex exec` launched in the background without `</dev/null` waits on stdin and returns nothing.

## Decisions
### One Node module instead of five bash libraries
- Context: deploy and check were two reconcilers over shared bash libs; the previous run hit errexit masking and lexical `..` escapes.
- Choice: one manifest, one op table (absent → link; disposable link → replace; foreign → move aside to `<path>.bak.<ts>` or `<surface>.bak/`; failed backup → unresolved, exit 1).
- Rejected options: keep bash and add tests (failure classes survive); generate bash from a manifest (two languages).
- Consequences: check needs Node on PATH; other machines rewrite links once on their next `--apply`.

### Accepted behavior deltas (D3)
- Deploy replaces a live wrong-target link into the checkout; check prunes stale hook/script links and the retired `subagents.json`; deploy creates `~/.local/bin/{fix-links,deploy-workflow}`; agent/script prune needs a direct child with matching basename; deploy continues past a missing source and exits 1; grok check left to the installer; a missing catalogue skips record prune; foreign `.local/bin` files and a non-disposable `~/.pi/extensions` link are moved aside; link targets use the checkout realpath; user link chains ending in the checkout count as checkout links; `--dry-run` with a mutating mode exits 2; Pi settings migration stages an exclusive `0600` copy and renames it.

## Accepted Drift
- Original plan/spec: AC-10 listed `README.md` among the pointer updates; `claude-skill-load-check` was to change in its preamble only.
- Implemented reality: README unchanged (it names only the kept wrapper); the load-check heredoc reads `SKILL_NAMES` JSON because the bash helpers it used are gone.
- Why accepted: no stale reference remains; the helper removal forced the read.

## Validation Evidence
- command: `node --test tests/surfaces.test.mjs`
  - result: 23 pass, 0 fail; each review regression mutation-checked (fails without its fix)
- command: `scripts/verify-agentic-infra full`
  - result: 34/34 checks passed
- command: `cd pi && bun test extensions/__tests__/ && bun run typecheck`
  - result: 61 pass, 0 fail; tsc exit 0
- command: differential old (`5b1359d9`) vs new on shared, work and relocated `CLAUDE_CONFIG_DIR` fixture homes
  - result: final state identical after deploy + check --fix; per-stage diffs all within D3
- command: live `--dry-run`, `--apply`, `--dry-run`; `check-fix-symlinks.sh`; `fix-links check`; `claude-hooks-check`; both load checks
  - result: 0 `WOULD_` before and after; apply exit 0 (index 4776 / 3936); managed-surface snapshot unchanged (394 entries); 0 issues; all ok
- review: plan adversary 4 codex passes (folded). T1: Logic and Spec GO WITH NOTES, codex CHALLENGED (dry-run mutation with `--fix`, EACCES lexical fallback removing a foreign link, installer bypassing `NODE_CMD`) — fixed. D1: codex MEDIUM staged settings `0644` leftover — fixed. T2: Logic GO, Spec GO WITH NOTES, codex MEDIUM `--home <alias>/..` lexical — fixed. D2: Logic GO WITH NOTES, codex MEDIUM (non-blocking) listed below.

## Follow-up State
- Remaining risks: none open. The D2 follow-up (`activeScopes` and `claudeConfigOverride` joining `HOME` lexically) was fixed in the next commit via `physicalHome`; codex READY.
- Other machines: run `scripts/deploy-agent-workflow --apply` once; `check-fix-symlinks.sh` now requires Node on PATH.
- Superseded docs/specs: bash-library mechanics of ADR-0018/0031 superseded by ADR-0038 (scope decisions kept).
- Next links: `docs/adr/0038-reconcile-agent-surfaces-from-one-node-manifest.md`
