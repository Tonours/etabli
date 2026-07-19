# Implemented: Kimi K3 maximum-effort fallback

## Metadata
- Archived: 2026-07-19
- Source plan: Replace the Pi multi-model fallback with Kimi K3 at maximum effort
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome
- Replaced the Etabli fallback role from `opencode-go/kimi-k2.6` at `high` to official `kimi-coding/k3` at Pi `xhigh`, mapped to Kimi `max`.
- Added K3 as a custom model on Pi's built-in Kimi Coding transport because Pi 0.80.5 did not yet expose it in the built-in registry.
- Deployed the model and role locally while preserving the user's primary defaults: `kimi-coding/kimi-for-coding/high`.
- Kept single-agent execution as the ambient default; K3 is only the degraded fallback for an explicitly requested multi-model panel.

## Context
- `https://www.kimi.com/code/docs/en/`: official API model ID `k3` and Kimi Coding endpoints.
- `https://www.kimi.com/code/docs/en/third-party-tools/other-coding-agents`: official `low` / `high` / `max` effort tiers and `xhigh -> max` mapping.
- `pi/models.json`: pinned 256k context and 32k output rather than claiming the unverified 1M membership entitlement.
- `/Users/tonours/.pi/agent/settings.json.bak.20260719-150001`: recoverable pre-deployment Pi settings backup.

## Decisions
### Use the official K3 ID through the built-in Kimi Coding transport
- Context: K3 was released on 2026-07-16, but the installed Pi registry only listed K2 models.
- Choice: add `kimi-coding/k3` with explicit Anthropic transport, endpoint, user agent, limits, and thinking map.
- Rejected options: relabel K2.7 as K3; invent `opencode-go/kimi-k3`; wait for a future Pi registry refresh.
- Rationale: the official Kimi API accepts `k3`, and Pi custom models can extend a built-in provider without changing stored authentication.
- Consequences: the custom entry should be re-evaluated when Pi ships a native K3 definition.

### Prevent silent downgrade to K2.6
- Context: Kimi documents that disabling thinking can route K3 requests to K2.6.
- Choice: mark Pi `off` and `minimal` as unsupported, use `xhigh -> max`, and require exact runtime provenance plus thinking evidence on both probe turns.
- Rejected options: allow every Pi effort level; trust the requested model name without runtime evidence.
- Rationale: fallback status must be explicit and cannot hide a provider-side model substitution.
- Consequences: any missing thinking block, provider error, or model mismatch is `blocked`.

### Preserve personal defaults and keep 1M out of scope
- Context: K3 access and context limits depend on membership, while the user's ordinary Pi default remains K2.7.
- Choice: add K3 to managed enabled models without changing `defaultProvider`, `defaultModel`, or `defaultThinkingLevel`; advertise 262144 context only.
- Rejected options: make K3 the daily primary model; claim 1M from a small authenticated request.
- Rationale: the requested change concerns the panel fallback, not the user's ordinary model or billing tier.
- Consequences: 1M remains unverified; local K2.x entries may remain user-selectable but are not the Etabli fallback.

## Accepted Drift
- Original plan/spec: the first real probe treated every generic `Agent` helper as a multi-model panel sidecar.
- Implemented reality: panel assertions count only the five named Etabli portfolio roles.
- Why accepted: Luna legitimately used a generic helper for bounded obvault retrieval; filtering by exact panel roles preserves the no-automatic-panel invariant without conflating unrelated knowledge retrieval.

## Validation Evidence
- `bun test pi/extensions/__tests__/model-portfolio-config.test.ts pi/extensions/__tests__/settings-consistency.test.ts`:
  - result: 9 passed, 0 failed.
- `bash tests/deploy-agent-workflow-smoke.sh && bash tests/workflow-event-smoke.sh && bash tests/install-smoke.sh`:
  - result: all passed; K3 propagation, user defaults, idempotence, K3 event acceptance, and K2.6 event rejection verified.
- `PI_BIN=/Users/tonours/.asdf/installs/nodejs/24.6.0/bin/pi RUN_REAL_MULTI_MODEL=1 bash tests/multi-model-real-smoke.sh --probe-only`:
  - result: exact K3 provenance in 13877 ms; two thinking turns; nonce preserved; explicit panel 2 roles; ordinary/trivial portfolio panels 0.
- `scripts/verify-agentic-infra all`:
  - result: all groups passed; 211 Pi tests, 0 failures, 556 expectations; router 32/32.
- `git diff --check`:
  - result: passed.
- Fresh-context Terra review `/root/terra_k3_final_review`:
  - result: `GO`, no actionable findings.
- GLM-5.2 xhigh K3-only code-diff adversary:
  - result: `GO WITH NOTES`; no accepted finding.

## Follow-up State
- Remaining risks: K3 runtime proof expires after seven days; 1M context entitlement is unverified; a future Pi release may make the custom entry redundant.
- Parking lot: re-probe K3 after Pi/provider upgrades or membership changes.
- Superseded docs/specs: the K2.6 fallback decision in `docs/plan/20260719-multi-model-execution-evaluation.md` is historical and superseded by this archive.
- Next links: `workflow/skills/multi-model-orchestration.md`, `pi/models.json`, `tests/multi-model-real-smoke.mjs`.
