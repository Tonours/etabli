---
status: accepted
date: 2026-10-05
tags: [models, routing, subscriptions, pi, claude]
affected_components: [pi/agent/settings.json, pi/models.json, claude/scopes/shared/agents, scripts/lib/claude-launch.mjs, workflow/runtime/model-routing.json, workflow/runtime/adversary-model-policy.json]
---

# Align model routing with the subscription stack

## Decision

Use [workflow/runtime/model-routing.json](../../workflow/runtime/model-routing.json) as the declarative model registry. Consumers keep their native configuration formats; launch and probe scripts read the registry, and settings, agent, benchmark and workflow smokes reject cross-file drift. The registry is advisory foreground routing, not an automatic multi-agent executor.

| Task | Primary | Escalation |
| --- | --- | --- |
| Broad or risky plan | Claude Code opusplan: Opus 5.5 plans, Sonnet 5.5 executes | Codex Sol 6.1, then Astra |
| Simple plan, volume, tests, docs and commits | Pi Z.ai GLM 5.3; GLM 5.3 Flash for mechanical work | Foreground Claude Sonnet 5.5 after a no_progress event from two failed attempts at the same hypothesis |
| One-shot UI | Official Muse CLI: muse / muse exec with browser subscription login | Codex Sol 6.1 |
| Interactive app or UI polish | Claude Sonnet 5.5 | Codex Sol 6.1, then Astra |
| Hard bug, terminal or CI | Codex Sol 6.1 | Astra |
| Cross-family adversary for GLM author | Codex Sol 6.1 | Astra, then Claude Opus 5.5 |
| Same-family Claude sample | Claude Opus 5.5 | Supplementary only; never counts as cross-family |

Pool eligibility remains in adversary-model-policy.json. The registry's author_family_routes excludes the implementation author's family: Anthropic uses Sol/Astra/GLM, OpenAI uses Opus/GLM, and GLM uses Sol/Astra/Opus. Record effective model provenance; configured_unverified is neither credential nor quota proof. Astra is a stronger escalation and an unavailable-Sol fallback. The initial Sol choice follows the user's cost/quality assessment; no new benchmark claim is made.

## Subscription boundaries

- Claude selections use the official Claude Code CLI, not Anthropic models inside Pi or a Claude-to-Z.ai credential store. Pin Sonnet/Opus 5.5; Fable is removed from active selection. [Anthropic's Fable plan documentation](https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan) checked 2026-10-05 says Fable uses additional credits on Pro. This decision does not attest an individual account's available quota. [Native model configuration](https://code.claude.com/docs/en/model-config) documents opusplan and the component default environment variables. Explicit CLI/env overrides remain supported.
- ChatGPT Plus work uses the native Codex CLI. The optional Pi openai-codex selections are omitted here; catalog registration does not establish terms coverage for third-party subscription OAuth.
- [Z.ai Flash documentation](https://docs.z.ai/guides/vlm/glm-5.3-flash), checked 2026-10-05, lists GLM 5.3 Flash on the Coding Plan. Both GLM IDs use Pi's existing Z.ai coding endpoint, not Claude Pro credentials. Exact registered IDs are catalog-verified; real credential/quota availability remains unverified.
- **Muse subscription is recommended through the official Muse CLI only.** [Meta subscription documentation](https://dev.meta.ai/docs/muse-code/subscriptions), checked 2026-10-05, restricts the subscription credential to Muse Code; separately created API keys incur pay-as-you-go charges. [Authentication documentation](https://dev.meta.ai/docs/muse-code/auth) says an environment API key, then a stored API key, takes precedence over browser login. For subscription work use an existing browser subscription login with no API-key override, e.g. `env -u META_API_KEY muse` or `env -u META_API_KEY muse exec "..."`, and check the CLI's billing/auth indication. Do not change or inspect credentials automatically. The tracked custom Meta provider is labeled pay-as-you-go only and remains outside enabledModels.
- **Pi Meta OAuth is experimental and carries unresolved terms risk.** pi-ai 1.0.3 implements a Muse-subscription login; technical support is not proof of authorization, subscription billing or CGU safety. No Meta OAuth login or request is activated by this change.

## Pi upgrade decision

Keep the repo's Pi 0.84.4 pin. Published package evaluation used npm view/pack without lifecycle scripts: pi-ai 1.0.3 includes the Meta OAuth connector, while coding-agent 1.0.3's changelog has breaking provider/runtime/MCP changes. Existing 0.84.4 already registers GLM 5.3, Flash, Sol 6.1 and Astra. A separate 1.x PR must exercise extension/MCP/session compatibility and retain the terms boundary; access to Muse subscription in Pi is not its acceptance criterion. No global runtime is installed or modified here.

## Observed evidence and consequences

- Codex CLI 0.160.0 refreshed catalog dated 2026-10-05 lists gpt-6.1-sol and gpt-6-astra. Pi 0.84.4 --list-models gpt-6 lists both under openai-codex; they are registered but disabled in the tracked Pi scope.
- Isolated Pi 0.84.4 --list-models glm-5.3, with a dummy ZAI_API_KEY solely for catalog visibility, lists zai/glm-5.3 and zai/glm-5.3-flash. No model request is made and the dummy value proves no authentication.
- Official Muse CLI 1.4.2-R4684.1 passes --version and exec --help with updates disabled. No subscription call is tested.
- Tracked Pi scope has two Z.ai models. Convergence removes exact previously managed IDs from the registry's retired_pi_models, preserves unrelated custom selections/defaults, and resets a retired managed default to the tracked GLM default. Dry-run remains read-only.
- Active benchmark definitions now use 5.5; historical fixture receipts remain intact. The selected winner and old resolution evidence are invalidated, and a fresh calibration is required. No paid benchmark or savings claim is produced.

The benchmark baseline mirrors current agent model/effort/turn limits, including the existing Sonnet reviewer. Candidate B uses a Sonnet low-effort core and Opus adversary so every arm passes the existing different-model check. These within-Anthropic comparisons do not satisfy workflow cross-provider independence. The declaration records the base Git revision; invariant hashes refer to the modified working/committed tree. Native Sonnet 5.5 requires Claude CLI 2.1.284 per the model configuration documentation; 2.1.289 was observed here. Old winner text and resolutions are cleared.
