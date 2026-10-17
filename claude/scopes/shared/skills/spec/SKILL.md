---
name: spec
description: Writes, structures or revises employer product specs, technical Epics and design docs from the two bundled templates. Use for /spec or when the user asks to draft or review a spec, Epic or design doc; not for ADRs (adr) or Linear tickets (linear-ticket-create).
---

# employer spec writing

Write an employer spec that meets two standards: the team's real format (Linear)
and industry design-doc practice (Google, RFC, ADR). A spec exists to **collect
feedback BEFORE building**, not to document afterwards.

## Two levels, never mixed

employer splits two documents. Decide which one you are writing BEFORE starting.

| | Product spec | Technical Epic |
|---|---|---|
| Answers | **what / why** | **how** |
| Written by | product / CS | tech |
| Template | `template-product.md` | `template-technical.md` |
| Key sections | Problem/Goal/Solution, Discovery, Description, Screens, Expected behavior, Events | Context, Goals/Non-goals, Technical description, Alternatives, Cross-cutting, User stories, Estimations |

A very technical architecture spec (a service such as the BFF) is a **hybrid**:
take the technical template, it already carries the light product context. Both
templates sit next to this file: copy the right one and fill the `< >`.

## Core versus disposable

Across the ~16 real employer Epics, these are **always present**: Scope/Owners/Product
spec, Technical description, User stories (points, Required/Optional),
Estimations, Questions. These are **optional boilerplate** (often pasted,
sometimes dropped): the opening `> **Warning**` blockquote, Design challenge,
Tech approval. Keep the core, delete unused optional parts.

## The sections everyone forgets (and that carry the value)

Without them a "spec" is an implementation manual. The templates include them;
never leave them empty.

- **Non-goals**: what could be a goal but is excluded. Stops scope creep.
- **Alternatives considered**: the other serious approaches and *why they were
  rejected*. This is what makes it a decision. Flag irreversible choices
  (one-way doors).
- **Cross-cutting**: Security & privacy, Rollout/migration (with **rollback**),
  Monitoring. A deliberate "N/A" is fine; a missing section is not.

## Principles

- **Trade-offs over implementation.** If the solution is obvious with no
  trade-off, the spec is not needed. The core is the choices and their reasons.
- **Verify, do not assume.** Source every technical mechanism as `file.ts:line`;
  otherwise mark it "to confirm". A dropped option stays ~~struck through~~ with
  the why. A choice that changed gets an honest callout.
- **Link, don't duplicate.** Point to the product spec or the repo instead of
  copying, but embed 2-3 lines of context so the reader need not leave.
- **Proportionate.** Small change: a few lines. Large project: split it. No spec
  for a trivial change.
- **Explicit status.** Draft → In review → Accepted, plus who must approve.

## Writing the content

**Specs are written in English** (every employer spec is). For prose (context,
reasons, transitions), use the direct voice transposed to English: invoke the
`write-direct` skill. Technical contracts (routes, payloads, types) stay exact,
never stylized. ASCII diagrams stay clean (aligned boxes, arrows under what they
connect).

Linear target: the spec lives in a Linear **Document** (wiki-page equivalent)
attached to the Product team. Standard Markdown. Linear does NOT render GitHub
callouts `> [!NOTE]`; a bold title inside a blockquote (`> **Note**` then the
text) plays the same role. Keep blockquotes for important call-outs.

## Before publishing

- [ ] Every `< >` filled or deleted
- [ ] Every `<!-- -->` comment removed
- [ ] Unused "(optional)" sections deleted
- [ ] Non-goals and Alternatives filled (or a justified "N/A")
- [ ] Technical mechanisms sourced as `file.ts:line`

## Length

Mini-spec or incremental change: 1-3 pages. Large project: 10-20 pages at most;
beyond that, split. Until it ships, update the spec when the design drifts;
after shipping it becomes the historical entry point.
