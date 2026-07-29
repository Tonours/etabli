---
status: accepted
date: 2026-07-29
tags: [nvim, review, theme, performance]
affected_components: [nvim, docs/adr/0003]
supersedes: ADR-0003
---

# Neovim is a code-first minimal IDE

Etabli treats Neovim as a fast code editor (files, grep, LSP, format, diagnostics, basic git signs) with Catppuccin Mocha aligned to Ghostty and tmux. In-editor review inbox, Hunk rails, comment editor, and first-pass Claude/Pi review commands are removed from nvim. Hunk may remain as an optional external CLI or tmux pane for product diff review; it is not a subsystem of the Neovim config. This supersedes ADR-0003’s decision that Hunk is the default review surface *inside* nvim, because that cockpit competed with the code workflow and bloated startup surface without owning agent orchestration (which stays in Pi/Claude/workflow).
