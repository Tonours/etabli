---
status: accepted
date: 2026-10-17
tags: [tooling, deploy, simplification, claude, pi]
affected_components: [scripts/lib/surfaces.mjs, scripts/deploy-agent-workflow, scripts/check-fix-symlinks.sh, scripts/claude-skill-load-check, scripts/claude-hooks-check, scripts/claude-hooks-merge, scripts/lib/install-main.sh]
---

# Reconcile agent surfaces from one Node manifest

`scripts/lib/surfaces.mjs` now holds the skill catalog reader, the active scopes, the Claude config dir and one reconciler; `scripts/deploy-agent-workflow` is a Node script over it, and `scripts/check-fix-symlinks.sh` is a wrapper for `deploy-agent-workflow --check [--fix]`. Deploy and check walk the same desired state, so a link one of them knew and the other did not (stale hooks and scripts, `~/.local/bin` links, theme files, the retired `subagents.json`) can no longer drift. Checkout membership is physical (`realpath.native` per component, dangling symlinks followed, loops foreign), which replaces the lexical `..` guards. This keeps ADR-0018's single convergence entry point and ADR-0031's surface scope; it replaces their bash libraries (`managed-surfaces.sh`, `skill-catalog.sh`, `etabli-scope.sh`, `claude-config-dir.sh`).

## Consequences

- Good, because the bash failure classes behind three HIGH findings (errexit inside `$(…)`, errexit suspended by a caller `|| return`, lexical `..` escapes) are gone, and a failed backup is an exception counted as unresolved instead of a status that callers had to propagate.
- Good, because a differential run of the old and new scripts on three seeded homes (shared, work, relocated `CLAUDE_CONFIG_DIR`) ended in identical state after deploy plus `--check --fix`.
- Bad, because check needs Node on PATH; fixtures that replace HOME must put the real Node directory first, since asdf shims resolve Node from HOME.
- Bad, because link targets use the checkout's realpath: a checkout reached through a symlink gets its links rewritten once.
- The grok `agent` collision check left `check-fix`: the installer and the rc hook from `prefer-cursor-agent.sh` own it.

## Considered Options

- Keep bash and add a manifest: rejected, the manifest would still run through the same errexit and `$(…)` semantics.
- Generate the check list from deploy in bash: rejected for the same reason.
