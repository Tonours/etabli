# Skills and MCP Consolidation Research

Research backing the 2026-07-28 harness recenter: skills consolidated under
`pi/skills/`, MCP consolidated on Claude user scope + Pi import.

Access date: 2026-07-28.

## Confidence legend

| Label | Meaning |
| --- | --- |
| confirmed | Verified against a cited source or a local command in this session |
| approximate | True on the inspected surface; generalization limited |
| proxy-supported | Indirect evidence (doc plus local proxy behavior) |

## Questions

1. What structure should consolidated skills follow so one tree serves Pi,
   Claude, and `~/.agents` consumers without per-harness forks?
2. Where should MCP server definitions live so Pi and Claude share them
   without duplication or committed secrets?

## Findings — skills

1. **Agent Skills are an open, harness-neutral standard** — confirmed.
   A skill is a folder with a `SKILL.md` (YAML frontmatter `name` +
   `description`, then Markdown instructions) and optional `references/`,
   `scripts/`, `assets/`. Sources: https://agentskills.io/specification,
   https://github.com/agentskills/agentskills.
   Local consequence: the former `codex/skills/` packs were already
   standard-shaped; migration to `pi/skills/` needed no format change, only
   removal of harness metadata (`agents/openai.yaml`) and scrub of
   harness-specific prose.

2. **Progressive disclosure is the designed distribution model** — confirmed.
   Agents load name+description at startup (~100 tokens), the SKILL.md body on
   activation, and resources only when required. Source:
   https://agentskills.io/specification.
   Local consequence: keeping 27 domain packs in `pi/skills/` with
   `pi_core=0, agents_visible=0` in `workflow/runtime/skill-surface.tsv`
   costs nothing at startup for Pi core installs, while staying one symlink
   flip away from activation. This matches the catalog/opt-in design instead
   of a separate stockpile tree.

3. **One adapter per harness over shared contracts beats forked skills** —
   confirmed locally. The three `linear-*` pairs in `pi/` vs `codex/` differed
   only in source-resolution fallback paths (session recon 2026-07-28,
   `diff` of the two trees). The surviving pi copies are the canonical
   adapters over `workflow/skills/linear-*.md`; the codex forks were dropped.

4. **Skills complement MCP; they do not replace it** — confirmed.
   MCP servers provide live tool/data/auth access; skills provide the
   procedural expertise for using them. Source:
   https://github.com/agentskills/agentskills.
   Local consequence: the Linear skills stay skill-side while the missing
   Linear server is an MCP configuration gap (see below), not a skill bug.

## Findings — MCP

5. **Claude Code MCP scopes make user scope the natural shared store** —
   confirmed. Claude reads user scope (`~/.claude.json`) plus project scope
   (`.mcp.json`); `${VAR}` placeholders keep secrets out of tracked files.
   Sources: https://code.claude.com/docs/en/mcp (scope docs), local
   inspection of `~/.claude.json` (7 global servers, one already using a
   `${UIDOTSH_TOKEN}` placeholder).
   Drift observed locally: `chrome-devtools` and `context7` duplicated across
   several project scopes with argument/transport drift — motivating rule 4 in
   `docs/mcp-strategy.md`.

6. **Pi can import the Claude server set natively** — confirmed locally.
   `~/.pi/agent/mcp.json` is `{ "mcpServers": {}, "imports": ["claude-code"] }`,
   and Pi's runtime cache shows the imported servers. Zero-duplication
   consolidation therefore needs no sync tool.

7. **Generic multi-harness MCP sync tools are not justified here** —
   approximate. Tools such as agentsync or mcpx target fleets of harnesses
   with divergent config formats. With two harnesses and a working native
   import, an extra sync layer adds failure modes without removing any manual
   step (judgment call, 2026-07-28; re-evaluate if a third harness returns).

8. **Linear MCP is the only skill-required server missing** — confirmed.
   `workflow/skills/linear-*.md` expect Linear MCP and degrade to
   `LINEAR_MCP_UNAVAILABLE`; no inspected config defines a `linear` server
   (session recon 2026-07-28). The official endpoint is the streamable-HTTP
   server `https://mcp.linear.app/mcp` with host-side OAuth. Source:
   https://github.com/anthropics/skills (managed-agents-tools.md, Linear
   `mcp_servers` example).

## Decision summary

- Skills: single tree `pi/skills/`; catalog opt-in via
  `workflow/runtime/skill-surface.tsv`; harness surfaces are symlinks, not
  copies. Confidence: confirmed by `scripts/verify-agentic-infra core` exit 0
  on 2026-07-28.
- MCP: template-tracked inventory (`mcp/servers.template.json`), Claude user
  scope as live store, Pi native import, project scope for project servers.
  Confidence: confirmed for the mechanism, approximate for long-term drift
  control (depends on rule adherence).

## Sources

- https://agentskills.io/specification — Agent Skills format and progressive
  disclosure (accessed 2026-07-28).
- https://github.com/agentskills/agentskills — standard overview, skills/MCP
  complementarity (accessed 2026-07-28).
- https://github.com/anthropics/skills — Anthropic skills repo; Linear MCP
  endpoint example in managed-agents-tools.md (accessed 2026-07-28).
- Local evidence: `~/.claude.json` (user-scope server set, placeholder
  precedent), `~/.pi/agent/mcp.json` (claude-code import),
  `workflow/runtime/skill-surface.tsv`, `docs/mcp-strategy.md`.
