# Implemented: subscription model routing

## Metadata
- Archived: 2026-10-05
- Source plan: `PLAN.md` — subscription model routing
- Source plan SHA-256: `5cd622f971f82464a4684e5cfea6fc81762d7e367dbe74cf173ee59bf0e245ca`
- Status: IMPLEMENTED
- Branch: `chore/subscription-routing`, base `5d45f904e488d1073f52dec93924ebcda49ad8ce`
- Workflow initiative: `model-routing-20261005`
- Approved plan contract: `74da0744bc7e81d8c97156c2dcc58b2704757a61b0d0a1891362fa766dd92f0d`

## Outcome
- Pi default remains GLM 5.3, with GLM 5.3 Flash as the only other tracked enabled model.
- Worker, scout and reviewer use Sonnet 5.5; the Claude adversary uses Opus 5.5. Deep mode uses opusplan with 5.5 components and preserves nonempty explicit overrides.
- A declarative registry records the seven task routes. The three-family adversary pool uses native Codex Sol first with Astra escalation, Claude Opus and Pi GLM; effective family provenance remains mandatory.
- Exact previously managed IDs are retired in both deployment modes. Custom selections/defaults remain; newly retired managed defaults reset to GLM. Dry-run stays read-only.
- Benchmark baseline/probes now follow live roles, candidate arms remain eligible, and old winner/resolution evidence is invalidated.

## Context and decisions
- [ADR-0029](../adr/0029-subscription-model-routing.md) holds the routing table, subscription boundaries, package evaluation and live catalog observations.
- Keep Pi 0.84.4: GLM/Flash/Sol registrations already exist. Pi 1.0.3 adds Muse OAuth but includes breaking runtime/MCP/provider changes, requiring a separate migration.
- Muse subscription uses the official Muse CLI. Pi OAuth remains disabled and experimental with unresolved terms risk. The custom Meta API provider is labeled pay-as-you-go only; no Anthropic or Meta route is enabled in Pi.
- Native Codex supplies OpenAI work; optional Pi OpenAI OAuth is omitted because catalog registration alone does not establish subscription terms coverage.
- No Claude-to-Z.ai store, global deployment, credentials inspection, subagent activation or paid benchmark was performed.

## Accepted drift and review decisions
- Rebased scope to the existing origin/main state before edits by creating a new local branch, without rewriting published history. The original dirty checkout was preserved and its status/model diff hash rechecked unchanged.
- The benchmark's former Fable baseline reviewer was already stale versus the live Sonnet role. Baseline now matches all model/effort/turn fields; experimental Fable adversaries become Opus 5.5. Candidate B uses a Sonnet low-effort core to preserve the existing different-model check.
- Within-Anthropic benchmark model diversity does not establish cross-provider workflow independence. Full arm configurations include effort, turns and session, so equal model maps are valid comparisons.
- T1/T2 findings were folded: role-derived probes, stale winner note, baseline metadata, harness-specific fallback prose, sweep failure handling, empty env treatment, full route order and negative drift fixtures. Registry loading uses native fs/JSON, preserving Node compatibility.
- Historical legacy-default expansion was rejected: this change resets only the registry's exact newly retired managed IDs, preserving pre-existing unrelated behavior. Separate PR council defaults and optional additional author-family maps remain follow-ups.
- Sol-first follows the explicit user routing preference. The pool is not a new benchmark ranking; generic strongest-pool prose does not prove a contradictory concrete selection.

## Validation evidence
- `bun test pi/extensions/__tests__/settings-consistency.test.ts`: 6/6 pass.
- `bash tests/workflow-docs-smoke.sh`: pass, including consumer/registry mutations and fail-closed sweep errors.
- Claude launch, agents and token-budget smokes: pass; model pins, override forms/empty env and current benchmark eligibility/hash checks covered.
- Contract coherence, deploy/install smokes: pass, including dry-run, idempotence and retired/custom defaults.
- `node --test tests/claude-efficiency-campaign.test.mjs`: 13/13 pass.
- `CI=true scripts/verify-agentic-infra core` with local Pi on PATH: 33/33 pass, including 445 Pi tests.
- Workflow reference, ADR, project-verification and diff checks: pass. Product verification is not required for this configuration change.
- Independent foreground Claude contexts attested native Sonnet 5.5 for Logic/Spec and Opus 5.5 for adversary. T1/T2 findings were reconciled; D1 Logic/Spec is clean. Final commit review belongs to the local ledger.
- Codex refreshed catalog/Pi 0.84.4 lists register Sol 6.1 and Astra. Isolated dummy-key Z.ai catalog lists GLM 5.3 and Flash; it proves no authentication. Muse CLI version/help work, without a subscription call.

## Follow-up state
- Installed-home live guard failed on a pre-existing radius-api package-filter mismatch. CI skips that guard; this archive claims repository fixture/integration success, not installed-profile validation.
- Account credentials/quota remain unverified; route availability stays configured_unverified.
- Fresh benchmark calibration needs separate explicit budget approval; no savings claim survives the model redeclaration.
- Pi 1.x compatibility and Meta subscription terms need a separate assessment before enabling OAuth.
- Draft PR publication requires the user's explicit push approval. No push or merge was performed.
