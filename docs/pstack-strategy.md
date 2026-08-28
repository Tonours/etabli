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

## Deployment surfaces

Catalog rows (`workflow/runtime/skill-surface.tsv`): `source=pstack`,
`0 0 1`. The install vendor loop links each skill into
`~/.pi/agent/skills`, `~/.claude/skills`, and `~/.codex/skills` whenever the
`shared` scope is active (always). `agents_visible=0` on purpose: Grok and
Cursor already run pstack natively; etabli does not duplicate it there.

## Degradation on Pi (accepted)

- Subagent fan-out instructions (how/why/interrogate spawn explorers,
  investigators, reviewers) degrade to single-model sequential passes.
- Model-role references (sol/grok/fable/opus defaults) are inert; the current
  model does the work.
- `disable-model-invocation: true` frontmatter is a Cursor/Claude flag; if the
  runtime ignores it, skills may self-trigger — acceptable for wave 1.
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

## Wave 2 menu (not vendored; requires a follow-up ADR if adopted)

- 21 `principle-*` skills — catalog-noisy as standalone Pi skills; candidates
  for shelf rows (`0 0 0`) or a single indexed skill.
- 22 playbooks + `poteto-mode` — sticky router competes with ambient contract
  activation; revisit only if task-skill coverage proves insufficient.
- `arena` / `swarm` / `recall` / `setup-pstack` / `no-comments` /
  `make-bot-ui` — Cursor-coupled (fan-out, transcripts, plugin config,
  subagents).

Wave-2 adoption is a `vendor/sources.tsv` row extension plus catalog-flag
flip, nothing more.
