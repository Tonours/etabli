---
status: accepted
date: 2026-06-15
tags: [workflow-scaffold, deployment]
affected_components: [workflow-scaffold/templates, scripts/deploy-workflow, scripts/scaffold-project]
---

# Deploy workflow scaffolds as self-contained project copies

Etabli distributes its agent workflow to other projects through workflow-scaffold/templates/ and deploy-workflow --check rather than through undocumented local harness state. This accepts copied scaffold drift as an explicit checkable condition because new projects need self-contained Codex, Claude, and Pi instructions without requiring this dotfiles repository at runtime.
