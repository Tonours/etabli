# Docs inventory baseline (2026-07-29)

> Working inventory from the English-docs goal. Not an operational guide.
> Canonical maps: `README.md`, `docs/workflow-guide.md`, `workflow/spec.md`.

Classification for the English docs / workflow-guide goal. Protected classes
remain provenance unless a script requires present-tense accuracy.

## Live / keep (operational)

| Path | Action |
|------|--------|
| `docs/mcp-strategy.md` | keep (smoke + Linear) |
| `docs/pi-cheatsheet.md` | keep (smoke) |
| `docs/agentic-workflow-hardening.md` | keep (smoke); dated research still useful |
| `docs/source-grounded-answer-quality-research.md` | keep (smoke) |
| `docs/cross-project-research-grounding.md` | keep (smoke); portable paths |
| `docs/answer-quality-eval-cases.md` | keep (smoke) |
| `docs/answer-quality-traces/**` | keep (smoke + fixtures) |
| `docs/plan/README.md` | keep archive notice |
| `docs/adr/**` | keep (immutable ADRs) |
| `docs/plan/**` | keep historical archives |
| `docs/nvim-minimal-*.md` | keep as dated snapshot banners |
| `docs/SECURITY` via root `SECURITY.md` | keep |

## Update / banner / delete

| Path | Decision |
|------|----------|
| `docs/handoff.md` | replace with English pointer |
| `docs/handoffs/*` | historical banner (FR ok under banner) |
| `docs/mengto-skills-analysis.md` | delete (references removed `codex/skills`) |
| `docs/etabli-vnext-goal-research.md` | historical banner |
| `docs/etabli-harness-audit-20260724.md` | historical banner |
| `docs/adversary-etabli-10-*.md` | historical banner |
| `docs/answer-quality-goal-completion-audit.md` | historical banner + fix live codex/AGENTS claim |
| `docs/skills-mcp-consolidation-research.md` | historical banner |
| `docs/workflow-guide.md` | **create** |

## Surfaces confirmed

- `nvim/lua/config/review` absent
- `codex/` tree absent
