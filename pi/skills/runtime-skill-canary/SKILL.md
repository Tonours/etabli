---
name: runtime-skill-canary
description: Verify Etabli skill hashes, managed links and runtime discovery/invocation after installs, catalog changes, upgrades or sync.
disable-model-invocation: true
---

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
