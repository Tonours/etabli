# skills-archive

Dormant skill suites relocated out of the autoload scan path (`pi/skills/`).

## Why these are archived

The `tanstack-*` and `adonisjs-*` suites are authored, framework-specific
playbooks (Proprietary, author: Moka). They are **not** wired into the active
agent surface:

- not listed in `pi/agent/settings.json` (`local:etabli-workflow` package),
- `pi_core=0`, `agents_visible=0`, `locked=0` in `skill-surface.tsv`,
- not referenced by the workflow router as a loadable skill.

Keeping 188 KB / 57 files of dormant markdown under `pi/skills/` inflated the
adapter footprint counted by `scripts/workflow-efficiency-report`
(`find pi/skills -type f -name '*.md'`) and cluttered the skill catalog with
zero-per-turn entries. They were moved here — not deleted — so the author's work
is preserved and recoverable.

## Internal cross-references

The suites link to each other with relative paths (`../adonisjs-backend/...`).
They were relocated together, so those links stay valid within this directory.

## Restoring a skill

To re-activate a skill, move its directory back into `pi/skills/` and re-add a
`pi_core`/`agents_visible`/`locked` row to
`workflow/runtime/skill-surface.tsv` (and list it in `settings.json` if it must
be loaded by the agent). Run `pi/scripts/verify-skills-lock.mjs` afterwards.
