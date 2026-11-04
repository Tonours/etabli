# Implemented: etabli README and guides rewritten to match the repo

## Metadata
- Archived: 2026-11-04
- Source plan: `PLAN.md` — Rewrite the etabli README and guides so they match the repo at 645f1687
- Source plan SHA-256: `db6c7da2bf0837c564ca382cae874338b42e26e7f865078fc3a9e7f907fda9ad`
- Status: IMPLEMENTED
- Commit / branch: `main`, d9c20afa
- Workflow initiative: none

## Outcome
- Rewritten in English, write-direct voice, employer-docs-writing rules transposed: `README.md`, `SECURITY.md`, `docs/symlink-layout.md`, `docs/mcp-strategy.md`, `docs/plan/README.md`, `claude/README.md`, `extras/README.md`, `vendor/README.md`.
- Stale claims fixed: three guards (pr-body now checks commits), no-comments exemptions, install steps, CI jobs, `deploy-hosts` and `prs-today`, Claude settings merge rule, move-aside versus rotated backups, vendor restore commit, discard records in `docs/plan/`.
- `claude/README.md` lost its rollout residue and keeps the unverified external-validator caveat.

## Context
- `docs/adr/README.md` stays untouched: `skills/shared/adr/scripts/apply-adr.mjs` regenerates its title and intro.
- Headings cited by name elsewhere are kept: `docs/mcp-strategy.md` § Linear MCP gap, `claude/README.md` § Hooks and § Scopes, `SECURITY.md` § Secret-scan policy.

## Decisions
### English, voice transposed
- Context: write-direct defaults to French.
- Choice: English (owner answer), write-direct rules applied in English.
- Rejected options: French docs.
- Rationale: the repo, its code and its contracts are English.
- Consequences: none.

## Accepted Drift
- Original plan/spec: nine files, ADR index intro included.
- Implemented reality: eight files; the ADR index is generated.
- Why accepted: plan adversary finding; a hand edit would be overwritten by the next `/adr`.

## Validation Evidence
- command: `scripts/verify-agentic-infra full`
  - result: 45/45 on the final diff
- command: `node scripts/validate-adrs .`, link and path check, heading and banned-word checks
  - result: pass
- command: reviews
  - result: plan adversary CHALLENGED (8 deltas applied); Spec reviewer GO WITH NOTES (fixed); codex diff pass BLOCK, 15 findings fixed

## Follow-up State
- Remaining risks: the 15 codex fixes shipped without a third cross-model pass (budget).
- Parking lot: none.
- Superseded docs/specs: none.
- Next links: none.
