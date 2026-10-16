# Implemented: etabli recentered as the Pi and Claude workflow harness

## Metadata
- Archived: 2026-10-16
- Source plan: `PLAN.md` — Recenter etabli on an AI harness for Pi and Claude only, workflow at its core
- Source plan SHA-256: `35a8490c9260ca3e55389825a9fde463d477b494622c8ac06f2f30b37475254c`
- Plan contract SHA-256 (READY, plan-adv-4): `b4745f347ea1cdd34e7e1969de694499315d98a1b8a42d1a51bf428de476172f`
- Status: IMPLEMENTED
- Commit / branch: `chore/recenter-harness` (24f93a3a..bbb369ec on 45d3e873)
- Workflow initiative: recenter-harness

## Outcome
- The efficiency lab (token budget, agent benchmark, efficiency campaign, bench and usage rollup) and `pi/durable` are deleted with every reference; `extras/` stays.
- `scripts/tmux-clipboard.sh` and `scripts/herdr-sync-mini` live in the dotfiles repo; `install.sh` removes only `~/.local/bin` links that still point into this checkout.
- Deploy manages `~/.claude` and `~/.pi/agent` only. `managed_surface_prune_retired_surfaces` removes this checkout's links from `~/.codex/skills`, `~/.config/devin/skills` and `~/.agents` (repo-target links plus the exact plan/workflow links) and leaves real directories, files and foreign links. The `agents_visible` column, the Codex skill source check and the Codex and Grok runtime entries are gone.
- `/etabli` loads in every Claude session: `claude/mods` is the `etabli-local` folder marketplace and `deploy_etabli_plugin` registers it and installs `etabli@etabli-local` at user scope, read from the checkout. The step is idempotent, re-points a marketplace registered elsewhere, compares physical paths, and WARNs instead of aborting on any CLI failure.
- ADR-0031 records the decision; it supersedes ADR-0015 and ADR-0024 and amends ADR-0011's `~/.agents` clause.

## Context
- Pi loads `~/.agents/skills` natively (`pi/node_modules/@earendil-works/pi-coding-agent/docs/skills.md:61`), so a skill left there still reaches Pi's prompt.
- `workflow-adapter-sync --check` was already red on main since 5d45f904: `write-direct` had no adapter-manifest row.
- Claude Code 2.1.301 `plugin marketplace add|install` run non-interactively; `plugin list --json` reports `readFromFolder` for folder installs. No `known_marketplaces.json` fallback was needed.

## Decisions
### Folder marketplace plus a re-pointing deploy step
- Context: `/etabli` only loaded under `--plugin-dir`.
- Choice: `claude/mods/.claude-plugin/marketplace.json` and a deploy step using the CLI.
- Rejected options: `CLAUDE_CODE_PLUGIN_DIRS` (another live settings merge); `--plugin-dir` in launchers (plain `claude` still lacks it).
- Rationale: one persistent install, read from the checkout, so mod edits apply on the next session.
- Consequences: a deploy from a worktree would re-point the marketplace to it; the step skips under `--home`, helper smokes, `ETABLI_SKIP_CLAUDE_PLUGIN=1`, or a `CLAUDE_CONFIG_DIR` outside the home.

### Prune only what this checkout created
- Context: the retired surfaces also hold user and dotfiles content (the dotfiles `herdr` skill link).
- Choice: symlinks whose literal target is under `$REPO_DIR/`, plus three exact `.agents` links.
- Consequences: relative links with `..` and links through another physical path are left behind; never over-removal.

## Accepted Drift
- Original plan/spec: AC-3 grep returns only the prune and its smoke.
- Implemented reality: it also lists `scripts/pi-skill-load-check`, `scripts/pi-dmi-stamp` and their smokes (`pi-skill-load-check-smoke`, `guards-active-smoke`), plus prune fixtures in `fix-links-smoke` and `vendor-*` smokes.
- Why accepted: those scripts read `~/.agents/skills` to measure Pi's native prompt; they deploy nothing (ADR-0031 Consequences).

- Original plan/spec: AC-1 grep returns nothing.
- Implemented reality: the `~/.local/bin/pi-durable` retirement cleanup in `install-main.sh` and `check-fix-symlinks.sh` remains.
- Why accepted: required by plan adversary pass 3 to clean live machines.

- Original plan/spec: manifest rows `etabli-mod` and `etabli-session-tests`.
- Implemented reality: `etabli-mod-smoke`, `etabli-session-test`, `etabli-session-mod-test`, plus `etabli-plugin-deploy-smoke` (stub `claude`) added by review.
- Why accepted: the runner runs one `.mjs` per row; the stub smoke gives the plugin step CI coverage without a `claude` binary.

- Original plan/spec: slice C edits listed files only.
- Implemented reality: `runtime-capabilities.json` drops the `grok` and `codex` runtimes; the cross-surface broken-mirror prune now matches `.claude/skills` only; a self-canonical `write-direct` adapter-manifest row was added.
- Why accepted: the runtimes named retired surfaces; the row makes `adapter-sync --check` green, which AC required.

- Original plan/spec: slice D commit `chore: move tmux clipboard to dotfiles`; ADR via the helper.
- Implemented reality: commit `chore: hand tmux-clipboard and herdr-sync-mini to dotfiles`; the helper takes one `supersedes`, so the ADR-0024 link and index status were added by hand in the helper's shape (`validate-adrs` passes).
- Why accepted: cosmetic; validator-enforced.

- Original plan/spec: docs name only Pi and Claude.
- Implemented reality: `docs/mcp-strategy.md` keeps the Codex MCP inventory and several Grok mentions (rows 18, 43, 71, 82).
- Why accepted: runtime-local MCP inventory, not a managed surface; Codex stays an adversary model provider (ADR-0029). Cleanup is a follow-up.

## Validation Evidence
- `scripts/verify-agentic-infra full` at bbb369ec
  - result: 92/92. Against the 92/92 main baseline: removed `durable-tests`, `claude-token-budget-smoke`, `claude-efficiency-campaign`, `codex-source`; added `etabli-mod-smoke`, `etabli-plugin-deploy-smoke`, `etabli-session-test`, `etabli-session-mod-test`; no other change.
- `scripts/verify-agentic-infra core`, `workflow-adapter-sync --check`, `node scripts/validate-adrs .`, `scripts/workflow-ref-linter`, `bun run verify:skills`
  - result: 34/34, clean, 31 records, clean, 81 hashes.
- Scratch `CLAUDE_CONFIG_DIR` with the real CLI: deploy step dry-run (WOULD only), apply (LINK + INSTALL), apply again (OK, OK), re-point from a copied marketplace (WOULD_REMOVE, then LINK + INSTALL, then OK); `claude -p --debug-file … "/etabli"` without `--plugin-dir`
  - result: `plugin.register: etabli (user, etabli@etabli-local)`, `/etabli listed`, bridge `node exited 0`.
- Real-HOME dry-run from the worktree (`.workflow/recenter-harness/real-home-dry-run.txt`) and post-merge prune preview from the main checkout (`post-merge-prune-preview.txt`)
  - result: no WOULD_REMOVE on retired surfaces from the worktree; from main, 29 + 29 + 17 etabli links and 3 exact `.agents` links, nothing foreign.
- Ledger check over the main `.workflow/` before and after slice B
  - result: identical (ok=141 quarantined=12 stale=2 failed=0).
- Review: T1 Logic and Spec hunters GO WITH NOTES, code_diff adversary code-adv-1 (zai/glm-5.3) CHALLENGED with one HIGH (bare CLI mutators under `set -e`), folded; T2 Logic and Spec GO WITH NOTES, code_diff adversary code-adv-2 READY but inadmissible (one grep on a guessed path), rerun code-adv-3 on the same pinned patch READY and admissible; round clean.

## Follow-up State
- Remaining risks: until the post-merge deploy runs from the main checkout, live Codex, Devin and `~/.agents` links still point at the main checkout and `/etabli` is not installed.
- Parking lot: Grok wording in `docs/mcp-strategy.md`; `pi-durable` cleanup removes any symlink of that name rather than only this checkout's; a marketplace named `etabli-local` from a non-directory source WARNs each deploy without repair; dry-run of the plugin step can print WOULD lines for an unresolvable `CLAUDE_CONFIG_DIR` that apply would skip; legacy `~/.pi/agent/skills -> ~/.agents/skills` mirrors left dangling are not auto-pruned. The legacy `~/.claude/skills/audit` cleanup left with the `.agents` block (absent on this machine). `docs/claude-etabli-mod.md` says the step skips with `--home`; precisely it skips when `--home` differs from `$HOME`. The real CLI JSON shape (`path`, `id`, `readFromFolder`) is pinned only by the stub; drift shows as a WARN each deploy.
- Superseded docs/specs: ADR-0015, ADR-0024.
- Next links: post-merge `scripts/deploy-agent-workflow` then `--apply` from the main checkout; register `tmux-clipboard.sh` in dotfiles `scripts/fix-links` and commit there; rebase `feat/review-dedup` (possible conflict on `review-rounds.jq`).
