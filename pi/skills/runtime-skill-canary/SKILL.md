---
name: runtime-skill-canary
description: Verify Etabli skill hashes, managed links and runtime discovery/invocation after installs, catalog changes, upgrades or sync. Use only when explicitly asked via /skill:runtime-skill-canary; not for general health checks.
disable-model-invocation: true
---
<!-- GENERATED:adapter-sync:start -->
skill: runtime-skill-canary
harness: pi
canonical: pi/skills/runtime-skill-canary/SKILL.md
name: runtime-skill-canary
description: Verify Etabli skill hashes, managed links and runtime discovery/invocation after installs, catalog changes, upgrades or sync. Use only when explicitly asked via /skill:runtime-skill-canary; not for general health checks.
pointer: Adapter for the `runtime-skill-canary` skill. Read and follow the shared contract in `pi/skills/runtime-skill-canary/SKILL.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Runtime Skill Canary

Use `scripts/runtime-skill-canary` and keep its three evidence layers separate:

1. `source_locked`: the skill exists and is declared locked in the canonical
   catalog.
2. `link_valid`: the managed shared link resolves to that exact source.
3. `runtime_invoked`: an opt-in, bounded, tool-free runtime call returned the
   response documented only inside this skill.

Run offline proof by default:

```bash
scripts/runtime-skill-canary --json
```

Run provider-backed invocation only when explicitly authorized:

```bash
RUN_SKILL_RUNTIME_CANARY=1 scripts/runtime-skill-canary --live --json
```

Preserve `skipped`, `unknown`, and `failed` states. Never infer invocation from
a source hash, a valid symlink, a binary version, or a provider-independent
config inspection.

## Canary

When a runtime asks to invoke this skill and return its documented canary
response, reply with exactly the following value and no other text.

Canary response: `ETABLI_RUNTIME_SKILL_CANARY_V1_7F3C9A`
