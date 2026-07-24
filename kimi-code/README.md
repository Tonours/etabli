# Kimi Code Organization

Tracked Kimi Code operating surface for this machine.

## Contents

- `skills/` - Kimi Code skills, deployed into `~/.kimi-code/skills/`.
  - `skills/rtk/` - token-optimized shell output via the `rtk` proxy. kimi-code
    has no extension/hook system (unlike pi's `rtk.ts`), so this is an opt-in
    skill that teaches the model to prefix commands with `rtk`.

## Skills model

Kimi Code auto-merges every directory under `~/.kimi-code/skills/` when
`merge_all_available_skills = true` (see `~/.kimi-code/config.toml`). There is no
explicit registration list — folder presence is sufficient.

The Etabli skills shared with pi (`caveman`, `adversary`, `bug-check`, `ci-fix`,
`github-pr-review`, `grill-me`, `linear-ticket-create`, `linear-work`, `pr-qa`,
`pr-review`, `sec-pr`, `verify`) are **not** duplicated here. Their canonical
source is `../pi/skills/`; the deploy script mirrors them directly so there is a
single source of truth.

Only kimi-code-specific skills that have no pi equivalent live in this
directory (currently `rtk`).

## Deploy

```bash
# preview
../scripts/deploy-kimi-code --dry-run

# deploy the whitelisted skills into ~/.kimi-code/skills
../scripts/deploy-kimi-code --apply

# replace a whitelisted skill that diverged from source (backs up the target)
../scripts/deploy-kimi-code --apply --force
```

The script only ever writes its fixed whitelist. Other skills already present in
`~/.kimi-code/skills/` (including kimi-code-adapted copies of `plan-loop`,
`implement`, `review`, `code-review`) are never touched or deleted.
