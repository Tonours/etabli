# Command/skill backlog

Candidates surfaced by `/analyze-sessions` on the conversation logs. Not built —
each needs context we don't have yet. Build when the trigger condition is met.

## qa-visualizer (highest potential gain)
Parameterized Chrome DevTools QA workflow: dev URL, workflow name, step, test-id
list, main vs fix branch, before/after screenshots. ~15 hits, very high manual
load — retyped near-identically each time.
- Blocked on: credentials + base URLs must go to config (not hardcoded in a
  committed command), and it depends on the chrome-devtools MCP being set up.
- Build when: you start a QA session and want it repeatable. Cadre the config
  story first.

## release-tag
bump version + tag rc/release + verify CI green. ~40 hits.
- Blocked on: the exact release flow is package-specific. A generic command risks
  being wrong/useless.
- Build when: a concrete package needs a repeatable release ritual — model it on
  that one, don't generalize early.

## strip-comments
Deterministically remove useless comment-blocks from a diff/PR. ~22 hits, aligned
with the "No comments" rule.
- Overlaps: `simplify` / `code-simplifier` already cover part of this.
- Build when: `simplify` proves too broad and you want a surgical
  comment-only pass. Otherwise YAGNI.
