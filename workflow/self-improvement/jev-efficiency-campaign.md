# Jev efficiency campaign

`scripts/jev-efficiency-campaign` is the read-only measurement and progression
controller for Jev-first self-improvement experiments. It never calls a
provider, edits a candidate, changes `PLAN.md`, promotes a result, rolls back a
change, publishes, or deploys.

## Evidence boundary

The checked-in manifest is a frozen public structural inventory, not a sealed
or confidential benchmark. Raw prompts, traces, provider receipts, grader
details, and arm results stay under the ignored private campaign directory.
Only opaque fingerprints and aggregate comparison receipts may enter Git.

The baseline must be collected with `candidate_enabled: false` before any live
candidate is enabled. Baseline and candidate bind the same private population,
evaluator bundle, runner, provider, model, effort, and runtime fingerprint.
Missing token usage makes the comparison non-comparable. A provider that emits
complete token receipts but no trustworthy price records `cost_status:
unavailable` and `cost_usd: null`; unknown cost is never replaced by zero or an
estimate.

## Authority

- Jev produces eligible typed diagnoses and may abstain.
- The controller emits one next obligation from supplied evidence.
- `skill-eval` remains the quality/safety transition authority.
- Deterministic code owns protected routes, budgets, provider checkpoints,
  READY/adversary gates, comparison, rollback obligations, and completion.
- Humans retain provider/billing authorization and every separately protected
  external action.

## Comparison

```bash
scripts/jev-efficiency-campaign compare \
  --manifest workflow/self-improvement/jev-efficiency-manifest.json \
  --baseline .workflow/jev-autonomous-efficiency/private/baseline.json \
  --candidate .workflow/jev-autonomous-efficiency/private/candidate.json \
  --baseline-artifact .workflow/jev-autonomous-efficiency/private/baseline-artifact \
  --candidate-artifact .workflow/jev-autonomous-efficiency/private/candidate-artifact
```

Acceptance requires three ordered repetitions, stable pass vectors, no
baseline-pass to candidate-fail transition, every protected task passing, no
Jev retry, complete provider receipts, and at least 30% traditional-LLM token
savings in every repetition. Jev calls, tokens, cost, latency, abstentions, and
escalations are reported separately so cost cannot be hidden by shifting it.

`next --manifest ... --state ...` reports the next obligation. `rollback_required`
is an instruction to the ordinary READY-gated workflow, never a mutation by
the controller itself.

`rank-offline --manifest ... --input ...` accepts one to four synthetic-only
hypotheses. It rejects retries, installed-runtime activation, incomplete task
populations, unsafe fallbacks, and protected-route failures. Its ranking is a
pre-provider prioritization aid and always carries
`offline_only_no_runtime_savings_claim`; it cannot select or promote the live
candidate before the candidate-off baseline exists.

`validate-population --manifest ... --population ...` freezes the ignored
validation population against the public manifest and current reusable harness
artifacts. It rejects category/split drift, stale artifact fingerprints,
unsupported graders, unsafe paths, and secret-like inline prompts. The
validation held-out split is explicitly adaptive and non-sealed; a later final
transfer surface must not reuse it as untouched evidence.

`dry-run-live --manifest ... --population ... --state ... --config ...`
validates the exact candidate-off baseline matrix without executing Pi or any
provider call. The private config must name an explicit provider, model,
thinking effort, timeout, non-negative monetary cap, three repetitions, and
`retry_policy: none`; credential fields are rejected. Until the human
checkpoint is recorded as `authorized`, the result remains non-executable.

The ignored config has this shape; placeholders are deliberately not given
defaults because provider, model, effort, and budget are part of the human
authorization:

```json
{
  "schema_version": 1,
  "arm": "baseline",
  "runner": "pi",
  "provider": "<authorized-provider>",
  "model": "<authorized-model>",
  "effort": "<authorized-effort>",
  "repetitions": 3,
  "timeout_seconds": 600,
  "max_cost_usd": 1,
  "billing_mode": "metered",
  "candidate_enabled": false,
  "retry_policy": "none"
}
```

`billing_mode` is either `metered`, which requires numeric provider cost
telemetry for cap enforcement, or `subscription`, which requires
`max_cost_usd: 0` and preserves missing price telemetry as unavailable.
Before execution, `snapshot-live-artifact --candidate-enabled false` copies the
frozen runtime inventory declared by the manifest into a new ignored private
directory and binds it to the exact manifest hash. The inventory includes Pi
configuration, relevant extensions and skills, the Jev boundary, and deployed
workflow templates; the managed `pi/skills/herdr` symlink is excluded and its
repository source is copied explicitly. The live runner rejects hand-written,
stale, wrong-arm, or inventory-drifted artifacts.
`run-live-baseline` additionally requires the state checkpoint to be
`authorized`, `ETABLI_JEV_EFFICIENCY_LIVE=1`, a non-empty runtime artifact,
and a brand-new output directory below the ignored private campaign root. It
removes `TYPESAFE_API_KEY` from baseline child processes so the baseline cannot
silently make Jev calls before candidate evaluation.
