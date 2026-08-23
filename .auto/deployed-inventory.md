# Deployed-surface inventory (iteration 10, read-only audit)

Scope declared: `work`. Every live link on the 4 agent surfaces resolves and is
classified. Repo-managed deployment is COMPLETE and contract-conform.

## Repo-managed (this repo's authority) — all correct

- `~/.pi/agent/skills`: 14/14 piCore present + herdr symlink. ✓
- `~/.agents/skills`: 14/14 agents_visible present (incl. `runtime-skill-canary`),
  - herdr. ✓
- `~/.claude/skills`: shared+work scope skills (write-direct, spec, week-roadmap,
  frontend-css-*, ember ×13, forest-backend-suite, adr, playwright-*, …). ✓
- `~/.codex/skills`: work-scope ember ×13 + herdr + user bridges. ✓

## User-managed external (deliberate — left untouched, report only)

- Standalone clones beside the repo: `/Volumes/Crucial/work/adonisjs-skills`
  (385 files) and `/Volumes/Crucial/work/tanstack-start-skills` (348 files).
  Skills bridge from these onto surfaces: adonisjs ×6 on pi+claude,
  tanstack ×18 on claude. NOTE: this means tanstack skills ARE consumed daily —
  via the user's clone, never via the (now deleted) vendored snapshot, which
  had zero deployed links. The iteration-1 deletion rationale holds.
- `~/.agents/skills` real directories (~30: impeccable, code-review, deslop,
  control-cli, html-prototype, weekly-review, …) — the shared Grok/npm surface,
  never symlinked by this repo.
- `~/.agents/skills.disabled/ui-pruned-2026-04-28` — user's dated manual
  pruning archive (e.g. `audit` links there).
- Cross-surface bridges: `obsidian` (codex→claude), relative `../../.agents/*`
  bridges (impeccable, brave-search, code-review, …).

## Validation

How the claims above were established (last run: 2026-08-23, session
iteration 10; re-verified iteration 19):

- Dangling-link census — command: `find <surface> -maxdepth 1 -type l ! -exec
  test -e {} \; -print` per surface (~/.pi/agent/skills, ~/.claude/skills,
  ~/.codex/skills, ~/.agents/skills), then `readlink` on each; result: 71
  dangling, 42 repo-managed (pruned, 0 remain repo-managed), 38 external.
- Catalog conformance — cross-check of `workflow/runtime/skill-surface.tsv`
  flags against live links: piCore 14/14 on pi, agents_visible 14/14 on
  agents; result: passed.
- Scope — read `~/.etabli-scope`; result: `work`.
- Clone health — `find <clone> -type f | wc -l` + `diff -rq` vendored vs
  clone; result: adonisjs diff=0 (curated), tanstack clone live at 348 files.
- Vault/merge facts — `obvault loop --json` (222 notes, 0 errors) and
  `git merge-tree --write-tree main HEAD`; result: rc=0.

## Remaining risks

- Point-in-time census: nothing prevents new dangling links after this run;
  repo-managed ones are caught by the next `scripts/install.sh` prune pass,
  external ones by nothing (no checker owns user-created links).
- The 38 external links are user decisions pending; if pruned without review,
  any tooling still referencing them by name will report missing skills.
- The adonisjs personal-scope question (12 links under work scope) is
  inconclusive from repo evidence alone — only the user knows intent.
- `/Volumes/Crucial/work/*` clones are external state: they can move or be
  deleted independently of this repo; re-run the readlink census before
  relying on the classification.
- The session branch `autoresearch/simplify-etabli-20260823` (38 commits)
  exists only on this machine — no remote copy. A disk loss before merge
  loses the work; merging (or pushing a backup ref, user-gated) removes
  that risk.

- The 38 dangling links detail (from the census above): 26 on pi surface
  (old ui.sh/taste design set), 6 french business skills on codex, 6 on
  agents. Zero data at risk (targets deleted, not content); user-created,
  so not pruned autonomously — say the word and all 38 go.

## Scope observation (user decision only)

adonisjs (personal-scope) skills are linked on pi/claude while the declared
scope is `work`. The installer contract would not deploy them under work;
they come from the user's clone. If intentional, ignore; if stale from a
personal-scope era, prune the 12 links.
