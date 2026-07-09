# MengTo Skills Adoption Notes

Source: https://github.com/MengTo/Skills

## Snapshot

- Date inspected: 2026-07-08
- Repository description: Clawdbot AgentSkills for web design and prompting.
- License: MIT.
- GitHub API tree count at inspection time: 73 tracked `SKILL.md` files.
- README count at inspection time: 75 skills.
- Import mode: local skills are rewritten adaptations; the upstream library is
  not vendored wholesale.
- Decision: use the repository as a reference library and adopt only narrow
  operational workflows that fit Etabli's skill design contract.

## Local Fit Criteria

Accepted skills must:

- be procedural, not encyclopedic;
- have an explicit trigger;
- separate workflow from optional references or helper scripts;
- avoid account-specific assumptions;
- preserve local repo instructions and validation gates;
- expose a real check or inspection surface.

Rejected or deferred skills include:

- broad aesthetic style lanes that would bias unrelated product UI work;
- source-specific capture workflows tied to one content workspace;
- external account workflows without a local validation path;
- large imported bundles that increase skill routing noise.

## Adopted

### Browser Full Page Capture

- Upstream references:
  - `agent-skills/codex/stitched-full-page-capture/SKILL.md`
  - `agent-skills/codex/html-to-interaction-prompts/SKILL.md`
- Local path: `codex/skills/browser-full-page-capture/`
- Why adopted: Etabli already relies on browser evidence and product dogfood
  checks; native full-page screenshots can be unreliable on lazy-loaded,
  reveal-heavy, or WebGL pages.
- Local adaptation: a generic helper script captures settled viewport slices
  and stitches them with `ffmpeg`. It uses project-provided Playwright and does
  not install dependencies.

### Frontend Motion Performance

- Upstream reference: `agent-skills/codex/optimize-web-animations/SKILL.md`
- Local path: `codex/skills/frontend-motion-performance/`
- Why adopted: it gives a concrete workflow for animation profiling, offscreen
  pause behavior, RAF/canvas cleanup, and leak-oriented browser evidence.
- Local adaptation: keep it stack-agnostic and route through existing repo
  validation instead of prescribing one app framework.

### UI Reference Capture

- Upstream references:
  - `agent-skills/codex/video-to-superprompt/SKILL.md`
  - `agent-skills/codex/html-to-interaction-prompts/SKILL.md`
  - `agent-skills/ui/design-first-ui-prompting/SKILL.md`
- Local path: `codex/skills/ui-reference-capture/`
- Why adopted: it turns reference videos, HTML, and live pages into reusable
  prompt packs with screenshots, motion notes, accessibility constraints, and
  implementation boundaries.
- Local adaptation: output stays evidence-backed and project-neutral; it does
  not assume a dated article workspace.

## Rejected For Default Runtime Surface

### Web Design Style Lanes

Examples include glass, beige, dark-blue, green-tech, lasers, paper, and other
single-lane visual styles.

- Reason: useful as inspiration but too opinionated for model-invoked default
  skills.
- Future path: keep as reference material for a specific design brief, not as
  ambient routing surface.

### Landing Page And Pricing Page

- Reason: useful only when the task is explicitly marketing/conversion work.
  Etabli product UI work should not default to landing-page structure.
- Future path: add a user-invoked marketing-page skill only if repeated work
  proves it is needed.

### Daily UI Inspiration Capture

- Reason: the upstream workflow is tied to a dated article format and project
  conventions that are not currently part of Etabli.
- Future path: reuse pieces through `ui-reference-capture` when a real content
  workflow exists.

## Validation Surface

This adoption is pinned by:

- `bash tests/codex-organization-smoke.sh`
- `bash tests/deploy-agent-workflow-smoke.sh`
- `bash tests/fix-links-smoke.sh`
- `bun test pi/extensions/__tests__/`
- `node --check codex/skills/browser-full-page-capture/scripts/stitch-full-page-capture.mjs`

The new skills are intentionally Codex-visible through the maintained
`CODEX_VISIBLE_CODEX_SKILLS` arrays, not Pi core skills.
