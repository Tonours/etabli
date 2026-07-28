---
name: adonisjs-architecture
description: Choose the right AdonisJS 7 structure before coding. Use for layer ownership, module choice, framework-native design, large refactors, and drift-prone architectural decisions.
---

# AdonisJS Architecture

Use this skill before implementation when the main risk is structural drift.

Read [architecture principles](references/architecture-principles.md) first.
Read [decision checklist](references/decision-checklist.md) before making a recommendation.
Read [decision record template](references/decision-record-template.md) when the decision should be recorded.
Read [module playbooks](../adonisjs-backend/references/module-playbooks.md) when the choice depends on a specific Adonis module.
Read [anti-patterns](../adonisjs-backend/references/anti-patterns.md) when drift risk is high.
Read [examples and prompts](references/examples-and-prompts.md) when the user needs a ready-to-send architecture prompt.
Use [adonisjs-testing](../adonisjs-testing/SKILL.md) after the design is chosen to define the minimum proof needed to ship safely.

## Role

Act as the architecture safety harness for AdonisJS 7.

Do not jump to code first. Decide:

- which Adonis primitive should own the concern,
- which layer should hold each responsibility,
- which framework defaults should stay explicit,
- which shortcuts would create drift.

## Decision flow

1. Classify the problem: HTTP, persistence, validation, auth, contract, bootstrapping, background work, integration, or operations.
2. Map it to the closest Adonis module or lifecycle primitive.
3. Assign the correct layer.
4. Check drift risk.
5. Recommend the smallest safe design.
6. If several paths work, rank them and choose one.

## Defaults

- routes define entry points
- middleware handles cross-cutting HTTP concerns
- controllers orchestrate and define response boundaries
- Vine validators own input contracts
- Lucid owns persistence shape
- actions/services own multi-step business workflows
- providers own registration and boot wiring
- events/listeners own reactions
- commands/scheduler own operational or recurring execution
- Mail, Drive, Auth, Ally, and Bouncer own their native concerns

## Block when

- a custom abstraction replaces an obvious Adonis primitive,
- business logic is pushed into middleware or controllers,
- Vine or Lucid is bypassed casually,
- env/config access leaks into feature code,
- API contracts depend on unstable database internals,
- important boot behavior is hidden outside providers,
- events/listeners replace an explicit core flow.

## Output

Return:

- recommended architecture,
- owner layer for each concern,
- AdonisJS primitives to use,
- drift risks,
- smallest safe implementation path,
- optional second-best alternative only if it matters.
