# Product Dogfood Verification Contract

Shared contract for proving user-facing changes through real flows, observable
UI/browser evidence, and a bounded fix loop.

This is a validation layer, not a mandatory top-level route. Runtime adapters
may use Playwright, a browser plugin, Chrome, Computer Use, or another
observable UI surface when available. Do not hardcode one browser driver into
the shared workflow contract.

## Trigger

Use this contract when a change materially affects a user-visible product flow:

- UI screens, forms, navigation, content, responsive behavior, or accessibility;
- browser-side state, auth, permissions, redirects, or client/server handoff;
- emails, notifications, links, callbacks, exports, imports, or other side
  effects that users follow across surfaces;
- a user explicitly asks to dogfood, click through, visually verify, or test the
  branch like a real user.

Do not force this contract onto pure docs, internal refactors, CLI-only changes,
or backend-only changes with no user-visible path unless their acceptance
criteria require UI/browser proof.

## Required Sequence

1. Resolve the target under test: branch/ref, base, changed files, app surface,
   and whether edits are allowed.
2. Scope to the diff or stated acceptance criteria. Do not turn dogfood into a
   whole-app audit unless the user asked for that scope.
3. Map user flows before writing a checklist:
   - entry point;
   - each user action;
   - validation, empty, error, permission, and loading branches;
   - side effects;
   - true end state.
4. Derive a scenario matrix from the flow map. Each flow node and branch that
   can change the outcome becomes a scenario.
5. Choose the strongest available observable surface:
   - browser/runtime tool when available;
   - Playwright or project test harness when available;
   - manual verification request when the decisive leg is external;
   - `blocked: no validation surface` when none can prove the claim.
6. Execute each scenario as a user would. Do not mark a page render as pass when
   the feature risk lives between pages or after a side effect.
7. Record artifacts or exact evidence for each scenario: URL, command,
   screenshot, trace, console/network result, email preview, log line, or
   explicit reason the leg is blocked.
   - For durable claims, capture a closed pack shaped by
     `workflow/evidence-pack.schema.json`. Bind the target/environment hashes and every action, result, and declared
     side effect to a non-empty hashed artifact.
   - `integrity_valid` means the pack is internally intact. Only an explicit
     parent-observed receipt can yield `parent_observed_execution`.
8. Run the fix loop only for failures or sharp product paper cuts that are clear
   and low-risk.
9. Re-run the failed scenario after each fix, then re-check adjacent flows that
   could regress.
10. Re-run the plan's focused checks after any accepted dogfood fix. Readiness
    cannot rely on validation that predates the latest product-flow edit.
11. Finish with a report or plan/archive section that names passed, failed,
    blocked, fixed, and handed-off scenarios.

## Scenario Matrix

The matrix must be concrete enough that another agent or human can replay it:

```md
| Scenario | Flow branch | Preconditions | Steps | Expected result | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
```

Statuses:

- `pass`: observable evidence proves the expected result.
- `fail`: observable evidence contradicts it.
- `fixed`: the scenario failed, was fixed, and passed on re-run.
- `blocked-human-decision`: a product, schema, architecture, security, or
  business trade-off must be decided by a human.
- `blocked-human-verify`: the decisive leg requires a human-controlled external
  surface such as OAuth consent, real inbox delivery, payments, production data,
  or unavailable credentials.
- `blocked-no-validation-surface`: no available runtime, artifact, or command
  can prove the scenario.

Do not convert a blocked scenario into `pass`.

When only a screenshot fixture, mocked adapter, or hand-authored artifact is
available, report `proxy_supported`. When no observable artifact exists,
report `blocked`. Neither label is a live product pass.

For UI scope, record exact viewports plus keyboard, focus, accessibility,
console, network, responsive, and reduced-motion outcomes. Responsive claims
need at least one viewport at or below 480px and one at or above 1024px.
Motion scope needs reduced-motion evidence.

## Product Lens

A product/persona lens can flag friction, confusing copy, unnecessary clicks,
visual jumps, or expectation mismatches. Treat it as a second reading, not an
independent proof source. A sharp paper cut may enter the fix loop, but the
final readiness claim still needs functional evidence or an explicit handoff.

## Fix Loop Governor

Autonomous fixes are allowed only when all are true:

- the failure is reproduced or directly evidenced;
- the root cause is clear enough to explain;
- the fix is localized and low-risk;
- no schema, architecture, permission, security, billing, or product trade-off
  is being decided;
- a regression test, browser replay, or documented artifact can prove the fix.

If any condition is false, stop that scenario as `blocked-human-decision` and
record:

- what is broken;
- options with trade-offs;
- the recommended next decision;
- the smallest verification that should run after the decision.

Do not invent hollow tests to satisfy the loop. When a test is meaningless
because the fix is copy, spacing, or a visual adjustment, say why and preserve a
browser/UI replay artifact instead.

## Event Ledger

For autonomous runs, record dogfood progress in `.workflow/<slug>/events.jsonl`
with the event types in `workflow/events.md`:

- `dogfood_matrix_created`;
- `dogfood_scenario_run`;
- `dogfood_fix_applied`;
- `dogfood_blocked`.

The final `completed` or `blocked` event remains the terminal run state.

## Completion Evidence

Dogfood is complete only when the final handoff names:

- target ref/base or acceptance criteria under test;
- flow map location or inline summary;
- scenario matrix location or inline summary;
- browser/UI/runtime surface used, or the explicit blocked reason;
- pass/fail/fixed/blocked counts;
- fixes made and their regression evidence;
- focused checks re-run after dogfood fixes;
- adjacent flows re-checked after fixes;
- human decisions or manual verification still required.
