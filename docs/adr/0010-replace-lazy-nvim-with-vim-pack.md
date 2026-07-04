---
status: accepted
date: 2026-07-04
tags: [nvim, performance, plugins]
affected_components: [nvim/init.lua, nvim/lua/plugins, nvim/lua/config/bootstrap.lua]
---

# Replace lazy.nvim with vim.pack

Etabli replaces lazy.nvim with the Neovim 0.12 builtin `vim.pack` plugin manager plus a small local loader (`config.pack`) that interprets the existing plugin specs (event, cmd, ft, keys, dependencies, opts, config). lazy.nvim's own core was the largest remaining startup cost after the 2026-07-04 optimization pass; the migration cut median startup from 22.8ms to 12.6ms. This accepts losing lazy.nvim's UI, lockfile pinning, and require-hook autoloading in exchange for a dependency-free, deterministic loader; `vim.pack.add` runs only when a plugin directory is missing so steady-state startup pays no manager cost.
