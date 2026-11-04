# extras

You can keep a skill here tracked in git without deploying it to any harness,
as `coolify` and `react-doctor-100` are today (`GLOSSARY.md` § Shelf,
ADR-0027). Their rows in
`workflow/runtime/skill-surface.tsv` use source `extras` with `pi_core=0`, and
the deploy reads only `etabli` and vendor rows, so they never reach a harness.
`skills-lock.json` still locks them.

- Use one: read `extras/skills/<name>/SKILL.md` directly.
- Promote one: `git mv extras/skills/<name> skills/<scope>/<name>`, rename its
  catalog row to `<scope>/<name>` with source `etabli` and the flags you want,
  give it a state in `claude/settings.skill-overrides.json` (the deploy's skill
  load check fails on an ungoverned skill), regenerate `skills-lock.json`, then
  run `scripts/deploy-agent-workflow --apply`.
