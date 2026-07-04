---
status: accepted
date: 2026-07-04
tags: [review, hunk, nvim, performance]
affected_components: [nvim/lua/config/review, nvim/init.lua, nvim/lua/config/keymaps.lua, README.md]
---

# Remove the legacy local review mirror

Etabli removes the legacy local review module and the Hunk note mirror (state, items, diff, annotations, transactions, suggestions, sync). Hunk owns review sessions and notes; every review action now talks to the Hunk CLI directly and the context rail refreshes asynchronously. This accepts losing the local durability fallback because the mirror ran multiple blocking CLI and git calls on every review action, which made the review flow visibly slow, while Hunk session persistence covers the original gap.
