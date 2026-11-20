---
status: accepted
date: 2026-11-20
tags: [hooks, tokens, rtk]
affected_components: [scripts/lib/claude-hooks-fragment.mjs, tests/claude-hooks-smoke.sh, claude/README.md]
amends: ADR-0045
---

# Keep the rtk Claude hook the owner installs

ADR-0045 retired RTK and listed a bare `rtk hook claude` among the retired hook commands, so `claude-hooks-merge` removed it from `~/.claude/settings.json`. This change takes that command off the list: `claude-hooks-merge` and `claude-hooks-check` leave an `rtk hook claude` the owner installed with `rtk init -g --hook-only`, whatever its path or options. Etabli still does not install RTK, and the `rtk-guard.mjs` hook, the Pi extension, `RTK.md` and the prompt rule stay retired.

The reason is a token audit of the work account, 16 to 20 November: Bash tool results were about 17 % of the API-equivalent cost, and RTK saves 18.7 % of the output it rewrites (`rtk gain`, 21 641 commands on macbook-work). That is roughly 3 % of the week, more than the 1.8 % ADR-0045 measured, for a hook that adds no rule to any prompt. Rejected: putting the hook back in the fragment (it would install RTK on every machine, Pi included, for a gain only measured on one). The cost accepted: rewritten commands carry an `rtk` prefix, which the read-only agent guard already strips for `git`, `gh`, `ls` and `wc` and otherwise judges as written.
