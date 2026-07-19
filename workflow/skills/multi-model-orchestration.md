# Adaptive Multi-Model Orchestration

This is the bounded adaptive Etabli profile for eligible work. It refines an
existing route; it is not a new route or an ambient pi-workflow graph. Ordinary
work remains parent-only, while narrow deterministic signals escalate to one
scout or a two-agent council. This preserves the 2026-07-19 blind quality gate,
which rejected automatic full panels after four of six repetitions exceeded
4x baseline latency without a quality gain.

## Selection

| Work shape | Execution |
| --- | --- |
| Ineligible route, no signal, or explicit opt-out | Parent only |
| One medium signal on planning/architecture work | Terra scout |
| One medium signal on research/diagnosis/review work | Luna scout |
| One critical signal or two distinct medium signals | Route-specific two-agent council |
| Explicit multi-model intent on an eligible route | Route-specific two-agent council |
| Primary role unavailable | Kimi K3 at maximum effort may replace it on Pi, with `degraded` status |
| Material disagreement after deterministic checks and one rebuttal round | Sol adjudicates once |
| Mutation | Parent is the only writer |

Eligible routes are `plan-loop`, `plan-implement`, `implement`, `spec-guide`,
`linear-work`, `adversary`, `bug-check`, `review`, `pr-review`, `pr-qa`,
`sec-pr`, and `research-plan`. Verification, CI repair, simple answers, and
sensitive or externally mutating routes are always parent-only. On
implementation routes sidecars are limited to planning, reconnaissance, and
review. `single-agent`, `agent unique`, `no-panel`, or `sans panel` always opts
out; explicit `multi-model`, `panel`, `cross-model`, or `plusieurs agents`
forces the council only on an eligible route.

The accent- and case-insensitive V1 signals are category-deduplicated:

- critical risk scores 2: security, vulnerabilities, auth/authz, race or
  deadlock, concurrency, transaction/atomicity, data loss, destructive
  migration;
- system complexity scores 1: architecture/distributed/cross-module,
  refactor, performance/scalability, API contract;
- uncertainty scores 1: root cause, intermittent/flaky/unclear, trade-off, or
  conflicting evidence;
- literal prompt failure history scores 1: two failures, still failing after
  two attempts, or repeated regression.

Zero stays parent-only, one selects a scout, and two or more selects a council.
The router does not infer hidden history or spend another model call to decide.

## Invariants

- Launch first passes blind: no agent receives another first-pass result.
- A scout is one primary plus at most one replacement, with no resume or judge.
- A council is two primaries, at most one replacement, one resume per admitted
  participant, and one Sol call; delegation depth stays one.
- Give every packet an owned question, evidence format, budget, and stop rule.
- The parent integrates and owns the final verdict; there is no majority vote or
  forced consensus.
- Deterministic checks outrank model judgments. Sol is used only once, after
  fan-in, for material unresolved disagreement or high-risk ambiguity.
- No sidecar writes in the shared worktree. Pi roles enforce this by excluding
  `bash`, `edit`, and `write`. Current Codex children inherit the parent's
  filesystem posture, so the restriction is contractual and guarded by a
  before/after diff check rather than described as a sandbox.
- A missing role, provider error, silent model fallback, or missing provenance
  produces `degraded` or `blocked`, never an unqualified panel success.
- Do not rebroadcast full transcripts, perform all-to-all rankings, recurse,
  or force consensus. Rebuttals receive at most six anonymized material claim
  IDs with evidence references.
- Structural call and round caps are enforced by the Pi router. Output caps are
  requested and measured after completion: scout 600; council first pass 900
  per agent, rebuttal 350 per agent, Sol 650, and 3,500 total. An overage cannot
  produce an accepted protocol-v2 event.
- Do not terminate a model solely because of elapsed wall-clock time. Record
  elapsed time as telemetry, while structural turn/call caps, explicit user
  cancellation, provider errors, and the workflow no-progress rule remain the
  stop mechanisms.

## Runtime Portfolios

Pi uses exact pinned roles:

- `etabli-luna-scout`: `openai-codex/gpt-5.6-luna`, `medium`;
- `etabli-terra-analyst`: `openai-codex/gpt-5.6-terra`, `high`;
- `etabli-glm-challenger`: `zai/glm-5.2`, `xhigh` (provider `max`);
- `etabli-sol-judge`: `openai-codex/gpt-5.6-sol`, `xhigh`;
- `etabli-kimi-fallback`: `kimi-coding/k3`, `xhigh` (provider `max`), fallback only.

Kimi K3 is supplied as a custom model on Pi's built-in `kimi-coding` transport.
Its official API ID is `k3`; thinking `off` and `minimal` are disabled because
the provider may otherwise route to K2.6. Exact runtime provenance, thinking
evidence, and the isolated multi-turn probe are mandatory; any mismatch is
`blocked`, never a silent downgrade.
Official contract: https://www.kimi.com/code/docs/en/third-party-tools/other-coding-agents.

Codex uses direct `spawn_agent` model and reasoning overrides from the active
collaboration surface. Terra and Sol are current supported tiers. Luna is used
only when a live spawn returns Luna provenance; otherwise it is `blocked`.
GLM/Kimi remain Pi-only until Codex has a proven Responses-compatible transport
and user-owned authentication. Sol, Terra, and Luna are one provider family and
must not be treated as three independent votes.

## Pi Execution

For a council, issue both `Agent` background calls in the same assistant turn,
then wait for each id with `get_subagent_result(wait=true)`. Normalize no more
than six material claims. Stop on agreement or deterministic resolution. Only
when material disagreement remains, resume each exact original id once with
the compact opposing claim packet. Sol sees only the resulting dispute ledger.
`TaskExecute` is for tracked DAG work, not short council fan-out/fan-in. Etabli
portfolio roles and exact portfolio-model overrides are rejected on
`TaskCreate`, `TaskUpdate`, and `TaskExecute`; use the guarded `Agent` surface.
Direct Agent success does not prove TaskExecute stop/tracking semantics.

Each result packet must state observed facts, findings, unknowns, confidence,
and verdict. The parent records accepted/rejected findings and any fallback.

## Evidence Event

Record a `multi_execution_completed` event when the run has a ledger. Its detail
may use the historical shape or protocol v2. Protocol v2 contains:

```json
{
  "protocol_version": 2,
  "participants": [{"id":"agent-id","model":"provider/model","family":"provider-family"}],
  "independent_first_passes": true,
  "disagreement": false,
  "adjudicator": null,
  "verdict": "accepted",
  "trigger": "adaptive",
  "strategy": "council",
  "signals": ["critical-risk"],
  "rounds": {"first_pass":1,"rebuttal":0,"adjudication":0},
  "claim_count": 2,
  "disagreement_count": 0,
  "stop_reason": "agreement",
  "budget": {"max_claims":6,"first_pass_output_tokens":1800,"rebuttal_output_tokens":700,"adjudication_output_tokens":650,"total_output_tokens":3500},
  "stage_usage": {"first_pass":{"measured":false},"rebuttal":{"measured":false},"adjudication":{"measured":false}},
  "usage": {"measured": true, "input_tokens": 1, "output_tokens": 1, "total_tokens": 2, "elapsed_ms": 1},
  "fallback_status": "none"
}
```

Model/provider fields come from runtime evidence, not agent self-report.
