<!-- employer TECHNICAL EPIC template (the "how"). The product "what/why" has its own
     template: SPEC-TEMPLATE-PRODUCT.md. Fill the < >, delete what you don't need, and STRIP every
     comment + unused "(optional)" sections before publishing. Write in English. -->

# Epic - [Persona] want [outcome]

**Scope:** <domain — Workflow, AI, Platform, Agent…>
**Owners:** <names>
**Status:** Draft <!-- Draft → In review → Accepted -->
**Approvers:** <who must read and sign off before dev>
**Product spec:** <link — the source of the what/why (SPEC-TEMPLATE-PRODUCT.md)>

> **Warning**
> Read the linked product spec first and challenge it. It must cover discovery, solution, screens, expected behavior, release and events. Without that, don't start the technical work.

## Context & problem

<!-- 2-4 lines, embedded (not just a link): the state of the system today and the precise technical problem you're solving. Someone should get it without opening 3 other docs. -->

## Goals

<!-- The intended outcomes, measurable if possible. What success looks like. -->
-

## Non-goals

<!-- What COULD reasonably be a goal but you exclude, explicitly. The section everyone forgets, and the one that kills scope creep. E.g. "no massive multi-tenant in v1", "no support beyond agent-nodejs". -->
-

## Technical description

<!-- The core. Not an implementation manual: emphasize the choices and their trade-offs.
  - concrete entities in a block: TS interfaces, tables, payloads.
  - architecture/service: a clean ASCII diagram (boxes same width per level, arrows │ ▼ └──┬──┘ under what they connect) + routes (a "what it does" list + a Params/Result table, or by case).
  - VERIFIED mechanisms sourced `file.ts:line` — no assumption; otherwise mark "to confirm".
  - ⚠️ on hard constraints / assumed limits.
  - options dropped along the way → ~~struck through~~ with the why-not.
  - a choice that changed / might be stale → a callout, with the up-to-date source. -->

```typescript
export interface <Entity> { /* … */ }
```

## Alternatives considered

<!-- The other serious approaches, and WHY rejected. Without this section, the doc is just an implementation manual, not a decision. One line per alternative is enough: "X — dropped because Y". Flag any choice that's a one-way door (irreversible). -->
-

## Cross-cutting

<!-- The classic blind spots. One line each, an assumed "N/A" if truly nothing. -->

- **Security & privacy:** <trust boundaries, secrets, the real barrier, exposed data. Who holds what.>
- **Rollout / migration:** <how you deploy, what you migrate, feature flag or big-bang, and the **rollback** if it goes wrong.>
- **Monitoring:** <how you'll know it works in prod: metrics, traces, health, version in responses.>

## User stories

<!-- Cut into shippable units. A story blocked by another → order them. Several batches → group under `### Release N`.
  Per story: title + points, `> **Required**` or `> **Optional**` in a blockquote, back/front/tests checklists ticked as you go, PR link inline, ~~struck through~~ for the dropped. -->

### Story #1 - <title> - <N>pts

> **Required**

- [ ] Backend — <task>
- [ ] Frontend — <task>
- [ ] Tests

## Estimations

> **Note**
> 8 pts / dev / week (review + tests + release included), or 4 pts / dev / day (without review).

- **Global:** <N> pts → <N>d dev, <N>d to release
- **Required:** <N> pts · **Optional:** <N> pts

## Tech approval (optional)

<!-- Keep if the feature touches another team, otherwise delete the section. -->
> **Warning**
> Share in #tech-all for sign-off: Platform if new infra/platform usage, Core/DevXP/OpsXP if the ownership is close to them.

## Questions

<!-- The living trace of decisions: questions raised, answer, status. Stops the next reader from re-asking the same ones. -->

| Question | Answer | Status |
| -------- | ------ | ------ |
|          |        |        |

## Revisions

<!-- Changes decided AFTER dev started. Don't rewrite the body — trace it here. -->
