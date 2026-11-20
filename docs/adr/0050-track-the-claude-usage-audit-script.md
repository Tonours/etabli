---
status: accepted
date: 2026-11-20
tags: [tokens, measurement, claude]
affected_components: [scripts/claude-usage-audit, tests/claude-usage-audit.test.mjs, tests/fixtures/claude-usage-audit.mjs, workflow/runtime/agentic-infra-checks.tsv]
---

# Track the Claude usage audit script

`docs/research/20261109-claude-code-token-optimization.md` ended on "measured gain: none" because no tracked tool read the whole transcript tree. A private audit of 20 November 2026 measured the three hosts with a throwaway script; this decision tracks that script as `scripts/claude-usage-audit` so every token setting change can be compared on the same basis, 7 days later, on each host.

It reads `~/.claude/projects/**/*.jsonl` and the subagent `.meta.json` files, deduplicates turns by `message.id` plus `requestId`, and prints one JSON object of aggregates: tokens by model and by main thread or subagent, a list-price weight used only to rank models and token kinds, subagent runs by type with the model each ran on, concurrency, context peaks, cache misses, tool result sizes, first-turn context, effort, entrypoints and project basenames. Two additions over the throwaway script: a Bash result size histogram, to set `bashOutputMaxChars`, and the first-turn context distribution per entrypoint, to separate interactive, SDK and T3 sessions. It has no dependency and never prints message text, tool inputs or tool results; its output still names projects and leading command words, so it stays on the host and never enters this repo.

Rejected: `/usage` alone (its percentages say which share of usage a tip applies to, overlap, and are not savings), `rtk gain` and `rtk cc-economics` (they ignore that a tool result is re-read on every later turn), and a statusline counter (it sees one session, not the tree).

## Consequences

- A test runs the script on fabricated transcripts: deduplication, subagent attribution, histogram bounds, entrypoint grouping, and the absence of any content marker in the output.
- The list prices in the script are relative weights; a subscription is not billed that way and its limits weight models and cache reads in unpublished ways.
- Review date: 2027-02-20. Still unused for a settings decision by then, the script is deleted.
