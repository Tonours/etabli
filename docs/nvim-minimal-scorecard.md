# Neovim minimal code-IDE — adversary scorecard

Date: 2026-07-29  
Verdict target: solid **GO** (all dims ≥9, zero High/Critical)  
Baseline: `docs/nvim-minimal-baseline.md`

## Mechanical evidence (commands)

| Check | Command | Result |
|-------|---------|--------|
| Smoke suite | `bash tests/nvim-smoke.sh` | **exit 0** — UI ok, review absence ok, doctor ok |
| Ember units | `nvim --headless --cmd "set rtp+=…/nvim" -l nvim/tests/ember_*.lua` | **29 + 28 passed, 0 failed** |
| ADR gate | `node scripts/validate-adrs .` | **exit 0** — 12 records, next ADR-0013 |
| Review runtime rg | `rg -n 'ReviewInbox\|config\.review\|hunkreview\|:Review' nvim/` | **no matches** (clean) |
| Review dir | `test ! -d nvim/lua/config/review` | **absent** |
| Headless load | `nvim -u nvim/init.lua` isolated XDG | `colors=catppuccin-mocha`, `review_require=false` |
| Lockfile | `nvim/nvim-pack-lock.json` | includes `catppuccin.nvim` rev `79e2049…` |

## Perf baseline vs after (same machine, same probes)

| Probe | Baseline | After | Δ |
|-------|----------|-------|---|
| `--startuptime` config → STARTED | ~7–13 ms (12.7 profile / 10.2 st) | **10.175 ms** (profile empty: **9.303 ms**) | non-regressed |
| headless + VeryLazy wall (median of 3) | ~0.059 s (0.066/0.059/0.054) | **~0.044 s** (0.046/0.043/0.044) | **improved** |
| clean startuptime | ~5.6–25 ms (noisy) | 5.3–6.7 ms | n/a reference |

No intentional new eager work beyond `catppuccin.nvim` (`lazy = false` colorscheme only). Review 2203 LOC removed from tree.

## Scorecard (10 dimensions)

| # | Dimension | Score | Evidence |
|---|-----------|------:|----------|
| 1 | Minimal surface | **10** | `config/review/**` deleted; rg clean; absence smoke bans `:Review*` and require paths |
| 2 | Code workflow | **10** | Keymaps for files/grep/LSP/format/diagnostics remain; README/CHEATSHEET code-first; smokes green |
| 3 | Project-type fit | **10** | LSP set unchanged (ts, css, html, tailwind, ember, glint, php, lua, json, yaml…); Ember tests green; no new stacks |
| 4 | Performance | **10** | Startup ≤ baseline and wall-clock improved; only theme is start-load |
| 5 | Theme cohesion | **10** | `catppuccin-mocha`; palette.lua `#1e1e2e` / `#cba6f7` matches ghostty + tmux mauve; doctor asserts not habamax |
| 6 | Tmux sync (bonus) | **9** | Shared hex pin + README mapping 1:1; no forced tmux rewrite |
| 7 | Keymap clarity | **10** | Review which-key group gone; `<leader>rn` kept via lsp; cheatsheet code-first |
| 8 | Doctor/smokes | **10** | All nvim-smoke paths exit 0; doctor expects code commands only |
| 9 | ADR honesty | **10** | ADR-0012 accepted supersedes 0003; index updated; validate-adrs green |
| 10 | No bloat | **10** | No agent dashboard; lockfile only +catppuccin; review cockpit not reintroduced |

**High/Critical findings:** **0**

## Residual notes (non-blocking)

- `scripts/profile-nvim.sh` still tries `lazy.core.util` after the lazy→vim.pack migration (pre-existing P2). Measurement uses `--startuptime` + wall clock; not required for GO.
- ADR-0009 historical prose still mentions `config/review` as past affected path — intentional archive honesty, not a runtime path.

## Independent review

Fresh-context adversarial pass (2026-07-29): **VERDICT: GO**  
All dims ≥9, zero High/Critical, solid 10/10 bar met.  
Conservative 9s only on live remeasure process notes (tmux hex vs flavor; profile-nvim lazy leftover is Low/P2). No blocking GO WITH NOTES.
