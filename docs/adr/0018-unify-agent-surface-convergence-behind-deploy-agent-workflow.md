---
status: accepted
date: 2026-08-24
tags: [installer, deploy, reconciler, agent-surfaces, supply-chain]
affected_components: [scripts/lib/install-main.sh, scripts/deploy-agent-workflow, scripts/check-fix-symlinks.sh]
---

# Unify agent-surface convergence behind deploy-agent-workflow

## Context

Three scripts converge the same `$HOME` agent surfaces (`~/.pi/agent`,
`~/.claude`, `~/.codex`, `~/.agents`) with separate policies:
`scripts/lib/install-main.sh` (workstation bootstrap + inline agent
convergence), `scripts/deploy-agent-workflow` (agent-only deployer,
dry-run default), and `scripts/check-fix-symlinks.sh` (checker/fixer). The
2026-08-23 branch council measured the cost of that triplication twice in one
session: the `cross_harness` removal silently deleted the only live cleanup
(the prune), and the deployer carried a hardcoded `managedModels` roster that
diverged from the installer's tracked-models policy.

## Decision

1. **One policy per fact, consumed everywhere.** Managed models come from the
   tracked `pi/agent/settings.json` `enabledModels` list — the deployer now
   reads that list directly; the hardcoded roster is gone. Any future managed
   surface fact (paths, keep-lists) gets one declarative source before it gets
   a second consumer.
2. **Delegate, do not duplicate.** When an existing script already implements
   a convergence policy, callers delegate to it instead of re-implementing.
   The deployer is the convergence engine; the installer is a workstation
   bootstrap that will call it rather than inline its own link blocks.
3. **Slice 2 (structural, deferred with entry criteria):** extract the
   deployer's link/prune core into a shared `scripts/lib/` consumed by the
   deployer and the checker, and move `install-main.sh`'s agent section to a
   `deploy-agent-workflow --apply` call. Entry criteria: the next touch of
   either script's structure (not a hotfix), with the harness-eval smoke and
   `deploy-agent-workflow-smoke` extended first to pin current link
   behavior.
4. **Strict mode now.** `install-main.sh` runs under `set -euo pipefail`
   (bash-3 array sentinels already guard empty expansions).

## Consequences

- Good: the demonstrated divergence class (two rosters for one surface) is
  closed at the source; the checker remains a read-only verifier until slice
  2 makes it a true mode of the shared engine.
- Bad: until slice 2, link/prune logic still exists in two places
  (installer, deployer); drift there is possible and must be caught by the
  deploy/fix-links smokes.
- The full installer/workstation split (brew, fonts, editors vs agent
  surfaces) is part of slice 2, not a separate project.
