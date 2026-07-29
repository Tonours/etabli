# Neovim minimal code-IDE — pre-mutation baseline

Captured: 2026-07-29 on this machine. Scratch: goal implementer dir (`nvim-baseline-inventory.txt`, `nvim-smoke-baseline.log`, `nvim-perf-baseline.log`).

## Inventory — review/ADE surface (to remove)

| Path | LOC |
|------|-----|
| `nvim/lua/config/review/hunk.lua` | 732 |
| `nvim/lua/config/review/hunk_flow.lua` | 510 |
| `nvim/lua/config/review/providers.lua` | 303 |
| `nvim/lua/config/review/hunk_rail.lua` | 278 |
| `nvim/lua/config/review/util.lua` | 205 |
| `nvim/lua/config/review/hunk_comment_editor.lua` | 175 |
| **Total** | **2203** |

**Runtime loaders (not under `review/`):**

- `nvim/init.lua:33–68` — `:Review*` lazy user commands → `config.review.hunk_flow`
- `nvim/lua/config/keymaps.lua:232–264` — `<leader>ri|rh|ra|rj|rk|rH|r?|rx|rc|rp`
- `nvim/lua/plugins/which-key.lua:19` — `{ "<leader>r", group = "Review" }`
- `nvim/lua/plugins/ui.lua:59–61` — bufferline `hunkreview` name_formatter
- filetypes `hunkreview` / `hunkreviewrail` set inside review modules

**Docs identity:** `nvim/README.md` / `CHEATSHEET.md` still describe “Review-first daily-driver”.

## Plugin pack (must-keep vs drop)

From `nvim/nvim-pack-lock.json` (no catppuccin yet):

| Keep | Role |
|------|------|
| telescope + fzf-native, plenary | files/grep |
| nvim-lspconfig, nvim-cmp + sources, conform | LSP/completion/format |
| nvim-treesitter | syntax |
| neo-tree + nui, bufferline, nvim-web-devicons | files/chrome |
| which-key, gitsigns, mini.bufremove | maps / git / buffers |
| grug-far | find-replace |
| render-markdown | light MD (not second docs IDE) |
| vim-ember-hbs | Ember HBS (kept if tests remain green) |

| Drop (S1) | Role |
|-----------|------|
| *none from lock* | review is local Lua only (~2.2k LOC), not a pack plugin |

| Add (S3) | Role |
|----------|------|
| catppuccin/nvim (as `catppuccin.nvim`) | Catppuccin Mocha = tmux + Ghostty |

## Perf baseline (same machine)

`scripts/profile-nvim.sh` empty startup:

| Probe | ms |
|-------|-----|
| clean `--startuptime` | 25.086 |
| config `--startuptime` | 12.727 |
| delta (config − clean) | −12.359 (noisy; config can win when plugins already on disk) |

Isolated `XDG_*` + headless `-u nvim/init.lua` + `VeryLazy` fire (wall clock, 3 runs):

| Run | s |
|-----|---|
| 1 | 0.0658 |
| 2 | 0.0586 |
| 3 | 0.0541 |
| **median** | **~0.059** |

`--startuptime` config path (another run): **~7–10 ms** to `--- NVIM STARTED ---`.

Notes:

- `scripts/profile-nvim.sh` still references `lazy.core.util` (broken after vim.pack) — baseline uses `--startuptime` + wall-clock headless, not fake lazy profile rows.
- `scripts/profile-nvim-runtime.sh` partial (write-path OK; TS LSP noise on non-TS fixture).

## Smoke baseline

```text
bash tests/nvim-smoke.sh → exit 0
  nvim UI smoke ok
  hunk lazy smoke ok
  etabli doctor smoke ok
  nvim smoke test: ok
```

## Adversary dims (pre-mutation scores 0–10)

Target state assumed: no in-nvim review; code-first minimal IDE; Mocha; Hunk external CLI only.

| # | Dimension | Score | Notes |
|---|-----------|------:|-------|
| 1 | Minimal surface (no review/ADE) | 1 | Full review subsystem live |
| 2 | Code workflow completeness | 8 | Files/grep/LSP/format present; docs bury under review-first |
| 3 | Project-type fit | 8 | TS/React/Ember/Tailwind/PHP/Lua covered |
| 4 | Startup/perf risk | 7 | Tuned; ~2.2k review LOC is dead weight when unused |
| 5 | Theme vs tmux Mocha | 2 | `habamax` default; clash with Ghostty/tmux |
| 6 | Keymap/docs clarity | 3 | Review group + review-first README |
| 7 | Dead code/plugins | 2 | Entire `config/review/**` is the dead surface for new goal |
| 8 | Doctor/smokes | 7 | Green but assert review *presence* |
| 9 | ADR-0003 honesty | 2 | Still `accepted` for nvim Hunk surface |
| 10 | Bloat risk | 4 | Review cockpit is the bloat |

## Findings P0–P3 (file:line)

### P0

- `nvim/init.lua:33–68` — Review command surface wired at startup
- `nvim/lua/config/review/**` — 2203 LOC in-nvim ADE/Hunk cockpit
- `docs/adr/0003-…md` status `accepted` — contradicts code-first direction

### P1

- `nvim/lua/config/keymaps.lua:232–264` — `<leader>r*` review maps
- `nvim/lua/plugins/which-key.lua:19` — Review group
- `nvim/init.lua:9` / `README.md:65` — `habamax` not Mocha
- `scripts/review_hunk_lazy_smoke.lua` + doctor smoke — require live review modules

### P2

- `nvim/lua/plugins/ui.lua:59` — `hunkreview` bufferline special-case
- `nvim/README.md` / `CHEATSHEET.md` — review-first identity
- `scripts/profile-nvim.sh` — lazy.nvim API leftover

### P3

- Empty `config/statusline.lua` — fine for minimal; no Mocha chrome yet
- render-markdown — keep unless proven unused (light ft-scoped)

## Ordered slices to solid 10

1. Baseline artifacts (this doc) + root PLAN READY  
2. S1 excise review runtime + smokes assert absence  
3. S2 keep code core / Ember with tests / no agent UI  
4. S3 Catppuccin Mocha + palette pin + docs  
5. S4 perf remeasure non-regression  
6. S5 doctor/docs/ADR-0012 supersedes 0003 / scorecard / adversary GO / archive  
