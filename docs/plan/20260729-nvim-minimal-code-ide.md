# PLAN.md

## Meta
- Subject: Recentre Neovim as code-first minimal IDE (excise review/ADE; Catppuccin Mocha; adversary 10/10)
- Status: IMPLEMENTED (archived)
- Last revised: 2026-07-29
- Archive: docs/plan/20260729-nvim-minimal-code-ide.md

## Goal

Neovim is a fast, code-first minimal IDE aligned with tmux + Ghostty Catppuccin Mocha. In-nvim review inbox / Hunk rails / ADE are gone; Hunk remains optional external CLI/tmux. Parent Etabli workflow outside nvim is unchanged. Solid adversary 10/10 on the explicit grid with mechanical evidence.

## Workflow Contract
- Route: plan-implement
- Pattern: localize-repair-validate
- Role: implementer + local adversary loop
- Goal verifier: smoke + scorecard + independent grid review GO
- Budget: ≤8 slices; no-progress = 2 same-hypothesis fails or 3 red checks without new diff → blocked
- Context reset: after S1 excision if needed
- Escalation: block with evidence
- Stop condition: validation complete (smokes green, scorecard ≥9 all dims, 0 High, ADR honesty, archive)
- Required evidence: `docs/nvim-minimal-baseline.md`, `docs/nvim-minimal-scorecard.md`, scratch logs, green `tests/nvim-smoke.sh`

## Acceptance Criteria
- No runtime ReviewInbox / config.review / hunkreview / :Review* / leader r* review maps / Review which-key group
- Code workflow intact and documented code-first
- Theme Catppuccin Mocha; aligned with tmux + ghostty (palette pin preferred)
- Perf startup ≤ baseline (same probes)
- ADR-0003 superseded; scorecard 10 dims ≥9; adversary solid GO
- Plan archived under `docs/plan/YYYYMMDD-nvim-minimal-code-ide.md`

## Scope
### In
- nvim config, plugins, lock, docs, smokes, ADR-0003/0012, baseline + scorecard

### Out
- Rebuild review in nvim; rewrite workflow/spec; commit/push/PR unless asked; uninstall Hunk CLI

## Facts And Assumptions
### Observed Facts
- Review surface: 2203 LOC under `nvim/lua/config/review/**` + init/keymaps/which-key/ui
- Theme: `habamax`; terminal already Mocha
- Smoke baseline exit 0; headless startup median ~59ms wall; startuptime config ~7–13ms
- ADR-0003 status accepted; ADR-0009 removed local mirror but kept Hunk-in-nvim

### Assumptions
- Ember keep justified by `nvim/tests/ember_*` + vim-ember-hbs
- Copilot stays native lazy/opt-in (already non-blocking)
- catppuccin/nvim via vim.pack with explicit name `catppuccin.nvim`

## Steps
1. Baseline doc done (`docs/nvim-minimal-baseline.md`)
2. **S1** Delete `config/review/**`; strip commands/keymaps/which-key/bufferline; replace review smokes with absence asserts
3. **S2** Preserve code core; no dead pack drops without proof; keep Ember + Copilot
4. **S3** Catppuccin Mocha + `palette.lua` hex pin + UI cohesion; README mapping
5. **S4** Remeasure perf; fix if worse
6. **S5** Docs code-first; doctor green; ADR-0012 supersedes 0003; scorecard; adversary; archive plan

## Risks
- profile-nvim lazy profile broken — use startuptime + wall clock only
- `<leader>rn` must remain after Review group removal
- vim.pack name collision for catppuccin/nvim → force name `catppuccin.nvim`

## Adversary (pre-impl)
- P0 review surface + ADR honesty + habamax: addressed by S1/S3/S5
- No High left unscoped
- Status READY for implementation

## Validation
See goal verification plan: smokes, rg clean, theme pin, perf after, ADR, scorecard GO

## Implementation archive stamp
- Date: 2026-07-29
- Status: IMPLEMENTED
- Smokes: bash tests/nvim-smoke.sh → 0
- ADR: validate-adrs → 12 records; 0003 superseded by 0012
- Theme: catppuccin-mocha
- Scorecard: docs/nvim-minimal-scorecard.md
