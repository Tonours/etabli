---
status: superseded by ADR-0012
date: 2026-06-09
tags: [review, hunk, nvim]
affected_components: [nvim/lua/config/review, README.md]
superseded_by: ADR-0012
---

# Use Hunk as the default review surface

Etabli makes Hunk the default review surface and keeps legacy Neovim annotations hidden by default. This accepts dependency on the external Hunk workflow because review persistence, diff navigation, and agent handoff are more robust in a dedicated review tool than in bespoke local annotation state.

Superseded by ADR-0012: nvim is a code-first minimal IDE; Hunk is external CLI/tmux only, not an in-nvim cockpit.
