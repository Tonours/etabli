# Implemented: Kimi Code uses caveman, rtk, and the Etabli skill set

## Metadata
- Archived: 2026-07-24
- Source plan: Make Kimi Code use caveman, rtk, and our skills (request)
- Status: IMPLEMENTED
- Commit / branch: `main` (uncommitted local change in the etabli repo)
- Scope: no root PLAN.md (small scoped change, YAGNI); evidence chain recorded here.

## Outcome
- Kimi Code now loads 13 skills via its existing `merge_all_available_skills = true`
  mechanism in `~/.kimi-code/config.toml` — no config edit required.
- Deployed into `~/.kimi-code/skills/`:
  - Etabli skills mirrored from `pi/skills`: `caveman`, `adversary`, `bug-check`,
    `ci-fix`, `github-pr-review`, `grill-me`, `linear-ticket-create`,
    `linear-work`, `pr-qa`, `pr-review`, `sec-pr`, `verify`.
  - kimi-code-specific `rtk` skill (no pi skill equivalent).
- Added a reproducible deploy script `scripts/deploy-kimi-code` and a versioned
  source surface `kimi-code/` (README + `skills/rtk/SKILL.md`).
- Pre-existing kimi-code-adapted skills (`plan-loop`, `implement`, `review`,
  `code-review`, `plan-implement`) were never overwritten.

## Context
- `~/.kimi-code/config.toml` sets `merge_all_available_skills = true`; the only
  behavior surface in Kimi Code is the auto-merged `~/.kimi-code/skills/` folder
  (verified: no global AGENTS.md / instructions file).
- Kimi Code has no extension/hook system, so pi's always-on `rtk` extension has
  no native equivalent; an opt-in skill is the best achievable.

## Decisions
### Copy rather than symlink the Etabli skills
- Choice: real-file copies, sourced from `pi/skills`.
- Rejected: symlinks into the etabli repo (would couple Kimi Code to a repo path
  that may not exist on another machine; existing Kimi Code skills are already
  copies, not links).
- Consequences: drift is possible if a pi skill is updated without re-deploying;
  mitigated by the idempotent re-deploy command documented in
  `kimi-code/README.md`.

### rtk as an opt-in skill, documented as a trade-off
- Choice: `skills/rtk/SKILL.md` teaches the model to prefix commands with `rtk`.
- Rejected: pretending to be always-on (no hook exists); doing nothing.
- Consequences: token savings depend on the model invoking the skill; the skill
  description is written to trigger on noise/compact/save-token intent.

### Strict whitelist, non-destructive deploy
- Choice: the script only ever writes its fixed whitelist; it never deletes.
- Rejected: mirror-and-prune sync (would destroy user-authored Kimi Code skills).
- Consequences: a removed source skill leaves a stale copy; accepted as a
  safety invariant, same philosophy as `scripts/deploy-codex`.

## Accepted Drift
- A latent nesting bug in `deploy-kimi-code` (`mkdir -p "$dst"` before `cp -R`)
  would have created `$skill/$skill/SKILL.md` on a fresh machine. The real
  deployment was performed manually, so production was unaffected; the bug was
  caught in code review and fixed before this archive.
- Near-duplicate skill names now coexist (`ci-fix` vs `fix-ci`, `verify` vs
  `verify-this`, `pr-review` vs `pr-review-canvas`). Accepted: descriptions
  disambiguate and the skills are genuinely different.

## Validation Evidence
- 13/13 skills present with valid YAML frontmatter (`name` + `description`);
  line counts: caveman 70, adversary 37, bug-check 25, ci-fix 26,
  github-pr-review 12, grill-me 17, linear-ticket-create 28, linear-work 25,
  pr-qa 25, pr-review 25, sec-pr 25, verify 78, rtk 116.
- `merge_all_available_skills = true` present (`~/.kimi-code/config.toml:3`).
- Pre-existing skills intact: `plan-loop`, `implement`, `review`, `code-review`,
  `plan-implement`.
- Fresh-deploy smoke (clean temp `$KIMI_CODE_HOME`): 13 copied, flat structure
  (`$skill/SKILL.md`, no nesting), content `diff -q` identical to source.
- Idempotent re-deploy on the real home: `copied=0 skipped=13 backed_up=0
  warnings=0`.
- Safety tests: non-whitelisted skill preserved; whitelisted skill that diverged
  is skipped without `--force` and backed-up-and-replaced with `--force`.
- Missing-source now exits non-zero (drift visible to automation); all-present
  exits 0.
- `bash -n scripts/deploy-kimi-code` clean; executable bit set.
- rtk skill command list cross-checked against `rtk --help`; path claim
  `~/.local/bin/rtk` verified (v0.39.0).
- Tool-native validation: `kimi doctor` reports `config.toml` and `tui.toml`
  valid; a non-interactive `kimi -p` prompt confirmed Kimi Code recognizes the
  deployed skills (`caveman, rtk, adversary, verify, sec-pr`) — end-to-end proof
  that the skills are loaded, not merely present on disk.

## Follow-up State
- Remaining risks: copied Etabli skills can drift from `pi/skills` until
  re-deployed; rtk benefit depends on model invocation; a stale whitelisted
  skill is not auto-pruned.
- Parking lot: re-run `scripts/deploy-kimi-code --apply` after Etabli skill
  edits; revisit rtk integration if Kimi Code ships a hook system; consider
  pruning policy if skill churn grows.
- Next links: `kimi-code/README.md`, `scripts/deploy-kimi-code`,
  `pi/skills/`, `~/.kimi-code/config.toml`.
