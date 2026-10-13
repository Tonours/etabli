---
status: accepted
date: 2026-10-12
tags: [workflow, verification, self-improvement]
affected_components: [workflow/project-constraints.md, scripts/lib/project-verification-recipe.mjs, scripts/lib/workflow-patterns.mjs, workflow/templates/escaped-defect.md]
---

# Promote recurring findings into project-native constraints

A recurring agent mistake on a project's code becomes a constraint in that project's own tooling, taking the first rung that can express it (type, existing linter rule, structural test, CI check, prose last), shipped with a failing-before/passing-after case and never auto-applied; the cold contract `workflow/project-constraints.md` holds the rule, `project-verification discover` reports where constraint config lives (presence only, no content read, no symlinks), and `workflow-ship-metrics` reuses its existing three-family detector to recommend a project constraint only for findings seen purely in code-diff review. Etabli owns this loop, never framework-specific rules: shipping per-framework rules and running linters inside discover were rejected, and an ast-grep fallback is deferred until a need is measured.
