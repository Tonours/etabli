---
status: accepted
date: 2026-10-25
tags: [tooling, security, vendor, claude, glm]
affected_components: [vendor/sources.tsv, vendor/cloudflare, scripts/security-audit-glm, scripts/lib/surfaces.mjs, workflow/runtime/skill-surface.tsv, claude/settings.skill-overrides.json]
---

# Run the Cloudflare security audit on GLM

Cloudflare's `security-audit` skill (`cloudflare/security-audit-skill`, MIT) is vendored under `vendor/cloudflare` in the `shared` scope, `user-invocable-only` on Claude and off Pi's core set. `scripts/security-audit-glm`, linked as `~/.local/bin/security-audit-glm`, runs it in Claude Code against the Z.ai Anthropic endpoint (`ZAI_API_KEY`) so the session, its auto-mode classifier and every subagent run on one GLM model, `glm-5.3[1m]` at effort `max` by default.

The harness is Claude Code, not Pi, because the skill needs fresh, isolated verifier agents and Pi's subagent capability is still `unknown` (`workflow/skills/orchestration.md`). A 2026-10-25 probe through the endpoint showed a GLM session spawning a GLM subagent through the `Agent` tool, `--effort max` raising GLM reasoning output about tenfold over `low`, and `auto` mode running a shell command.

`glm-5.3` is the default over `glm-5.3-flash`: Z.ai publishes cyber results only for GLM-5.3 (CyberGym 84.5, ExploitBench 54.4), and Flash scores lower on DeepSWE (63.4 against 66.9). GLM takes `low`, `high` and `max`; there is no `xhigh`.

## Consequences

- The runner uses its own `CLAUDE_CONFIG_DIR` (`~/.local/state/security-audit-glm`), `--setting-sources user` and `--strict-mcp-config`: no Anthropic credential, user hook or MCP server, and none of the audited repo's `.claude` settings, hooks or `.mcp.json`, reach the run.
- Audited source goes to Z.ai. Running it on a repo is a confidentiality decision for that repo's owner.
- Review date: 2027-01-25. If the runner is still unused then, delete it and the vendored skill.
