---
status: accepted
date: 2026-02-25
tags: [agent-runtime, pi, config]
affected_components: [pi, scripts/install.sh]
---

# Track Pi as a first-class local agent runtime

Etabli tracks Pi agent configuration, extensions, skills, themes, and symlink layout in this repository instead of relying on untracked live Claude or OpenCode state. This accepts repo ownership of Pi API drift and bootstrap complexity because local safety gates, redaction, task enforcement, and runtime defaults need reproducible code, tests, and reviewable changes. Claude and Codex surfaces can still exist as adapters, but Pi remains a first-class tracked runtime rather than ephemeral dotfiles.
