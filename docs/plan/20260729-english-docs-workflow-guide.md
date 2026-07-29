# PLAN.md

## Meta
- Subject: English README rewrite, docs hygiene, workflow schema guide
- Status: IMPLEMENTED (archived)
- Last revised: 2026-07-29
- Archive: pending

## Goal

Public-accurate English README; honest docs inventory; `docs/workflow-guide.md`
with diagrams; no zombie operational docs for removed surfaces.

## Workflow Contract
- Route: plan-implement
- Pattern: direct
- Role: implementer
- Goal verifier: workflow-docs-smoke + validate-adrs + link checks + adversary GO
- Budget: 6 slices
- Stop condition: validation criteria in goal
- Required evidence: scratch logs + green smokes

## Acceptance Criteria
- README English + smoke pins preserved
- docs hygiene complete
- workflow-guide.md with ≥4 diagrams
- validate-adrs 0; workflow-docs-smoke 0
- PLAN archived

## Scope
### In
README, docs/** operational hygiene, workflow-guide, light AGENTS links

### Out
workflow/spec semantics rewrite; plan archive rewrites; commit/push unless asked

## Facts And Assumptions
### Observed Facts
- workflow-docs-smoke pins many README substrings
- no codex/ or nvim config/review on disk
- plan/README already archive notice

### Assumptions
- Prefer banner over delete when smoke may reference; delete only unreferenced mengto analysis

## Steps
1. Inventory baseline (done)
2. README rewrite
3. Hygiene
4. workflow-guide
5. links + smokes + archive

## Adversary
No High blockers for docs-only; smoke constraints known; READY.

## Implementation archive stamp
- Status: IMPLEMENTED
- Date: 2026-07-29
- Evidence: tests/workflow-docs-smoke.sh exit 0; validate-adrs 0; docs/workflow-guide.md

- Post-archive fix: docs/cross-project-research-grounding.md Pi+Claude only (ADR-0011); smoke re-green.
