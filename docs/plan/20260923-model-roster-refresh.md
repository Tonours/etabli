# Implemented: model roster refreshed for Opus 5.5, grok-4.7 and Kimi on opencode-go

## Metadata
- Archived: 2026-09-23
- Source plan: `PLAN.md` — refresh the model roster: Opus 5.5, grok-4.7, Kimi on opencode-go, and newer releases
- Source plan SHA-256: `66bef534db8e8f02c92cedec0a5178b47cebfe5a52bca0486f9f2b1acf191a11`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main` (together with `docs/plan/20260923-opus-5-5-routes.md`)
- Workflow initiative: `model-roster-refresh`

## Outcome
- Frontier pool (`workflow/runtime/adversary-model-policy.json`):
  - xai is now `grok-4.7`, with routes `grok: grok-4.7` (direct, listed first) and `pi: opencode-go/grok-4.7`;
  - moonshot `kimi-k3` is routed through `opencode-go/kimi-k3`;
  - anthropic is `claude-opus-5-5`.
- Pi roster (`pi/agent/settings.json`):
  - Opus 5.5, Fable 5.1 and `grok-4.7` through Cursor;
  - `grok-4.7` and `kimi-k3` through opencode-go;
  - GPT-6 `astra`, `sol` and `luna` through openai-codex;
  - `mimo-v2.6-pro` and `deepseek-v4.1-flash`.
- Pi Explore subagent (`pi/agents/Explore.md`) now uses `opencode-go/deepseek-v4.1-flash`.
- Kimi subscription removal:
  - the custom `kimi-coding` provider is removed from `pi/models.json`;
  - `kimi-coding/k3` is pruned from local settings on install and on deploy.
- The fallback list in `claude/scopes/shared/commands/adversary.md` is updated.
- Claude subagents are unchanged: they use aliases, so `opus` means Opus 5.5 and `fable` means Fable 5.1.

## Context
- `pi update --models` refreshed every catalogue except xai, which fails with `invalid_grant`.
- `grok models` lists `grok-4.7` as the default but reports "not authenticated". Both direct xAI routes need a re-auth.
- `workflow-event-detail.jq` maps `opencode-go/*` participants to family `opencode-go`, so Kimi and Grok through opencode-go record under that family.

## Decisions
### Route Grok 4.7 through verified routes only
- Context: the xAI catalogue cannot be refreshed while OAuth is invalid.
- Choice: the policy uses the grok harness (direct) and `opencode-go/grok-4.7` (catalogue-verified). `xai/grok-4.6` and `xai/grok-4.5` stay enabled; no `xai/grok-4.7` is added.
- Rejected options: adding `xai/grok-4.7`, which cannot be verified.
- Rationale: every added id must be catalogue-listed. `prefer_direct_provider_route` has no runtime consumer.
- Consequences: after an xAI re-auth, a follow-up can add `xai/grok-4.7` and retire the `xai/grok-4.6` and `4.5` entries.

### Keep historical vocabulary
- Context: the `kimi-coding` family and ADR-0011 name the old route.
- Choice: keep `workflow-event-detail.jq` `kimi-coding` and ADR-0011 unchanged.
- Rationale: historical ledgers must keep validating, and accepted ADRs are records.
- Consequences: dead-but-harmless vocabulary.

## Accepted Drift
- Original plan/spec: `xai/grok-4.6` becomes `xai/grok-4.7`, and only `installLegacyModels` is pruned.
- Implemented reality: `xai/grok-4.7` is dropped as unverifiable (plan adversary), then added after the xAI re-auth (see Follow-up State), and `deployLegacyModels` also prunes `kimi-coding/k3` (code adversary). The xai routes are reordered, direct first.
- Why accepted: honesty of verified ids, and no dangling local id after the provider removal.

## Validation Evidence
- `cd pi && bun test ./extensions/__tests__/settings-consistency.test.ts`: 6/6. The new assertions failed before the change.
- `bash tests/workflow-docs-smoke.sh` and `bash tests/deploy-agent-workflow-smoke.sh`: pass.
- Catalogue: all 12 new ids are listed in `pi --list-models`, and `grok models` lists `grok-4.7`.
- `env -u TYPESAFE_API_KEY scripts/verify-agentic-infra core`: 22/22 after the review fixes.
- Reviews, all same-family: plan adversary (fable) GO WITH NOTES; reviewer (sonnet) GO, then GO WITH NOTES; code-diff adversary (fable) GO WITH NOTES, twice.
- Event ledger `.workflow/model-roster-refresh/events.jsonl`, validated with `--profile autonomous-completed`.

## Follow-up State
- Applied 2026-09-23 after the user re-authenticated xAI (Pi) and the grok CLI:
  - `pi update --models` now lists `xai/grok-4.7`, and `grok models` reports logged in;
  - `xai/grok-4.6` became `xai/grok-4.7` in `enabledModels`;
  - the policy xai routes are grok, then `pi: xai/grok-4.7` (direct), then `pi: opencode-go/grok-4.7` (fallback);
  - the `adversary.md` fallback names `xai/grok-4.7`;
  - tests assert `xai/grok-4.7` present and `xai/grok-4.6` absent (red, then green);
  - `core` 22/22.
- Remaining risks: the new routes are catalogue-listed but not exercised live.
- Parking lot:
  - `HARNESS_GROK_MODEL` (`scripts/lib/etabli-harness-eval.sh:8`) and `docs/harness-eval.md` to grok-4.7, in plan C (the evaluator sha is frozen).
  - The Cursor IDE Task model name (`review.md:34`, `pr-review.md:53`, `workflow-docs-smoke.sh:568`).
  - Pruning older roster entries (gpt-5.x, mimo-v2.5, xai/grok-4.5).
- Superseded docs/specs: none.
- Next links: `workflow/runtime/adversary-model-policy.json`, `pi/agent/settings.json`.
