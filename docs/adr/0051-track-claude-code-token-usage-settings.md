---
status: accepted
date: 2026-11-20
tags: [settings, tokens, deploy]
affected_components: [claude/settings.skill-overrides.json, scripts/lib/claude-settings-sync.mjs, scripts/deploy-agent-workflow, claude/README.md]
---

# Track the Claude Code token-usage settings in the shared fragment

The tracked fragment now carries, beside the skill map, attribution and the
three booleans: `env.CLAUDE_CODE_SUBAGENT_MODEL: "sonnet"`,
`env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS: "100000"`, `modelSettings` effort
`medium` for `claude-opus-5-5` and `claude-sonnet-5-5`,
`autoCompactWindow: 200000`, `bashOutputMaxChars: 15000` and
`skillListingMaxDescChars: 400`. This lifts the deferral recorded in
`docs/plan/20261107-token-defaults.md`: every Claude runtime on the three
hosts (PATH binary, the `claude-bin.sh` candidates, native installs, fnm/nvm
global installs, the runtime T3 Code spawns) was inventoried on 2026-11-20
at 2.1.292 or newer, above the 2.1.251 precedence change that makes the
subagent env a default rather than an override.

The writer validates each key by type and bound and refuses an out-of-bounds
tracked value before any backup or write, instead of relying on the client's
silent clamping. Each key carries its documented minimum version (subagent
model and per-model effort 2.1.251, Bash cap 2.1.261, compaction window
2.1.288, idle threshold 2.1.299; the skill description cap states no minimum
and stays ungated): on an older, absent, failing or unreadable
`claude --version` probe the key is skipped with a warning naming its
minimum, while satisfied and ungated keys still sync. `modelSettings` merges
`effortLevel` only, per tracked model; other models and fields stay, and a
local per-model `autoCompactWindow` that overrides the tracked window draws
a warning that names the model, never the value.
`scripts/deploy-agent-workflow --check` now reports tracked-settings drift
on a live home as an unresolved issue naming `--apply`, without writing.

The reason is a private token audit of 20 November 2026: the cost follows
what enters the context and how long it stays there, on which model — and
none of these settings was distributed, so each host carried its own
hand-set (or unset) values. On gromarchy, model-less subagents inherited the
parent model because no default was tracked.
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE` stays out of the fragment and is rejected
as a tracked key: it would override the models agents declare in their
frontmatter, including the review agents. Rejected: clamping out-of-bounds
values the way the client does (the fragment would then depend on silent
client behavior), and one global version gate (an older host would lose keys
it could honor). The cost accepted: a smaller window and Bash cap mean more
summaries and more file reads, and shorter skill descriptions can weaken
skill triggering; each key reverts by editing the fragment and redeploying.

- Review date: 2026-11-27. Compare a 7-day `scripts/claude-usage-audit` run
  per host against the audit's ratios; keep each lever that moved its
  indicator without a quality complaint, and revert the others in the
  fragment.
