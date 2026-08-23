---
status: accepted
date: 2026-08-03
tags: [workflow, routing, tokens, context]
affected_components: [claude/hooks, pi/extensions, tests, docs/adr/0007]
---

# Stop injecting route context into every prompt

Etabli no longer injects router guidance into the system prompt on every turn.
`classifyWorkflowRoute` and all six `plan*Guard*` predicates stay exactly as they
were; only the injection path is removed — `shouldInjectRouteContext`,
`buildRouteContext`, `userPromptSubmitDecision`, `claude/hooks/workflow-router.mjs`
and its `UserPromptSubmit` entry on the Claude side, and
`shouldInjectWorkflowRouter` / `appendWorkflowRouterGuidance` on the Pi side.

This **narrows** ADR-0007 rather than superseding it. That ADR bundled two
decisions: deterministic route classification with guards, and injecting the
resulting context into the prompt. Only the second is reversed here. ADR-0007
stays `accepted` because its guard half — the READY gate, check-freeze,
ops-stop, no-progress — is still in force and is the reason the classifier
exists at all. The formal `supersedes` field is deliberately not set: the
validator would require flipping ADR-0007 to `superseded`, which would be false.

## Why

Measured on real prompts before removal:

```
1426 chars (~357 tok)  route=plan-implement  "Implémente le PLAN.md ready"
1410 chars (~353 tok)  route=plan-implement  "corrige ce bug"
1149 chars (~287 tok)  route=answer          "Donne-moi des idées de SaaS"
 834 chars (~209 tok)  route=review          "review this diff"
```

~301 tok/turn average, against a ~2 700 tok fixed instruction load. Over a
50-turn session the injection is the larger line item (~15k vs 2.7k once). The
`answer` route — the most frequent — paid ~287 tok to restate a route the model
infers from `workflow/spec.md` anyway.

The guards are different in kind: they *block* actions, which no prompt text can
do. They are kept for exactly that reason.

## Consequences

- Route classification is now library-only. Its coverage is `scripts/router-eval`
  (53 cases, accuracy 1.0, including knowledge-routing), plus the Pi extension
  tests that observe the decision object.
- `tests/claude-hooks-smoke.sh` drops from 481 to 295 lines: ~40 router
  assertions removed, every guard section kept — those back the proofs in
  `workflow/runtime-capabilities.json:17-27`. Its 36 request fixtures under
  `tests/fixtures/claude-hooks/` went with them.
- `tests/agent-scenarios-smoke.sh` was **rewritten, not deleted**. It is the
  Claude/Pi route-parity matrix; a `claude_route_probe` helper now renders the
  same fields from `classifyWorkflowRoute` directly, so all 11 scenarios and
  their needles survive.
- The behavioral suite's `claude_route` driver calls the library directly
  instead of spawning the deleted hook, so all routing tasks stay driveable
  and the corpus hash pin holds.
- `scripts/lib/route-context-manifest.mjs` is now orphaned (its only consumer
  was the injection path). Left in place; `workflow/route-context-manifests.json`
  and its bash checker are a separate call.
  *(2026-08-23 update: the orphaned artifacts — lib, manifest JSON, checker,
  and smoke — were removed by the 7-round review follow-up; see
  `docs/archive/README.md` and the plan archive for that pass.)*
- The Pi `appendEntry` decision record is kept. With no injection it is no
  longer a UI feature but the only observation point for the Pi-side classifier,
  and five extension tests assert through it.

## Risk accepted

No mechanical check observes the behavioral effect. `router-eval` proves the
classifier is intact, not that agents route well without the injected context.
This is judged in daily use, and the change is self-contained enough to revert
alone if routing quality degrades.

## Validation

`scripts/router-eval`: 53/53, accuracy 1.0. `bun test pi/extensions/__tests__/`:
192 pass. `scripts/verify-agentic-infra full`: 44 PASS, 1 FAIL (`skill-lock`,
pre-existing on `main`).

Correction recorded deliberately: the first version of this ADR claimed that
same suite result while `pi-import-smoke` was in fact broken — it still imported
the deleted `block-google-providers.ts`. The failure was invisible because
`skill-lock` fails earlier in the `pi` group and stops the run. A fresh-context
review caught it. The lesson is that a known pre-existing failure can mask a new
one: when a group already has a red check, run the specific target too, not just
the group.
