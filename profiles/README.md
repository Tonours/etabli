# Profiles

Profiles make the repo's real usage explicit.

Current profiles:
- `profiles/personal/`
- `profiles/work/`

User-facing guide:
- `docs/profiles.md`

## Purpose

Profiles describe expected differences in:
- default runtime
- providers and models
- allowed commands and tools
- autonomy level
- extensions and integrations
- safety posture
- documentation emphasis

## Non-goals in this slice

- No automatic profile loader
- No per-profile settings engine
- No duplicated workflow contract per profile

The workflow contract stays shared:
- `workflow/spec.md`
- `workflow/statuses.md`
- `workflow/review-rubric.md`
- `workflow/handoff-template.md`

Profiles are documentation contracts first. They must state the intended runtime posture and the provider/model posture, even when enforcement is still manual. Runtime enforcement can be added later only if the docs-first version proves insufficient.
