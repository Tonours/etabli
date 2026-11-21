# Token-usage levers rollout

## Metadata

- Recorded: 2026-11-21
- Source plan: `PLAN.md`
- Source plan SHA-256: `23d34a152389ba72a0cb8cc80fd79c5cc9145aa0cd579ca3d16399967f4c275a`
- Status: DONE
- Workflow initiative: token-usage-levers
- Approved rollout commit: `1d702d0b54da6f83f9cfc079afd872a37a531423`

## Outcome

- [#126](https://github.com/Tonours/etabli/pull/126) added the usage audit. [#129](https://github.com/Tonours/etabli/pull/129) added version-gated token settings and drift detection. [#130](https://github.com/Tonours/etabli/pull/130) added the RTK hook check.
- [#132](https://github.com/Tonours/etabli/pull/132) fixed the `herdr` pin that blocked the first deployment. All three checkouts reached the approved SHA.
- Gromarchy and macmini passed deployment, restoration and the live Sonnet proof. Macbook-work passed them after its enabled plugin was listed in the machine-local plugin allowlist. AC-10 is met on all three hosts.

## Host ledger

| Target | Control path | Pre-state | Post-check | Rollback |
| --- | --- | --- | --- | --- |
| gromarchy | Local shell, live Etabli checkout | Main eligible for fast-forward. Owner edits saved. RTK hook installed after the first attempt. | Approved SHA. RTK show and verify passed. Deploy checks reported zero issues before and after restoration. Tracked keys matched both times. Restoration verified. Live `general-purpose` used `claude-sonnet-5-5`. | Restore `settings.json.bak.<stamp>` or remove the managed values with jq. Use the pre-init RTK backup to restore the prior hook state. Original named stash and patches retained. |
| macmini | SSH, Etabli checkout and explicit Claude configuration override | Old-history main with zero extra commits. Backup branch and edits saved before realignment. Login and noninteractive shells selected different Claude roots. | Approved SHA. RTK Homebrew init, show and verify passed against the live settings. Deploy checks reported zero issues before and after restoration. Live keys matched both times and restoration verified. Live `general-purpose` used `claude-sonnet-5-5`. The original default-directory deployment remains as a residual. Its settings were unchanged in the second attempt. | Restore the saved live settings or remove managed values with jq. The default directory can be rolled back from its own `settings.json.bak.<stamp>`. Preserve the pre-rewrite branch and saved patches. Restore the original RTK binary from the aside if needed. |
| macbook-work | SSH, Etabli checkout. Login shell verified the default Claude root. | Main eligible for fast-forward. Owner edits saved. RTK hook present. | Approved SHA. Tracked keys matched before and after verified restoration. The first checks hit a skill governance issue from an enabled plugin shipping skills. After the plugin was listed in the untracked `~/.config/etabli/machine-local-plugins.json`, the deploy check reported zero issues with the owner edits restored. Live `general-purpose`, run by the owner in an interactive session, used `claude-sonnet-5-5`. RTK and existing sessions untouched. | Restore `settings.json.bak.<stamp>` or remove managed values with jq. Restore the machine-local plugin list from its `.bak` copy. Named stash and patches retained. |

## Validation evidence

- The read-only Claude runtime inventory passed the `2.1.251` activation floor on all three hosts.
- The jq read-backs matched `env.CLAUDE_CODE_SUBAGENT_MODEL`, `env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`, both tracked `modelSettings.*.effortLevel` entries, `autoCompactWindow`, `bashOutputMaxChars` and `skillListingMaxDescChars`.
- Each restoration used its named stash SHA and compared staged, unstaged and untracked paths, file and index hashes, and changed-upstream diff lines. Gromarchy's two local `herdr` edits exactly matched the approved tree, so they left no diff. The saved macmini file modes were restored after their content matched.
- The macmini live settings were backed up before using `CLAUDE_CONFIG_DIR` for deploy and `RTK_CLAUDE_DIR` for RTK 0.42.3. The default settings fingerprint and metadata matched the recorded pre-state. The live probe model was read from the subagent metadata.
- Macbook-work first reported one live issue before and after restoration: the skill-load check rejects an enabled plugin whose skills fall outside the tracked policy. The documented machine-local plugin allowlist resolved it without a repo change, and its subagent proof was read from the owner's interactive run, since a noninteractive SSH session cannot reach the login keychain.

## Decisions and follow-up

- Keep `bashOutputMaxChars` at `15000`. The private gromarchy histogram showed that the next lower measured boundary would truncate a materially wider share of calls.
- A noninteractive SSH session on a Mac cannot reach the Claude login in the keychain. A live proof on a Mac runs in an interactive session.
- Removing a key from the tracked fragment leaves its deployed local value. Restore the settings backup or remove that value explicitly when rolling back.
