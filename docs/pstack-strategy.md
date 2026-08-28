# pstack vendoring strategy

How etabli consumes [pstack](https://github.com/cursor/plugins/tree/main/pstack)
(Lauren Tan's engineering skill set) without replacing its own workflow
contract. Decision record: `docs/adr/0020-*.md`.

## What is vendored

Eight runtime-agnostic task skills, synced verbatim from
`cursor/plugins` @ `main` (`vendor/sources.tsv`, subpath `pstack`):

| Skill | Use | Notes |
| --- | --- | --- |
| `how` | "how does X work" walkthroughs, ownership/layering questions | partial overlap with `workflow/skills/investigation.md` route — skill is invocable, route stays canonical |
| `why` | design rationale from git history + MCP evidence categories | categories depend on configured MCPs; empty categories reported honestly |
| `architect` | caller-first design sketch before code | complements `/plan-loop` (contract planning) |
| `blast-radius` | what else a small change could break, proven by running code | |
| `tdd` | failing test first when a cheap local test path exists | |
| `interrogate` | multi-model adversarial diff review, 4-bucket verdicts incl. dismissed | opt-in task skill; does not change `/review` route wiring (ADR-0013 stands for routes) |
| `create-verification-skill` | generate a project-local verify skill + feature map | aligns with evidence-pack ethos |
| `maintain-verification-skill` | keep that verify skill honest against source drift | |

License: `vendor/pstack/LICENSE` (MIT, Copyright Lauren Tan), copied from the
`pstack/` subpath — the monorepo root ships none.

## Wave 2 (deployed 2026-08-28, ADR-0021)

`poteto-mode` — the router skill with its 22 playbooks inline
(`poteto-mode/playbooks/`) — plus the 21 `principle-*` skills. On etabli it
is **opt-in**: type `/poteto-mode` to enter the mode; the ambient workflow
contract stays canonical for ordinary prompts. `poteto-mode` declares
`name: Poteto Mode`, so the installer links it by its directory basename via
the slug-validation fallback in `skill-catalog.sh`
(`tests/skill-catalog-name-smoke.sh`).

Principles are named, invocable one-rule skills (`principle-laziness-protocol`,
`principle-prove-it-works`, …); poteto-mode reads them by name and requires a
citation to trace to a real decision.

## Deployment surfaces

Catalog rows (`workflow/runtime/skill-surface.tsv`): `source=pstack`,
`0 0 1`. The install vendor loop links each skill into
`~/.pi/agent/skills`, `~/.claude/skills`, and `~/.codex/skills` whenever the
`shared` scope is active (always). `agents_visible=0` on purpose: Grok and
Cursor already run pstack natively; etabli does not duplicate it there.

## Degradation on Pi (accepted)

- Subagent fan-out instructions (how/why/interrogate/poteto-mode delegates,
  explorers, investigators, reviewers) degrade to single-model sequential
  passes; the `poteto-agent` subagent definition (`pstack/agents/`) is not
  vendored by the skills-only sync.
- Model-role references (sol/grok/fable/opus defaults, `Task` model tiers,
  `/setup-pstack` overrides) are inert; the current model does the work.
- `disable-model-invocation: true` is a Cursor/Claude flag; if the runtime
  ignores it, skills may self-trigger — acceptable while wanted.
- poteto-mode's `reminder:` frontmatter is an always-on nudge on Cursor and
  an unknown field elsewhere — residual self-trigger vector, documented in
  ADR-0021.
- Not-vendored references inside poteto-mode (degrade to nearest local
  behavior): `arena`, `swarm`, `recall`, `unslop`, `no-comments`,
  `technical-writing`, `figure-it-out`, `reflect`, `automate-me`,
  `make-bot-ui`, `teach`, `typescript-best-practices`, `show-me-your-work`,
  `bro`; Cursor built-ins `create-skill`, `/loop`, `AskQuestion`;
  cursor-team-kit `deslop`, `control-cli`, `control-ui`; Graphite for the
  shipping playbooks.
- `create-verification-skill` / `maintain-verification-skill` hardcode
  `.cursor/skills/verify-<app>/` as the output location
  (`create-verification-skill/SKILL.md:9,25,36`). On Pi, Claude, and Codex
  that path is not a discovered skill surface — relocate the generated
  `verify-<app>` folder to the runtime's project-local skills dir when the
  skill is used there.
- Vendored files are never edited; adaptation lives in this document.

## Updating

1. `scripts/sync-vendor-skills pstack` (fails closed if a skill dir moves
   upstream; refuses a dirty `vendor/` tree).
2. Review the diff, then commit `vendor/pstack/**` including the new
   `UPSTREAM_SHA`.

## Wave 3 menu (not vendored; requires a follow-up ADR if adopted)

- The remaining 14 skills: `arena` / `swarm` (fan-out; conflicts with the
  parent-only Pi profile), `recall` (Cursor transcripts), `setup-pstack`
  (plugin config), `no-comments` (Comment Sicko subagent), `make-bot-ui`
  (Grok Bot webhook), `unslop` / `technical-writing` (overlap deslop +
  answer-quality), `figure-it-out`, `reflect`, `automate-me`, `teach`, `bro`,
  `typescript-best-practices`, `show-me-your-work`.

Adoption remains a `vendor/sources.tsv` row extension plus catalog-flag
flip, nothing more.
