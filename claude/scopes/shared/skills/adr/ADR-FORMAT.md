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
- Parallel branches can still choose the same next number. That is a merge-time
  collision, not something the writer can prevent perfectly. Run
  `node scripts/validate-adrs` when available; duplicate numbers must be fixed
  by renumbering the newer ADR and updating links/indexes before merge.
- `slug` is a short kebab-case summary of the title. On collision, append a
  short disambiguator.

## Minimal template

```md
---
status: accepted
date: YYYY-MM-DD
---

# {Short title of the decision}

{1-3 sentences: the context, what was decided, and why. State the accepted
cost and the rejected alternatives when the rejection is non-obvious.}
```

That is the whole required template. An ADR can be a single paragraph. Add
optional frontmatter and sections ONLY when they carry value:

- `## Considered Options` — the alternatives weighed.
- `## Consequences` — `Good, because …` / `Bad, because …`.
- `supersedes` / `superseded_by` — required only when a supersession exists.
- `tags` — short retrieval categories, e.g. `auth`, `storage`, `deployment`.
- `affected_components` — concrete boundaries or components, e.g. `api`,
  `billing`, `postgres`.

All ADR content is written in English regardless of the conversation language.

## Status lifecycle

`proposed` → `accepted` (or `rejected`) → `deprecated` → `superseded by ADR-NNNN`.

## Immutability and supersession

- An accepted ADR is NEVER edited. The collection is trustworthy precisely
  because ADR-0007 still says what was true when it was written.
- To change a decision, write a NEW ADR. The only mutation allowed on an
  existing ADR is flipping its `status` to `superseded by ADR-NNNN`, adding
  `superseded_by: ADR-NNNN`, and adding the back-link.
- Link bidirectionally: the new ADR references the old one and explains the
  change with `supersedes: ADR-MMMM`; the old one points forward to the new
  with `superseded_by: ADR-NNNN`.
- Do not guess supersession. Read existing ADRs first and cite the local file(s)
  that were considered. If no candidate is grounded in an existing ADR, say
  "No supersession candidate found" and write a standalone ADR.
- If a candidate is plausible but uncertain, ask the user before mutating the
  existing ADR.

## Local grounding before drafting

The ADR directory is the source of truth. Before drafting, build a small
grounding set:

1. Read the `docs/adr/` file list, frontmatter, and titles.
2. Read the latest 3-5 ADRs by number.
3. Search existing ADR titles, tags, affected components, and body text for
   terms from the new decision.
4. Read the full text of any matching candidates before proposing a
   supersession.

In the draft, include a short supersession analysis:

```md
Supersession analysis:
- Considered: ADR-0003 `docs/adr/0003-example.md` — <why it might relate>
- Decision: supersedes ADR-0003 because <evidence>, or no supersession because <evidence>.
```

This analysis is not necessarily copied into the final ADR; it is there to keep
the model grounded and the human approval meaningful.

## The index and the CLAUDE.md pointer

The skill keeps the index in `docs/adr/README.md`, regenerated from the
directory on every write and by `apply-adr.mjs --reindex`:

```md
# Architecture Decision Records

Decisions live in this directory. Run `/adr` to record one.

- [0001](0001-slug.md) — Short title [accepted]
- [0002](0002-slug.md) — Short title [accepted]
```

`CLAUDE.md` carries only a fixed-size pointer to it, delimited by HTML comment
markers. It stays the same length whatever the ADR count, so the always-on
instruction surface does not grow with the decision log:

```md
<!-- ADR:INDEX:START -->
## Architecture Decision Records

Decisions live in `docs/adr/`, indexed in `docs/adr/README.md`. Run `/adr` to record one.
<!-- ADR:INDEX:END -->
```

The pointer is replaced in place between the markers (never appended twice). The
`/adr` skill must still read `docs/adr/` directly when it needs prior decisions.
