# P2 Design

## Accepted

- Add optional frontmatter fields: `supersedes`, `superseded_by`, `tags`, and
  `affected_components`.
- Require bidirectional relation fields only when a supersession exists.
- Teach `/adr` to inventory existing ADRs before drafting, read recent ADRs and
  relevant keyword/tag/component matches, then include a supersession analysis
  in the draft.
- Add `scripts/validate-adrs` for duplicate numbers, relation integrity, and
  duplicate CLAUDE.md index markers.
- Add deterministic smoke tests for validator behavior and hook false positives.
- Narrow `auth` and `middleware` hook path regexes to actual path segments or
  filenames.

## Rejected

- Vector DB, MCP server, or embeddings: too heavy for the repo and not needed
  until local keyword/tag/component retrieval fails on a real corpus.
- Mandatory MADR-style sections: conflicts with the "light" requirement.
- Claiming numbering cannot collide: false with parallel branches. Detect and
  repair instead.
- Auto-superseding without explicit user approval: too risky because
  supersession mutates an existing ADR.
