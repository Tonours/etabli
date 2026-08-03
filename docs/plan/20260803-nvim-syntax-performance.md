# Implemented: reliable Neovim first-open coloring with bounded parser work

## Metadata

- Archived: 2026-08-03
- Source plan: `PLAN.md`
- Source plan SHA-256: `c5a3732a4e423bf561e0a0692c20603cd78eaa625836cc2835084f77cc4f01fd`
- Status: IMPLEMENTED
- Commit / branch: uncommitted working tree

## Outcome

- Files from 512 KiB through 3 MiB are marked before `FileType`, retain Vim native syntax coloring, and continue to skip LSP, formatting, and Tree-sitter work.
- Files larger than 3 MiB still disable syntax after filetype detection, preserving the responsiveness safeguard.
- Tree-sitter no longer tries to install the complete parser set on the first opened buffer. It requests only parsers associated with the active filetype, avoids large buffers, deduplicates in-flight requests, and starts waiting buffers after a successful installation.
- The stale lazy.nvim profiler is replaced by startup and actual event-dispatch probes compatible with `vim.pack`.
- No runtime ADE/review surface remains; historical plans and ADRs were intentionally retained.

## Context

- `nvim/lua/config/autocmds.lua`: the prior medium-file path delayed marking and called `syntax=off`; `:edit` buffers could also be skipped because they were not yet `buflisted` at `BufReadPre`.
- `nvim/lua/plugins/treesitter.lua`: the previous first plugin load requested all 16 configured parsers and did not restart a buffer when installation finished.
- `scripts/profile-nvim.sh`: still imported `lazy.core.util` despite ADR-0010 replacing lazy.nvim with `vim.pack`.

## Decisions

### Split medium and hard file behavior

- Context: syntax must be visible for ordinary large sources without restoring expensive services.
- Choice: set `b:large_file` synchronously from 512 KiB, preserve native syntax until 3 MiB, and schedule `syntax=off` from `BufReadPost` only for the hard threshold.
- Rejected options: raise the medium threshold to 3 MiB, or re-enable Tree-sitter/LSP/formatting for all medium files.
- Rationale: it fixes the observed first-open regression while retaining the established cost guards.
- Consequences: very dense medium files use native syntax bounded by existing `synmaxcol=300`; >3 MiB deliberately remains uncolored.

### Make Tree-sitter parser installation demand-driven

- Context: no local parsers were installed, so the old code requested every configured grammar after the first buffer.
- Choice: map supported filetypes to their parser requirements, start synchronously when available, otherwise install only missing parsers and retry waiting buffers after success.
- Rejected options: installing parsers in smoke tests or retaining a global batch install.
- Rationale: the first-open fallback remains immediate and offline-safe while later parser work is proportionate.
- Consequences: first use of an uninstalled parser still depends on external installation capability, but it no longer blocks coloring or produces broad startup work.

### Keep ADE history, remove only runtime concerns

- Context: the request asked for all Neovim ADE logic removed; ADR-0012 and prior archives document the already-completed removal.
- Choice: keep historical evidence, verify the live runtime has no `config.review`, `:Review*`, `hunkreview`, or ADE markers.
- Rejected options: deleting archives and ADRs.
- Rationale: archives are not executable logic and preserve decision provenance.
- Consequences: future runtime searches stay clean while history remains auditable.

## Accepted Drift

- Original plan/spec: the first ledger stopped after the intentional red regression and one incomplete correction triggered `no_progress`.
- Implemented reality: a terminal ledger was recorded, then a fresh ledger isolated two additional mechanics: the premature `buflisted` filter and macOS `/var` versus `/private/var` test paths; it also confirmed filetype detection overwrites `syntax=off` set too early.
- Why accepted: the corrective changes remain inside the original files, behavior, and acceptance criteria; the fresh run added a stronger reproduction rather than expanding product scope.

## Validation Evidence

- `bash tests/nvim-smoke.sh`
  - result: exit 0; UI, syntax, review-absence, doctor, and top-level Neovim smoke passed.
- `cd nvim && nvim --headless --cmd "set rtp+=$PWD" -l tests/ember_spec.lua`
  - result: 29 passed, 0 failed.
- `cd nvim && nvim --headless --cmd "set rtp+=$PWD" -l tests/ember_cursor_spec.lua`
  - result: 28 passed, 0 failed.
- `bash scripts/profile-nvim.sh`
  - result: exit 0; startup plus `VeryLazy` and `InsertEnter` dispatch timings printed with no lazy.nvim import.
- `rg -n 'ReviewInbox|config\.review|hunkreview|:Review' nvim/` and `rg -n -i '\bADE\b' nvim/`
  - result: no runtime matches.
- `git diff --check`
  - result: clean.
- Primary diagnostics for `nvim/lua/config/autocmds.lua` and `nvim/lua/plugins/treesitter.lua`
  - result: no errors; an auxiliary typo scanner misread `ede` inside the pinned Tree-sitter commit fragment.
- Fresh read-only review (`openai-codex/gpt-5.6-luna`) and adversary diff pass
  - result: no actionable findings; GO recorded in the active ledger.

## Follow-up State

- Remaining risks: parser download still requires network/compiler support on the first use of a language; this is explicitly nonblocking because native syntax is present.
- Parking lot: compare the new `vim.pack` profiler across multiple warm/cold interactive sessions before treating its millisecond values as a performance target.
- Superseded docs/specs: none; historical ADE documents remain accurate history, not runtime guidance.
- Next links: `nvim/README.md`, `docs/adr/0010-replace-lazy-nvim-with-vim-pack.md`, `docs/adr/0012-nvim-is-a-code-first-minimal-ide.md`.
