# Packet H1: helper scope

## Deterministic helper should own
- Pre-existing integrity check before mutation.
- Next ADR number from `max(existing) + 1`.
- Slug generation and file path.
- Accepted ADR frontmatter.
- `supersedes` on the new ADR when supplied.
- `status: superseded by ADR-NNNN` and `superseded_by` on the old ADR.
- `CLAUDE.md` index creation, append, or in-place replacement.
- Post-write validation and rollback on failure.

## Claude should keep
- Whether the decision deserves an ADR.
- The title and short body.
- Whether supersession is grounded by a local ADR.
- Whether to ask the user when supersession is uncertain.

## Non-goals
- Automatic semantic supersession detection.
- Heavy ADR templates.
- Runtime retrieval/indexing beyond the lightweight `CLAUDE.md` pointer.
