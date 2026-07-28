---
status: accepted
date: 2026-07-28
supersedes: ADR-0004
tags: [harness, codex, kimi, pi, claude, skills, mcp]
affected_components: [pi/skills, scripts, tests, workflow/runtime, claude/commands, mcp, docs/mcp-strategy.md]
---

# Remove the Codex and Kimi Code harnesses and recenter on Pi and Claude

Etabli removes the Codex harness surface (codex/, scripts/deploy-codex, scripts/audit-codex-organization, tests/codex-organization-smoke.sh, docs/codex-organization.md, docs/codex-app-subagents.md) and the Kimi Code surface (kimi-code/, scripts/deploy-kimi-code), recentering the tracked harness fleet on Pi and Claude.

The 31 unique Codex skills migrate to pi/skills/: the three linear-* forks were near byte-identical to the canonical pi adapters, and codex-dynamic-workflows was harness-specific orchestration with no Pi equivalent. Pi keeps its openai-codex/* council models and the kimi-coding/k3 fallback, which are model providers, not harness surfaces. The shared ~/.agents link surface is retained for Grok and future harnesses, now sourced exclusively from pi/skills/ through the renamed skill-surface.tsv column agents_visible.

MCP configuration consolidates on Claude user scope as the single live definition store, with Pi importing the set through its native claude-code import; mcp/servers.template.json and docs/mcp-strategy.md make the inventory and hygiene rules explicit without committing secrets.

This supersedes ADR-0004's sanitized tracked Codex organization surface: maintaining per-harness trees, deploy scripts, CI core smokes, and string-pinned documentation for harnesses with no live local install cost more than the optionality it preserved. Historical docs/plan archives, dated audits, and the dormant telemetry recovery tooling remain as provenance, not active surface.
