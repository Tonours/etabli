# Implemented: exclude grep/rg from rtk rewriting and instrument the double-sample adversary

## Metadata
- Archived: 2026-08-26
- Source plan: `PLAN.md` — Implement the measured subset of the workflow token-optimization proposals; reject the unmeasured ones
- Source plan SHA-256: `8072e801a5c946a0c3454d2f2e80955d177a6c0a34cbb1ebe364f9035d5583fc`
- Status: IMPLEMENTED
- Commit / branch: main, uncommitted at archive time

## Outcome
- `~/Library/Application Support/rtk/config.toml` created with
  `[hooks] exclude_commands = ["grep", "rg"]`. Both commands now return native,
  uncorrupted output; `cat` and `find` stay rtk-optimized.
- `workflow/self-improvement/review-metrics.md` gained an `adversary_unique`
  column (definitions + Log header + 17 backfilled rows at `n/a`) and a
  reading-the-signal rule.
- `~/.claude/rules/tool-precedence.md` created (machine-local) stating that the
  PreToolUse hooks already perform the redirect, so the plain native command is
  what to write.
- ADR-0019 recorded, indexed in `CLAUDE.md`.
- Four of six proposed optimizations rejected as false; recorded, not silently
  dropped.

## Context
- `rtk grep` re-parses grep's `file:line:content` output by splitting on `:`.
  Any match on a colon-bearing line returned an invented filename, line `0`, and
  the key stripped. Ground truth via `rtk proxy grep`.
- rtk maps `rg` onto the same `rtk grep` implementation, so excluding only
  `grep` left the defect reachable.
- `~/.claude/rules/lean-ctx.md` is machine-managed between
  `<!-- lean-ctx-rules-v11 -->` and `<!-- /lean-ctx -->`.
- Verbatim duplication across the 9 injected CLAUDE.md chain files: 2 lines,
  ~138 bytes, ~37 tokens out of ~7810.

## Decisions
### Fix the tool, not the review stack
- Context: six proposed token optimizations, four aimed at the review passes.
- Choice: exclude `grep`/`rg` from rtk; leave `workflow/` untouched.
- Rejected options: cutting the standard-tier double-sample
  (`workflow/skills/adversary.md`), relaxing the `/ship` gate, dropping
  `worker` delegation, deduplicating the CLAUDE.md chain, pruning the plugin
  catalog.
- Rationale: the double-sample decorrelates by *information* (the adversary is
  forbidden the intent artifact), `worker` protects the parent from compaction,
  chain dedup recovers ~37 tokens, plugins are preference. The shared contracts
  are deployed to other machines and to Pi where the same gate is cheaper.
- Consequences: ambient cost rises ~400 tokens; evidence correctness improves.

### Instrument rather than cut
- Context: 17 metrics rows, all backfilled, models `unrecorded`, no column for
  the second sample's marginal yield.
- Choice: add `adversary_unique`; keep the double-sample until data says cut.
- Rejected options: cutting first and measuring later.
- Rationale: symmetric to ADR-0013 — the council was removed *after* a
  measurement gate, not before one.
- Consequences: the requirement stays argued-from-contract until the column fills.

## Accepted Drift
- Original plan/spec: Step 3 was to add a precedence paragraph to
  `~/.claude/rules/lean-ctx.md`.
- Implemented reality: shipped as a new sibling `~/.claude/rules/tool-precedence.md`.
- Why accepted: `lean-ctx.md` is machine-managed; an in-file edit would be lost
  on regeneration, and whether content outside the marker block survives is
  unverified.

- Original plan/spec: exclusion of `grep`.
- Implemented reality: exclusion of `grep` **and** `rg`.
- Why accepted: the Logic hunter's open question exposed that `rg` routes to the
  same implementation; the narrower fix was incomplete.

## Validation Evidence
- command: `diff <(grep -n "alpha\|8080\|beta" c.txt) <(rtk proxy grep -n ... c.txt)`
  - result: empty — identical to ground truth
- command: `diff <(rg -n "alpha|8080|beta" c.txt) <(rtk proxy rg -n ... c.txt)`
  - result: empty — identical to ground truth
- command: `grep -c beta c.txt`
  - result: `1` (was a mangled match listing)
- command: `cat c.txt | grep -n port`
  - result: `2:port: 8080`
- command: `scripts/validate-adrs`
  - result: ok, 19 records
- command: `scripts/verify-agentic-infra core`
  - result: 18/18 passed (baseline 18/18, unchanged)
- command: `bun test pi/extensions/__tests__/`
  - result: 242 pass, 0 fail (baseline identical)
- command: column-order equality check on both metrics tables
  - result: MATCH — definitions and Log header agree on all 9 columns

## Review Provenance
- Plan adversary: fresh-context Claude `reviewer` (`fable`), **same-family**.
  `PLAN CHALLENGED`; its HIGH blocker was refuted (its evidence came from the
  defective `grep` under repair), 2 MEDIUM + 4 LOW folded.
- Logic hunter: fresh-context Claude `reviewer` (`fable`), **same-family**.
  `GO WITH NOTES`; 1 MEDIUM (column-order asymmetry) fixed, 1 LOW fixed, and its
  open question found the `rg` gap.
- Spec: parent (`spec: parent`, reduced form per `workflow/skills/review.md`).
  Two self-findings fixed.
- Code-diff adversary: skipped per small-tier contract, not omitted.
- No cross-model pass available on this machine; nothing here is claimed as
  cross-model provenance.
