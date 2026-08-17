# Implemented: Explicit consent gate for default-branch writes

## Metadata

- Archived: 2026-08-17
- Source plan: `PLAN.md` — Allow exact default-branch operations under explicit user consent
- Source plan SHA-256: `dec6f05b7b616110d8b2ba3c218d9a6386a8211d25e42d8d87ebbbbfc1208ab9`
- Status: IMPLEMENTED
- Commit / branch: `docs/default-branch-consent` (commit pending at archive time)

## Outcome

- Replaced the absolute default-branch write ban with a default-deny consent gate.
- A normal `commit`, `merge`, or `push` is allowed only when the same current user request names the default branch as the write target and names each exact operation.
- Preserved separate safeguards for history rewriting, destructive work, secrets, production, remote protection, and stricter skill contracts.
- Kept `/ship` feature-branch-only; direct default-branch integration remains a separate request.
- Added documentation smoke assertions for target, operation, anti-spoofing, compound-operation, final-check, history, precedence, and `/ship` boundaries.

## Context

- `workflow/git-contract.md` previously prohibited every direct commit or push to the default branch, even after explicit user authorization.
- `workflow/skills/ship.md` independently protects its feature-branch and PR boundary.
- The unrelated untracked `scripts/optimize-fedora-t2-fullstack.sh` was preserved and excluded.

## Decisions

### Require conjunctive same-request consent

- Context: Generic or carried permission could accidentally authorize a high-impact external write.
- Choice: Require the named default branch as write target plus each exact operation word in the same current request.
- Rejected options: Generic “commit and push” consent, synonyms, agent paraphrase, or prior-request consent.
- Rationale: The rule stays default-deny while allowing deliberate user-directed integration.
- Consequences: Compound requests such as “commit and push to main” authorize both named operations; branch-less grants do not.

### Preserve stricter route and history rules

- Context: `/ship`, worktree isolation, remote protection, and history rewriting have independent safeguards.
- Choice: Make the consent gate subordinate to stricter skill contracts and explicitly exclude history-rewriting authorization.
- Rejected options: Relax `/ship`, force-push, rebase, amend, or protection bypass rules.
- Rationale: Normal integration consent must not become broad administrative consent.
- Consequences: `/ship` still stops after feature-branch/PR publication; rejected protected-branch writes stop without bypass.

## Accepted Drift

- Original plan/spec: Generic-consent denial did not distinguish a branch-less grant from an explicit compound request.
- Implemented reality: Clarified branch-less denial and separately authorized every exact operation named with the default write target.
- Why accepted: Fresh review found the original wording had two defensible readings.

- Original plan/spec: Initial smoke pins did not include exact operation vocabulary or synonym exclusions.
- Implemented reality: Added both anti-spoofing assertions.
- Why accepted: Fresh review identified an unguarded future-relaxation path.

## Validation Evidence

- Focused default-branch contract assertions:
  - result: intentional pre-fix failure, then final pass.
- `PATH="/tmp/etabli-prepush-bin:$PATH" bash tests/workflow-docs-smoke.sh`:
  - result: pass.
- `bash tests/workflow-contract-coverage-smoke.sh`:
  - result: pass.
- `PATH="/tmp/etabli-prepush-bin:$PATH" scripts/verify-agentic-infra core`:
  - result: pass; 192 Pi tests and every core smoke group passed.
- `git diff --check` plus Markdown, shell, and LSP diagnostics:
  - result: clean.
- Reviews:
  - result: two independent `zai/glm-5.3` plan adversaries returned `READY`; cumulative review returned `GO WITH NOTES`, both low notes were fixed; final local review found no remaining defect. The last external clean rerun was interrupted and produced no verdict.

## Follow-up State

- Remaining risks: The gate is instruction-level rather than an executable Git guard; remote branch protection remains the external enforcement layer.
- Parking lot: Add runtime Git parsing only if repeated bypass evidence justifies it.
- Superseded docs/specs: None.
- Next links: `workflow/git-contract.md`, `workflow/skills/ship.md`, `tests/workflow-docs-smoke.sh`.
