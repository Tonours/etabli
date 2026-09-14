# Workflow context budget

## Purpose

The context budget measures the resident instruction context each workflow
route loads, in JavaScript `String.length` characters (estimator: chars/4 for
tokens). A *surface* is the set of files a route or the always-on preamble
reads unconditionally; each surface has one frozen ceiling.

## Why resident context

Measured ledgers showed resident context dwarfing real work:

- `.workflow/harness-hardening-v2`: total 28,474,115 vs input 663,111 + output
  97,468 = 37×.
- `.workflow/etabli-live-lane`: 7,830,227 vs 100,499 + 33,024 = 59×.
- `.workflow/pstack-wave3-plan`: 39,561,741 vs 61,842 + 32,187 = 420×.
- 38 of 53 `outcome_metric` events were unmeasured.

Every duplicated rule in an always-loaded file is paid on every turn; the fix
is progressive disclosure — short maps that point to detail documents.

## Before / after

Ceilings are frozen at the pre-change numbers and ratcheted downward by the
lead after review; they never rise silently.

| Surface | Before | After | Δ | Ceiling |
| --- | ---: | ---: | ---: | ---: |
| always-on | 28,423 | 16,150 | −43% | 16,635 |
| plan-loop | 5,657 | 4,180 | −26% | 4,306 |
| plan-implement | 80,451 | 52,991 | −34% | 54,581 |
| implement | 74,632 | 48,747 | −35% | 50,210 |
| review | 21,800 | 21,800 | 0% | 21,800 |
| verify | 3,093 | 3,071 | −1% | 3,093 |
| spec-map | 32,258 | 32,256 | ~0% | 32,258 |

Ceilings are the ratcheted gates in `workflow/runtime/context-budget.json`; the
always-on After is the post-adversary measurement (16,150 chars) that its
16,635 ceiling was ratcheted from.

## What moved where

| Source | Destination |
| --- | --- |
| plan-loop source ladder + embedded template | pointer to `PLAN_TEMPLATE.md` |
| events validator/writer internals | `workflow/events-validator.md` |
| implemented-plan archive skeleton | `workflow/templates/plan-archive.md` |
| symlink layout bullet list | `docs/symlink-layout.md` |
| `workflow/spec.md` on hot routes | on demand; hot-route rules duplicated into `workflow/skills/implementation-loop.md` § Standing rules and `workflow/skills/plan-loop.md` § READY Gate |

## The loop

`workflow/skills/self-improvement-loop.md` § Token lens drives the recursive
cycle. Commands:

- `scripts/workflow-context-budget` — check all surfaces against ceilings.
- `scripts/workflow-context-budget --json` — per-surface chars, files, headroom.
- `scripts/workflow-context-budget --ratchet` — lower ceilings to
  `ceil(chars * 1.03)` after a validated trim; never raises.
- If a route genuinely needs more resident context, raise its
  `ceiling_chars` in the same reviewed budget diff and record the rationale in
  the Decision Log; the CI failure is intentional until that review is present.
- `scripts/workflow-retrospect` — text/JSON report now carries `context_budget`,
  `telemetry`, and `terminal` sections.

## Regression triggers

From `scripts/workflow-retrospect --json` at the time of this change:

- `telemetry`: measured=15, unmeasured=38 — unmeasured stays high; raising
  measurement coverage is a next lever, not a regression from this work.
- `terminal`: completed=73, blocked=8, in_progress=3 — a rise in `blocked` or
  `no_progress` outcomes after a trim signals a rule left the hot path.

## Not verified / next levers

- Billed tokens are not measured; chars/4 is an estimate, not an invoice.
- Runtime read-counting (which files are actually opened per session) needs a
  validator change; surfaces are declared membership, not observed reads.
- The ADR index cannot relocate from `CLAUDE.md` yet — the ADR helper
  hardcodes that path.
- Skill and tool surfaces are already gated by `scripts/claude-skill-load-check`
  and `scripts/pi-skill-load-check`.
