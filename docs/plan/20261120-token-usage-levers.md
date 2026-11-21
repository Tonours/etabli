# Token-usage levers rollout

## Metadata

- Recorded: 2026-11-21
- Source plan: `PLAN.md`
- Source plan SHA-256: `db69a6347e8752ada16d9067010aeca961f35dcdd79ba5d84c201f470c5dd305`
- Status: BLOCKED
- Workflow initiative: token-usage-levers
- Approved rollout commit: `1702e95011ea69cfc53518f03f44fb5c6fa01aa2`

## Outcome

- [#126](https://github.com/Tonours/etabli/pull/126) added the usage audit. [#129](https://github.com/Tonours/etabli/pull/129) added version-gated token settings and drift detection. [#130](https://github.com/Tonours/etabli/pull/130) added the RTK hook check.
- The gromarchy checkout reached the approved commit and the settings writer applied the tracked values. The live skill-load check blocked the rollout. The Mac hosts were held at the host-order gate. AC-10 remains open.

## Host ledger

| Target | Control path | Pre-state | Post-check | Rollback |
| --- | --- | --- | --- | --- |
| gromarchy | Local shell, live Etabli checkout | Main was eligible for fast-forward. Local edits and untracked files saved under `~/.local/state/etabli/`. RTK hook absent. | Checkout at approved SHA. RTK hook shown and verify passed. Tracked keys match before and after restoration. Live checks reported 1 issue before restoration and 2 after. Restored paths, file hashes, modes and upstream-overlapping hunks verified. Live `general-purpose` model proof pending. | Restore `settings.json.bak.<stamp>` or remove the managed values with jq. RTK hook rollback uses the pre-init settings backup. Named patches and stash retained. |
| macmini | SSH, Etabli checkout | Prior-history main and local changes from pre-rollout recon. | Held at the host-order gate. | No rollout changes. After a future apply, restore `settings.json.bak.<stamp>` or remove the managed values with jq. |
| macbook-work | SSH, Etabli checkout | Existing local setup. | Held at the host-order gate. | No rollout changes. After a future apply, restore `settings.json.bak.<stamp>` or remove the managed values with jq. |

## Validation evidence

- The gromarchy runtime inventory passed the `2.1.251` activation floor. The default CLI and observed live SDK runtime were both `2.1.330`.
- The jq read-back matched `env.CLAUDE_CODE_SUBAGENT_MODEL`, `env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`, both tracked `modelSettings.*.effortLevel` entries, `autoCompactWindow`, `bashOutputMaxChars` and `skillListingMaxDescChars`.
- Before restoration, `--apply` and `--check` failed because the `herdr` keeper was pinned on and its local frontmatter disabled model invocation. After restoration, the local `skillOverrides` edit in `claude/settings.skill-overrides.json` caused the repo/live maps to diverge and triggered tracked settings drift.
- Checkout restoration used the named stash SHA. The proof compared staged and unstaged path sets, untracked hashes, worktree and index hashes for unchanged-upstream paths, and staged and unstaged added and removed lines for the upstream-overlapping path.

## Decisions and follow-up

- Keep `bashOutputMaxChars` at `15000`. Run the private 30-day histogram check after gromarchy passes deployment validation.
- Resolve the gromarchy keeper and fragment drift with the owner edits preserved. Require green live checks and the Sonnet subagent proof there before moving to macmini and then macbook-work.
- Removing a key from the tracked fragment leaves its deployed local value. Use the settings backup or remove that local value explicitly when rolling back.
