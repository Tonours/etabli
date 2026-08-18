# Implemented: recent commit review repairs and guard hardening

## Metadata

- Archived: 2026-08-17
- Source plan: `PLAN.md` — Review and repair commits from the last 48 hours
- Source plan SHA-256: `a4a5f2dbacb3088740e34993245f843c899d0ba570fe4047f4cf4fd1b0c93849`
- Status: IMPLEMENTED
- Commit / branch: `main` (uncommitted local repair)
- Reviewed range: `76ffb2442dbc1ee8d442dc2ab79f542c95c06728..f1b9eb11b9fec9fa990a47446372945b21587694` (21 commits)

## Outcome

- Completed a per-commit review of the 21 commits from the preceding 48 hours and inspected the full 1,829-line patch.
- Fixed the plan commit guard so only the two tracked root templates are exempt; template-like session artifacts remain denied, while staged template-only commits are allowed.
- Replaced the tracked `brain` MCP server's machine-specific paths with the documented `${HOME}/work/brain` form and added config anti-drift coverage.
- Corrected all checkout annotations to v7.0.1, disabled credential persistence in the three read-only CI jobs, and added supply-chain count parity coverage.
- Preserved the unrelated untracked workstation script and recorded the discarded unrelated root plan separately.

## Context

- `claude/hooks/workflow-router-lib.mjs:171-179,959-1008`: command-token and staged-file guard decisions had drifted because they used different template rules.
- `.mcp.json:4-8` and `mcp/servers.template.json:26-32`: the tracked live config and sanitized template disagreed on portable home resolution.
- `.github/workflows/agentic-infra.yml`: GitHub confirms SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` is checkout v7.0.1; Zizmor found unnecessary credential persistence on the same three changed steps.
- GitHub Actions run `32040842362` was green at reviewed HEAD before the local repair.

## Decisions

### Use one exact template classifier

- Context: command inspection exempted every `PLAN_TEMPLATE*` name, while the staged-file scan still rejected the two real templates.
- Choice: share `isSessionPlanName` between command and staged-file paths, with an exact allowlist for `PLAN_TEMPLATE.md` and `PLAN_TEMPLATE_FULL.md`.
- Rejected options: another negative-lookahead regex; broad exemption for all template-like names.
- Rationale: one resolver removes the observed asymmetry and keeps fail-closed behavior for session artifacts.
- Consequences: nested `sub/PLAN.md` behavior remains the pre-existing root-contract limitation and was not widened.

### Keep tracked MCP config portable

- Context: `.mcp.json` referenced one macOS username while the contract and template use home expansion.
- Choice: use `${HOME}` in both argument and environment paths, with an exact JSON assertion.
- Rejected options: retain a machine-specific tracked path; move live external registration into this change.
- Rationale: matches the documented Claude MCP expansion contract and shared template without touching runtime-local stores.
- Consequences: actual expansion and vault availability remain runtime-owned.

### Harden read-only checkout steps

- Context: checkout comments mislabeled a v7.0.1 SHA as v6; Zizmor then identified persisted credentials that no job uses.
- Choice: correct annotations, set `persist-credentials: false` on all three jobs, and enforce 3/3/3 parity in the supply-chain smoke.
- Rejected options: token workarounds or widening to other workflows.
- Rationale: smallest auditable fix on the changed lines.
- Consequences: future checkout additions must update the parity assertion deliberately.

### Resume after a bounded no-progress stop

- Context: the first ledger retried `workflow-docs-smoke` until it hit the same missing-`shasum` prerequisite twice.
- Choice: terminate that run as blocked and continue under `recent-48h-review-resume1` without rerunning the unavailable full docs suite.
- Rejected options: bypass the ledger or install unrelated host dependencies.
- Rationale: preserves the no-progress contract while changing validation strategy to explicit focused checks.
- Consequences: the local canonical core suite remains unverified; this is reported, not hidden.

## Accepted Drift

- Original plan/spec: repair three initial findings.
- Implemented reality: quality diagnostics added a fourth accepted finding (`artipacked`) and the first code-diff adversary added supply-chain regression coverage.
- Why accepted: both additions stayed on already-reviewed surfaces, strengthened acceptance/checks, and passed cross-model plan/adversary review.

## Validation Evidence

- `bash tests/claude-hooks-smoke.sh`:
  - result: passed after reproducing the pre-fix staged-template failure.
- Focused portable MCP parity assertion plus JSON parsing:
  - result: passed; live and template paths agree on `${HOME}/work/brain`.
- Checkout SHA/comment/credential parity block from `tests/supply-chain-smoke.sh`:
  - result: passed; counts are 3/3/3.
- Focused YAML/Zizmor diagnostics:
  - result: YAML clean; `artipacked` cleared. One unrelated pre-existing `adhoc-packages` warning remains.
- `node --check`, `bash -n`, and `git diff --check`:
  - result: passed on the final diff, including after reverting unrelated deferred autoformat churn.
- `cd pi && bun test ./extensions/__tests__/pi-runtime.test.ts ./extensions/__tests__/settings-consistency.test.ts && bun run verify:skills`:
  - result: 8 tests passed; 79 skill hashes verified.
- Full local `scripts/verify-agentic-infra core`:
  - result: not verified; pre-existing `shasum` and Ruby prerequisites are absent on this Fedora host. The green remote run predates the unpushed repair and is baseline evidence only.

## Review And Adversary Evidence

- Plan adversary: `zai/glm-5.3`, runs `plan-adversary-glm53-20260817T182500Z` and `plan-adversary-glm53-20260817T183000Z` → `READY`.
- Final break-first review: `zai/glm-5.3`, run `fresh-review-final-glm53-20260817T184500Z` → `GO WITH NOTES`; all eight lens rows and five deciding-code rows complete.
- Plan-fit: all strengthened criteria met; nested-path note rejected as pre-existing and outside the root-plan contract.
- Final code-diff adversary: `zai/glm-5.3`, run `code-adversary-final-glm53-20260817T185000Z` → `GO WITH NOTES`; no accepted finding and no blocker.
- `/simplify`: repeated after accepted fixes; no further behavior-preserving simplification remained.
- Quality: `stack-suite` / `node`; no diff-scoped convention finding.

## Follow-up State

- Remaining risks: `${HOME}` expansion is runtime-owned; nested plan paths remain outside the root-plan contract; local full-core validation is still blocked by missing host prerequisites.
- Parking lot: consider portable hash/Ruby test prerequisites in a separate evidence-backed task; consider nested plan-path policy only if a real nested artifact appears.
- Superseded docs/specs: none.
- Next links: `docs/plan/20260817-discarded-unrelated-recent-commit-review.md`, `.workflow/recent-48h-review/events.jsonl`, `.workflow/recent-48h-review-resume1/events.jsonl`.
