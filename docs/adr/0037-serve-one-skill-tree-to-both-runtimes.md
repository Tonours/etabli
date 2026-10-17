---
status: accepted
date: 2026-10-17
tags: [workflow, skills, multi-agent, simplification]
affected_components: [skills, workflow/runtime/skill-surface.tsv, scripts/deploy-agent-workflow, scripts/check-fix-symlinks.sh, scripts/lib, claude/settings.skill-overrides.json, pi/agent/settings.json]
---

# Serve one skill tree to both runtimes

First-party skills now live once in `skills/<scope>/<name>/SKILL.md` and are linked into both `~/.claude/skills/` and `~/.pi/agent/skills/` from catalog rows with source `etabli`; Claude gets every active-scope row, Pi only `pi_core=1` rows. This retires `pi/skills/`, `claude/scopes/*/skills/` and the Claude commands under `claude/scopes/*/commands/`, which duplicated the same adapters with drifting wording, and the `local:etabli-workflow` Pi package entry, which Pi silently ignored. It amends ADR-0006: the adapter layer stays thin over `workflow/skills/`, but it is one file per skill, not one per runtime. The shared agent rules move from `pi/AGENTS.md` to `workflow/agent-rules.md`, imported by `claude/CLAUDE.md` and linked as `~/.pi/agent/AGENTS.md`.

## Consequences

- Good, because one edit reaches both runtimes, scope applies to Pi as well as Claude, and the lock, catalog and governance map derive from one tree.
- Bad, because Claude-only frontmatter (`argument-hint`, `allowed-tools`) rides along in files Pi reads (Pi ignores unknown keys), and slash entries that were commands now count in Claude's model-facing index, so explicit-only skills are mapped `user-invocable-only`.
- Bad, because Pi now honours scope too: a `personal` machine's Pi loses the `work` Linear and `bug-check` skills it used to get; moving a skill to `skills/shared/` restores it.
- Bad, because other machines keep dangling links and retired command links until their next `scripts/deploy-agent-workflow --apply`, which prunes them.

## Considered Options

- Link `pi/skills/` into Claude as well: rejected, Claude-only commands and scoped skills would still need their own tree, so two layouts would survive.
- Generate Claude commands from Pi skills: rejected, a generator and its drift check cost more than one file Pi reads with two ignored frontmatter keys.
