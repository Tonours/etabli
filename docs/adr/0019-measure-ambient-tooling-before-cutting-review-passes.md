---
status: accepted
date: 2026-08-26
tags: [tooling, hooks, review, metrics, token-efficiency]
affected_components: [workflow/self-improvement/review-metrics.md, workflow/skills/adversary.md, workflow/skills/ship.md]
---

# Measure ambient tooling before cutting review passes

## Context

A session asked whether the subagent logic is token-efficient. The first
analysis proposed six optimizations, four of which targeted the review stack:
drop the standard-tier double-sample adversary (`workflow/skills/adversary.md`),
relax the `/ship` gate that blocks on a single same-family pass
(`workflow/skills/ship.md`), stop delegating to `worker`, and deduplicate the
injected CLAUDE.md chain.

Three filters ran in sequence, and each killed a different set of proposals:

1. **Reasoning (adversary pass on the analysis).** The double-sample rejection
   was wrong: `reviewer` reads the intent artifact and `adversary` is forbidden
   from reading it, so the two samples differ by *information*, not only by
   model. That decorrelation is weaker than cross-model but not zero. The
   `worker` rejection was also wrong — it counted total tokens and ignored that
   the worker absorbs implementation churn that would otherwise push the parent
   into compaction.
2. **Measurement.** Verbatim duplication across the nine injected chain files is
   **2 lines, ~138 bytes, ~37 tokens** out of ~7810. The earlier "git rules ×3,
   anti-sycophancy ×2" claim had measured *topic overlap between layers* — the
   adapter/contract/machine-override split working as designed — not recoverable
   text. This proposal survived the adversary pass and was killed only by
   counting.
   Pruning the injected skills catalog was rejected on a different ground: 9 of
   12 `enabledPlugins` entries are on, and which of them a developer wants is a
   preference, not a defect. A harness decision does not silently disable
   someone's tools to buy context.
3. **Empirical probe (adversary pass on the resulting plan).** It raised a HIGH
   blocker claiming `[hooks] exclude_commands` does not exist in rtk 0.34.0,
   evidenced by `grep -a -c` on the binary returning `0`. That evidence was
   produced by the very defective tool the plan repairs: a raw byte scan finds
   the string, and writing the key demonstrably changes `rtk rewrite` behavior.
   The blocker dissolved; its two MEDIUM and four LOW findings were folded.

What the measurement did find is a defect in the ambient tooling that no review
pass would ever have surfaced, because it corrupts the evidence reviews are
built from.

## Decision

1. **`grep` and `rg` are excluded from rtk rewriting.**
   `~/Library/Application Support/rtk/config.toml` carries
   `[hooks] exclude_commands = ["grep", "rg"]`. `rg` needed the same treatment
   because rtk maps it onto the same `rtk grep` implementation
   (`rtk rewrite 'rg foo src/'` returned `rtk grep foo src/`), so an
   exclusion naming only `grep` left the identical corruption reachable through
   `rg`. Found by the Logic hunter, not by the author. `rtk grep` re-parses grep's
   `file:line:content` output by splitting on `:`, so any match whose line
   contains a colon returns an invented filename, line `0`, and the key
   stripped; `grep -c` returned a match listing instead of a count. Every
   `file:line` reference in the workflow contracts, every YAML frontmatter and
   every JSON/TOML config is in that blast radius, across 3986 recorded grep
   calls at a claimed 9.3% saving. Correctness of evidence outranks a 9%
   compression on the tool the whole review stack reads with.
2. **Machine-local problems get machine-local fixes.** The double-sample cost is
   a consequence of `~/.claude/rules/claude-only-agents.md` forbidding a
   cross-model runner on this machine, not a defect in `workflow/`. The shared
   contracts are deployed to other machines and to Pi, where the same gate buys
   one cross-model pass rather than two same-family ones. They are not edited to
   relieve one machine.
3. **The double-sample gets instrumented, not cut.** `review-metrics.md` gains
   an `adversary_unique` column recording whether the second sample produced a
   finding the first missed. A run of `n` is the evidence required to propose
   relaxing the requirement; until then the requirement stands. This closes the
   loop that ADR-0013 opened for the council: measure the pass, then decide.
4. **Tool precedence is stated once, outside machine-managed files.**
   `~/.claude/rules/tool-precedence.md` records that the hooks perform the
   redirect mechanically, so the `ctx_*` mandate needs no per-call decision, and
   that `rtk proxy <cmd>` is ground truth. It lives outside
   `~/.claude/rules/lean-ctx.md`, which is regenerated between
   `<!-- lean-ctx-rules-v11 -->` and `<!-- /lean-ctx -->`; whether the
   regenerator preserves content outside that block is unverified, which is
   itself the reason for a separate file.
5. **No cut without a number.** A token-reduction proposal against the review
   stack or the ambient chain is not actionable until it names a measured
   quantity. Four of six proposals here died on that rule.

## Consequences

- Good: grep output is trustworthy again, and the one durable lesson —
  compression layers can be *net negative* and their savings figures do not
  detect it — is written down instead of rediscovered.
- Good: the double-sample debate now has a data column instead of two opposing
  intuitions.
- Bad: rtk's recorded grep savings (4.7M tokens) are forfeited. Accepted: on the
  observed cases the mangled output was longer than the correct output, so part
  of that figure was never a saving.
- Bad: `adversary_unique` starts empty, so the double-sample stays justified by
  argument for as long as the column is unfilled. The 17 backfilled rows carry
  `n/a` and cannot be recovered.
- The two stacked Bash rewriters (`rtk-rewrite.sh` and `lean-ctx hook rewrite`)
  both claim `cat` with order-dependent precedence. No incorrect output was
  observed, so no fix is in scope; recorded for the next session that sees a
  compound command behave oddly.
- Step 3's precedence rule cannot silence the copy of the mandate injected by
  the lean-ctx MCP server; it only subordinates it.
