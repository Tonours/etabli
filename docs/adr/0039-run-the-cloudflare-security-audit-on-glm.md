---
status: accepted
date: 2026-10-25
tags: [tooling, security, vendor, claude, glm]
affected_components: [vendor/sources.tsv, vendor/cloudflare, scripts/security-audit-glm, scripts/security-audit-sandbox, scripts/lib/surfaces.mjs, workflow/runtime/skill-surface.tsv, claude/settings.skill-overrides.json]
---

# Run the Cloudflare security audit on GLM

Cloudflare's `security-audit` skill (`cloudflare/security-audit-skill`, MIT) is vendored under `vendor/cloudflare` in the `shared` scope, `user-invocable-only` on Claude and off Pi's core set. `scripts/security-audit-glm`, linked as `~/.local/bin/security-audit-glm`, runs it in Claude Code against the Z.ai Anthropic endpoint (`ZAI_API_KEY`) so the session, its auto-mode classifier and every subagent run on one GLM model, `glm-5.3[1m]` at effort `max` by default.

The harness is Claude Code, not Pi, because the skill needs fresh, isolated verifier agents and Pi's subagent capability is still `unknown` (`workflow/skills/orchestration.md`). A 2026-10-25 probe through the endpoint showed a GLM session spawning a GLM subagent through the `Agent` tool, `--effort max` raising GLM reasoning output about tenfold over `low`, and `auto` mode running a shell command.

`glm-5.3` is the default over `glm-5.3-flash`: Z.ai publishes cyber results only for GLM-5.3 (CyberGym 84.5, ExploitBench 54.4), and Flash scores lower on DeepSWE (63.4 against 66.9). GLM takes `low`, `high` and `max`; there is no `xhigh`.

## Consequences

- The runner uses its own `CLAUDE_CONFIG_DIR` (`~/.local/state/security-audit-glm`), `--setting-sources user` and `--strict-mcp-config`: no Anthropic credential, user hook or MCP server, and none of the audited repo's `.claude` settings, hooks or `.mcp.json`, reach the run.
- Target code runs only through `scripts/security-audit-sandbox`, a Docker Desktop container that meets the skill's "Universal execution safety" controls: no network but an isolated loopback, `env -i` with a fixed allowlist, read-only rootfs, toolchain and target, writes only to a size-capped in-memory copy of the agent scratch, and CPU, memory, pids, file-size, output and wall-clock limits. Docker won over Apple `container` (absent, and macbook-work runs macOS 14) and `sandbox-exec` (no memory, pids or disk limits). The launcher checks it before each run; without Docker Desktop and the `etabli/security-audit-sandbox:1` image (`security-audit-sandbox --build`) the audit stays source-only. Results leave only as capped stdout and stderr, so the promotion allowlist is empty. Residuals: target code can read every file of the target, including an ignored `.env`, which the agents can already read as source; GLM agents can still run target code on the host with their own shell tool, which only the prompt and the skill forbid.
- Tool search is off (`ENABLE_TOOL_SEARCH=false`): on 2026-10-26 a GLM subagent looked for the already-loaded `SubagentHandback` through ToolSearch 1038 times in an hour and stalled the run. Headless runs wait up to an hour for background agents.
- Audited source goes to Z.ai. Running it on a repo is a confidentiality decision for that repo's owner.
- Review date: 2027-01-25. If the runner is still unused then, delete it and the vendored skill.
