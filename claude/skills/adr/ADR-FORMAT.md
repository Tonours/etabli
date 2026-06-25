# ADR format and rules

Reference for the `/adr` skill. Architecture Decision Records capture *that* a
decision was made and *why* — not how to implement it.

## When an ADR is warranted

Propose an ADR only when ALL THREE conditions hold. If one is missing, refuse
and name the missing one.

1. **Hard to reverse** — changing course later carries real cost. Renaming a
   variable is not; choosing an ORM, a persistence model, or a public contract
   is.
2. **Surprising without context** — a future reader will ask "why on earth did
   they do it this way?". The decision is non-obvious from the code alone.
3. **The result of a real trade-off** — genuine alternatives existed and one was
   chosen over the others. Not a default, not the only option.

Qualifies: architectural shape, integration patterns between contexts,
technology choices with lock-in, boundary/scope decisions, deliberate
deviations from the obvious path ("manual SQL instead of the ORM because X"),
constraints invisible in the code, rejected alternatives when the rejection is
non-obvious.

Does NOT qualify: renaming, adding a test, following an existing convention,
formatting, a change with no alternative worth recording.

## File location and naming

- ADRs live in `docs/adr/` at the project root. Create the directory lazily —
  only when the first ADR is written.
- Sequential numbering, zero-padded to 4 digits: `0001-slug.md`, `0002-slug.md`.
- Next number = `max(existing NNNN) + 1`, NOT `count + 1` (a gap like
  `0001, 0003` must yield `0004`, never reuse `0003`).
- `slug` is a short kebab-case summary of the title. On collision, append a
  short disambiguator.

## Template

```md
---
status: accepted
date: YYYY-MM-DD
---

# {Short title of the decision}

{1-3 sentences: the context, what was decided, and why. State the accepted
cost and the rejected alternatives when the rejection is non-obvious.}
```

That is the whole template. An ADR can be a single paragraph. Optional sections,
added ONLY when they carry value:

- `## Considered Options` — the alternatives weighed.
- `## Consequences` — `Good, because …` / `Bad, because …`.

All ADR content is written in English regardless of the conversation language.

## Status lifecycle

`proposed` → `accepted` (or `rejected`) → `deprecated` → `superseded by ADR-NNNN`.

## Immutability and supersession

- An accepted ADR is NEVER edited. The collection is trustworthy precisely
  because ADR-0007 still says what was true when it was written.
- To change a decision, write a NEW ADR. The only mutation allowed on an
  existing ADR is flipping its `status` to `superseded by ADR-NNNN` and adding
  the back-link.
- Link bidirectionally: the new ADR references the old one and explains the
  change; the old one points forward to the new.

## CLAUDE.md pointer

The skill keeps a lightweight index in the project's `CLAUDE.md`, delimited by
HTML comment markers so it stays out of the loaded context (Claude Code strips
HTML comments before injecting CLAUDE.md, but the skill can still read them on
disk):

```md
<!-- ADR:INDEX:START -->
## Architecture Decision Records

Decisions live in `docs/adr/`. Run `/adr` to record one.

- [0001](docs/adr/0001-slug.md) — Short title [accepted]
- [0002](docs/adr/0002-slug.md) — Short title [accepted]
<!-- ADR:INDEX:END -->
```

The index is updated in place between the markers (never appended twice).
