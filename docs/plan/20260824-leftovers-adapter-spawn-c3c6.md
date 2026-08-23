# 2026-08-24 — Leftovers: adapter plan-noun, spawn argv markers, C3/C6 slice 1

Distilled archive of the root plan (terminal handoff via plan-cleanup). Tier: high-risk (installer + deploy touched). Source: 20260823-ratified-decisions.md § Known limits + delegated C3/C6 scoping decision.

## What shipped

1. **Adapter plan-status fallback** — `promptPlanStatusFallback` maps draft/challenged only when a plan NOUN co-occurs with the status word. The plan-noun regex excludes the English verb ("We plan to fix…") and compound tokens (`plan-implement.md`), so ordinary wording no longer resumes a plan cycle; statuses cover `brouillon`, plural `bloqués/bloquées`, `challengé(e)(s)`, `blocked`. Four extension tests pin the boundary (non-plan draft mention, plan-tied draft, plural blocked, plan-verb/compound). Documented residual: co-occurrence is an approximation (proximity parsing deliberately rejected as brittle); mentioning the `plan-implement` token still invokes the route via the classifier's autonomous pattern — intended, distinct mechanism.
2. **Spawn argv markers** — `harness_require_spawn_evidence` now requires ONE log line carrying both hunter argv markers (`--no-session` + `--append-system-prompt`, either order): a generic forged line fails. Negative smoke case added; ceiling rewritten in docs (falsification requires knowing the contract argv; same-user POSIX cannot close this without OS sandboxing — load-bearing cells don't depend on it).
3. **C3 slice 1 — models policy unified** — `deploy-agent-workflow` reads managed models from tracked `pi/agent/settings.json` `enabledModels`; the divergent hardcoded 5-model roster is deleted. Deploy smoke green under the tracked policy.
4. **C6 slice 1 — strict mode + ADR-0018** — `install-main.sh` under `set -euo pipefail`; the two degraded network pipelines (lazygit version fetch, node package listing) explicitly guarded `|| true` (hunter finding: pipefail made their coded fallbacks unreachable). **ADR-0018** (indexed in CLAUDE.md): one policy per fact, delegate-not-duplicate, slice 2 (shared lib for deployer+checker, installer delegates agent convergence) deferred with entry criteria = next structural touch.

## Evidence

- `verify-agentic-infra full`: **69/69**. Router accuracy=1/alignment=1. Pi tests 242/242. harness/deploy/install/fix-links/adr smokes green.
- simplify: clean (net deletions: roster, dead Set, dual greps). quality: clean.
- Logic hunter: 1 medium (pipefail lazygit) + 3 low folded (node pipeline, plural pattern, dead Set + ADR index registration). Spec hunter: medium ADR-index folded; co-occurrence approximation documented in code; formatter churn noted (pi-lens autofix, unavoidable).
- Adversary cross-model (grok-4.6): GO WITH NOTES — major (plan-noun verb/compound) + 2 minors folded (challengé/blocked forms, single-line marker requirement); re-validated 69/69.

## Known limits (open)

- Adapter: co-occurrence approximation (documented); `plan-implement` token invocation is classifier-intended.
- Spawn evidence: contract-aware forgery still possible (documented ceiling).
- ADR-0018 slice 2: shared surface lib + installer delegation — entry criteria recorded in the ADR.
