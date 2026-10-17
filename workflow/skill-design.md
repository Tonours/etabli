# Skill Design Contract

Rules for writing skills, commands, and agent instructions in this repo.
Sources: AI Engineer 2026 talks "Building Great Agent Skills" and "Build
Systems, Not Code", plus the map-not-manual golden principle.

## Rules

- Separate steps from reference: the skill body is the procedure; support
  material (templates, examples, edge-case tables) lives in pointed files
  loaded only when needed.
- One skill per step when steps must not leak: hiding future steps forces
  full effort on the current one (ask-questions and write-plan are separate
  concerns, not one prompt).
- Decide invocation explicitly: model-invoked costs permanent context and
  adds unpredictability; user-invoked shifts the cost to the human. Side
  effects default to user-invoked.
- Use leading words: dense, consistent terminology reused verbatim across
  the skill; check adoption by looking for the terms in the agent's output.
- Delete-test before shipping: remove a paragraph — if behavior would not
  change, the paragraph does not ship. A growing instruction file is a code
  smell; decompose by responsibility.
- Self-healing errors: every mechanical check (hook, lint, smoke assertion)
  fails with a message that names the remediation, not only the violation.
- Structured contracts at machine-to-machine boundaries: when one step's
  output feeds another agent or script, define the shape; no freeform prose
  between machines.

## Frontmatter and layout

Sources: Anthropic "Skill authoring best practices"
(platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices),
Claude Code skills docs (code.claude.com/docs/en/skills), Agent Skills spec
(agentskills.io/specification).

- `name`: lowercase letters, digits and hyphens, at most 64 characters, equal
  to the directory name.
- `description`: third person, what the skill does, then `Use when …`; add
  `Not for …` when a sibling skill competes. One line, at most 1024
  characters, key use case first (Claude truncates the listing). Every catalog
  character is paid each session: `scripts/pi-skill-load-check` and
  `scripts/claude-skill-load-check` gate the total.
- Body under 500 lines; reference files one level deep from `SKILL.md`;
  forward slashes; MCP tools by full name.
- Instructions in English. A skill whose output is another language keeps its
  target-language samples quoted.
- No time-sensitive wording ("until March, use the old API"); history belongs in ADRs.
