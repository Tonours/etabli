# Implemented: explicit workflow families and prerequisite/closure checks

## Metadata
- Archived: 2026-10-01
- Source plan: `PLAN.md` — Reduce recurring workflow friction and distinguish runs from work families
- Source plan SHA-256: `5ce3b711e610168f9aac46b18dd8267fff25e13db6f699c68a2f56363ad7bbd4`
- Status: IMPLEMENTED
- Commit / branch: local workspace changes; no commit, push or deployment
- Workflow initiative: workflow-pattern-followup
- Tier: high-risk; cross-family native adversary and fresh Logic/Spec required

## Outcome
- The existing reporter retains raw initiative/observation counts and adds project-scoped explicit family groups, unmapped coverage, planning phases and evidence-backed recorded-completed-successor links.
- `docs/workflow-run-lineage.json` maps the verified Lean Context T4, project-vault recovery and contract-coherence chains. Historical blockage records stay intact. Contract-coherence has no resolution assertion because its archive retains the Herdr incident gap.
- `scripts/workflow-run-check preflight` checks fixed tools and actual Pi dependency availability. Optional `--claude-home DIR` reuses the existing hooks checker against DIR/.claude; default live hooks are not checked.
- `scripts/workflow-run-check close --dir PATH SLUG` uses the real workflow-event completion profile on a disposable external copy. It leaves source ledger, active selection, PLAN and archives intact and states `scope: prospective-event-chain`, `archive_checked:false`.
- `docs/workflow-statistics.md` documents report, prerequisites, closure scope and existing shell/Git boundary matrices. Verified implementation; simplify: removed 1 duplicate object predicate by reusing the existing shared helper.

## Context
- Evidence: `.workflow/workflow-pattern-followup/live-report.json` retains 6 review-budget runs but represents them as 4 groups: one mapped family and 3 unmapped runs. Three Lean Context historical blockages have the explicit recorded completed successor.
- Evidence: The same report retains 4 review_requested runs but groups them into one project-vault family; all 4 carry a recorded completed successor. Unknown guard provenance remains separate from initiative recurrence.
- Evidence: `.workflow/lean-context-t4-review4/events.jsonl:28` and `.workflow/delivery-authority-completion/events.jsonl:30` provide terminal successor records. These are recorded workflow statuses, not proof of accepted delivery or verification of every incident.

## Decisions
### Explicit lineage, conservative resolutions
- Choice: An exact versioned per-project registry; separate family/run namespaces; direct links only. Reject structural errors globally; keep valid assignments with unresolved links when successor evidence is missing or invalid.
- Rationale: Repeated attempts should not be mistaken for independent work. Never infer membership from names or narrative. Unmapped groups require independence verification before a candidate mechanical check.
- Consequences: Successors must pass the existing ledger-integrity checker, be final v2 completed with a canonical timestamp strictly after the blockage and no later than report until. Raw history remains visible; no transitive or production-fix claim.

### Reuse runtime resolution and completion validators
- Choice: Native Node import.meta.resolve from pi/extensions, stat only, no package loading. Optional hooks delegate to the existing checker. Prospective close copies only one events.jsonl, then appends archive_written, plan_removed and completed through the real CLI and validates autonomous-completed.
- Rationale: The existing validators remain authoritative. Availability does not prove package behavior; event-chain readiness does not validate a real archive or perform cleanup.
- Consequences: No install, deployment, new parser, event schema or execution policy. Source bytes and pointer are compared after simulation.

## Accepted Drift
- Original plan/spec: Check actual installed dependencies without mutation; preserve wrapper failure semantics.
- Implemented reality: A physical package-directory assumption rejected valid native parent ESM lookup. Parent reproduced it with a failing fixture and used native resolution. T1 native review then found symlinked-parent invocation silently returned success; another red-first fixture reproduced it and pwd -P fixed the wrapper.
- Why accepted: Both are bounded correctness repairs within the frozen availability/exit-code requirements. Checks and review budgets were unchanged.

## Validation Evidence
- command: `node --test tests/workflow-patterns.test.mjs tests/workflow-run-check.test.mjs`
  - result: PASS 33/33 in `.workflow/workflow-pattern-followup/focused.log`; includes lineage/window/grouping, real completion success/refusals/source protection, ESM fallback, scoped hooks and symlink exit-code regression.
- command: `scripts/verify-agentic-infra core`
  - result: PASS 29/29 in `.workflow/workflow-pattern-followup/core.log`, including Pi 444/444, typecheck and reporter smoke with 33/33 Node tests plus guard journal isolation. Existing check membership unchanged.
- command: `bash tests/dual-runtime-guard-matrix-smoke.sh`
  - result: PASS before T1; `.workflow/workflow-pattern-followup/guard-matrix.log`.
- command: `bun test pi/extensions/__tests__/rtk-runtime.test.ts pi/extensions/__tests__/plan-cleanup-command.test.ts pi/extensions/__tests__/project-vault.test.ts`
  - result: PASS 115/115 before T1; `.workflow/workflow-pattern-followup/boundary-matrix.log` covers shell/cleanup and Git identity boundaries. No guard-policy change.
- command: `scripts/workflow-context-budget`
  - result: PASS 8/8, ceilings unchanged; `.workflow/workflow-pattern-followup/context-budget.log`.
- command: `scripts/workflow-run-check preflight --json`
  - result: ready:true on the real repo; `.workflow/workflow-pattern-followup/live-preflight.json`; live_hooks:not-requested.
- command: `scripts/workflow-run-check close --dir .workflow workflow-pattern-followup --json`
  - result: ready:true, archive_checked:false on the real reviewed ledger; `.workflow/workflow-pattern-followup/prospective-close.json`. The source is not completed by this check.
- Evidence: Parent compared current cumulative bytes with final pin SHA-256 `c34cf84f570a57535de8597fb5dfbca0447603e3050ebe573fd9d5b56cd72584`. T1 findings -> bounded repair -> T2 clean -> F1 clean. Fresh Logic GO with 12 complete independently opened deciding-code rows; fresh Spec no findings; parent Standards pass. Collaboration reviewers inherited Codex; exact model ID unavailable, no invented identity.
- Evidence: Cross-family native Claude Opus 5.5 / firstParty final GO, session `866e44b2-fab5-4d18-870b-921a556e1f58`, receipt `.workflow/workflow-pattern-followup/reviews/F1-adversary.json`; hunters and lead receipts in the same directory. Optional install/coverage expansions were not folded.
- Evidence: Baseline SHA-256 comparison preserved 145 protected old ledger/journal/archive/user-document files, including the prior implemented statistics archive and all 3 unrelated user docs. `git diff --check` passed. Existing quarantined/stale ledger inventory records remain untouched: ledger checker failed=0.

## Follow-up State
- Remaining risks: Explicit membership is a reviewed maintainer assertion. Unmapped runs are not proven independent. Recorded successor completion is not incident-level verification or accepted delivery. Validation failure events include intentional red-first checks and are not a failure rate.
- Remaining risks: Conservative fixed phrases/exact fingerprints retain previous semantic and legacy coverage limits. Guards lack trusted initiative/origin metadata. Preflight proves availability only; optional live hooks need an explicit home. Prospective close does not check actual archive quality/hash or source cleanup.
- Parking lot: Additional family mappings only with reviewed source evidence; script-file symlink installation is unsupported and fails loudly, unlike the repaired directory-symlink path.
- Next links: `docs/workflow-statistics.md`, `docs/workflow-run-lineage.json`; canonical actual closure evidence is `.workflow/workflow-pattern-followup/events.jsonl`.
- Archive state: This exact-hash implementation record follows completed review and pre-archive validation; sanctioned plan-cleanup and actual terminal autonomous-completed validation follow. No commit, push or deployment authorized.
