# Implemented: Product dogfood verification contract

## Metadata
- Archived: 2026-07-06
- Source plan: Integrate product dogfood verification into the Etabli workflow
- Status: IMPLEMENTED
- Commit / branch: `main` at `dbaec7b`; changes are uncommitted

## Outcome
- Added `workflow/skills/product-dogfood.md`, a shared harness-neutral contract
  for proving user-facing changes through real flows, a scenario matrix,
  observable UI/browser evidence, bounded fixes, and honest blocked states.
- Wired the contract into `workflow/spec.md` as a validation layer for material
  product-flow changes, without adding a new top-level router route.
- Updated `workflow/skills/implementation-loop.md` so dogfood runs before final
  focused checks for material user-facing changes, stops as plan drift if a
  plan omits required dogfood evidence, and re-runs checks after dogfood fixes.
- Extended `PLAN_TEMPLATE_FULL.md` with `Product Dogfood`, `User Flows`,
  `Scenario Matrix`, `Product Lens`, and `Browser/UI Evidence` sections.
- Added dogfood-specific ledger events to `workflow/events.md` and
  `scripts/workflow-event`: `dogfood_matrix_created`,
  `dogfood_scenario_run`, `dogfood_fix_applied`, and `dogfood_blocked`.
- Pinned the contract and event behavior in `tests/workflow-docs-smoke.sh` and
  `tests/workflow-event-smoke.sh`.

## Context
- `workflow/spec.md`: existing Etabli source of truth for evidence gates,
  blocked outcomes, event ledgers, fresh-context review, and plan drift.
- `workflow/skills/implementation-loop.md`: shared implementation phase order
  for Pi and Claude adapters.
- `PLAN_TEMPLATE_FULL.md`: prior UI validation surface was only a generic
  `UI/browser checks` bullet.
- `claude/skills/playwright-*`: existing Claude-side Playwright capabilities,
  but not a shared workflow contract or slash-command route.
- `scripts/lean-ctx-check`: reported `lean-ctx unavailable; documented native
  fallback present`, so native shell/search was used.

## Decisions
### Keep Dogfood As A Shared Validation Contract
- Context: The useful lesson from the article is flows and durable proof, not a
  new router path for every harness.
- Choice: Add `workflow/skills/product-dogfood.md` and reference it from the
  spec and implementation loop.
- Rejected options: new Pi/Claude/Codex router route in this change.
- Rationale: Dogfood is conditional validation for material user-facing
  product-flow changes. Adding a route would require adapter fixtures before it
  changes the core behavior.
- Consequences: Future plans can invoke dogfood without router churn; a later
  route can still be added if real prompts show demand.

### Stay Browser-Tool Neutral
- Context: The article describes one browser tool, while Etabli supports Pi,
  Claude, Codex, Playwright skills, browser plugins, Chrome, and sometimes no
  browser surface.
- Choice: Require the strongest observable UI/browser surface available and
  record `blocked` when none proves the claim.
- Rejected options: hardcoding one browser driver into `workflow/spec.md`.
- Rationale: Runtime capability honesty is already an Etabli invariant.
- Consequences: The contract can be used across harnesses without pretending
  they expose identical browser automation.

### Fresh Review Findings Folded
- Context: Fresh-context reviewer `Huygens` returned `BLOCK`.
- Choice: Accept both findings.
- Rejected options: treating the review as advisory because smokes were green.
- Rationale: Focused checks must not predate dogfood fixes, and the trigger must
  not rely on a plan that might forget dogfood for a material UI change.
- Consequences: `implementation-loop.md` now runs dogfood before the final
  focused check gate, stops as plan drift if dogfood evidence is omitted, and
  `product-dogfood.md` requires checks after any accepted dogfood fix.

## Accepted Drift
- Original plan/spec: Add contract, template, event types, smoke pins, and
  archive.
- Implemented reality: Completed as planned, with one reviewer-driven
  strengthening to implementation phase order and trigger semantics.
- Why accepted: The fresh-context review identified correctness gaps in the
  initial implementation; fixing them made the original objective more true.

## Validation Evidence
- `bash tests/workflow-docs-smoke.sh`
  - result: passed after replacing one brittle full-sentence pin with a stable
    substring because Markdown wrapped the sentence.
- `bash tests/workflow-event-smoke.sh`
  - result: passed; includes real append/validate coverage for all dogfood
    event types.
- `bash tests/workflow-contract-coverage-smoke.sh`
  - result: passed; the new shared contract is referenced and deployed.
- `bash tests/workflow-scaffold-smoke.sh`
  - result: passed.
- `git diff --check`
  - result: passed.
- `bash -n scripts/workflow-event tests/workflow-docs-smoke.sh tests/workflow-event-smoke.sh tests/workflow-contract-coverage-smoke.sh tests/workflow-scaffold-smoke.sh`
  - result: passed.
- `scripts/workflow-event validate dogfood-product-verification`
  - result: passed before archive with 16 events.
- Fresh-context review
  - result: initial `BLOCK` with two accepted findings, then `GO` with no
    remaining findings.

## Follow-up State
- Remaining risks: No runtime dogfood adapter was added. This is deliberate;
  the contract defines when future UI/browser work must produce evidence.
- Parking lot: Add a first-class dogfood route only after real prompt fixtures
  show that ambient routing needs it.
- Superseded docs/specs: none.
- Next links:
  - `workflow/skills/product-dogfood.md`
  - `workflow/skills/implementation-loop.md`
  - `workflow/events.md`
