# extras

Shelf for skills that are tracked in git but never deployed (see
`CONTEXT.md` § Étagère and ADR-0027). Rows in
`workflow/runtime/skill-surface.tsv` use source `extras` with
`pi_core=0` and `agents_visible=0`.

- Use one: read `extras/skills/<name>/SKILL.md` directly.
- Promote one: `git mv extras/skills/<name> pi/skills/<name>`, set its catalog
  row back to source `pi` with the wanted flags, then regenerate
  `skills-lock.json` and run `scripts/deploy-agent-workflow --apply`.
