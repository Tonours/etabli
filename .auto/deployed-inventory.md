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

## Open item (user decision only)

38 dangling symlinks whose targets are already gone (26 on pi surface: old
ui.sh/taste design set; 6 french business skills on codex; 6 on agents).
Zero data at risk (symlink targets deleted, not content), but the links are
user-created → not pruned autonomously. Say the word and I prune all 38.

## Scope observation (user decision only)

adonisjs (personal-scope) skills are linked on pi/claude while the declared
scope is `work`. The installer contract would not deploy them under work;
they come from the user's clone. If intentional, ignore; if stale from a
personal-scope era, prune the 12 links.
