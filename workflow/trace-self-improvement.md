# Trace-driven self-improvement

`harness-trace-retrospect` is an offline, read-only prototype for inspecting one
explicit Pi or Claude trace alongside one terminal Etabli ledger. It never
discovers live stores and never persists raw trace content.

```bash
scripts/harness-trace-retrospect \
  --adapter pi \
  --trace-file /private/path/session.jsonl \
  --ledger .workflow/example/events.jsonl \
  --run example \
  --capability prototype_offline \
  --json
```

The output follows `workflow/trace-observation.schema.json`. It contains only
allowlisted enums, bounded counters, `null` for unavailable metrics, and a fresh
random observation id. It contains no prompt, command, output, cwd, verifier
text, path, session identifier, or input-derived fingerprint. The explicit file
selection is labelled `explicit_unverified`: it supports observation, not causal
attribution.

Pi also loads `workflow-run-binding.ts`. Once exactly one active non-terminal
ledger is visible, it writes one private custom entry per session/run pair containing only a
domain-separated SHA-256 correlation over the session id, run slug, and
canonical immutable ledger genesis row. The analyzer recomputes that value and
labels an exact, unambiguous match `native_correlated`. This catches accidental
trace/ledger mismatch and cross-ledger replay; it is not authentication against
someone who can edit both private input files. Neither the identifiers nor the
fingerprint appear in the sanitized observation. A reused Pi session may hold
historical bindings; analysis considers only bindings inside the requested
ledger window and rejects duplicates or conflicts within that window.

## Completeness

- `complete`: the supported identity, terminal window, primary rows, tool ids,
  and decision counters are internally consistent;
- `partial`: only a known allowlisted non-decision row was encountered; the
  result is forced to `no_op`;
- `unavailable`: malformed, truncated, capped, unknown, ambiguous, conflicting,
  non-terminal, or mismatched input; no decision or Jev state is emitted.

An unavailable condition wins over partial, which wins over complete. Missing
telemetry is `null`, never a synthetic zero.

## Jev boundary

The prototype builds the two strings required by the existing
`self-improvement-candidate` shadow profile from typed fields. The semantic
profile policy assigns dedicated canonical field types, so
`prepareProfileRequest` rejects arbitrary strings even when callers bypass this
CLI. The command does not contact TypeSafe. A later explicit `jev-judge --live`
call remains private opt-in and shadow-only.

That level-1 tuple is a deterministic compatibility hint, not a semantic
diagnosis. The additive Jev-first path uses the distinct
`self-improvement-diagnosis` profile:

```bash
scripts/harness-trace-retrospect ... --json > /tmp/observation.json
scripts/jev-judge prepare-self-improvement \
  --observation-file /tmp/observation.json
```

Preparation is offline. Before projection it requires the canonical level-1
adapter/version/binding identity, an observation UUID, empty reason codes, and
zero unsupported rows. It then projects only completeness, terminal outcome,
verifier presence, and schema-valid bounded/null counters. Jev—not
`chooseDecision`—answers one Choice question: the primary friction `pattern`.
Deterministic code derives the rest from that accepted pattern: `target` through
a fixed pattern-to-surface map, and `actionability` as `no_op` only for
`no_material_friction` on a completed, verified episode, otherwise
`investigate`. A single episode never yields `candidate`; the contract requires
recurring evidence for that. If the pattern is uncertain, the provider fails,
consent is absent, or the observation is ineligible, the path emits no
diagnosis; deterministic code does not substitute one. Optional execution
requires `diagnose-self-improvement --live` and remains private opt-in. That
explicit probe is ungated and always spends one Jev call.

The narrower canary composes correlation, eligibility, and Jev-first request
preparation without writing an observation file. Like `diagnose-self-improvement`,
it is an explicit probe and bypasses the controller's no-friction gate:

```bash
scripts/jev-judge canary-self-improvement \
  --trace-file /private/path/session.jsonl \
  --ledger .workflow/example/events.jsonl \
  --run example
```

It accepts only a complete `native_correlated` Pi episode. Offline mode returns
a fixed aggregate `prepared` result; `--live` is the only provider-egress path
and never persists a receipt. Missing credentials yield a sanitized abstention,
not model-quality evidence. Paths, ids, run names, trace text, and request or
binding fingerprints are never returned.

## Maturity

| Level | State | Authority | Entry evidence | Exit evidence / availability |
| --- | --- | --- | --- | --- |
| 1 | `observe_prototype` | deterministic read-only extractor | explicit trace and terminal ledger; supported identity shape | sanitized complete/partial/unavailable observation; available as `prototype_offline` |
| 2 | `diagnose_shadow` | Jev is the semantic diagnostician; deterministic control plane | explicit `--live`, native run/session binding, complete terminal observation, retry-disabled provider policy | private terminal `no_op`/`investigate`; available through `scripts/jev-self-improvement` |
| 3 | `propose_reviewed` | bounded non-executable proposal request; READY workflow remains external | synthetic branch suite, three distinct live checks, current controller fingerprint, independent cross-model verification | fingerprint-bound receipt; unavailable until all evidence is current |
| 4 | `promote_automatic` | external isolated controller | frozen base, external root of trust and allow/deny policy, atomic rollback, explicit human authority | reversible applied change plus post-apply verification; currently blocked |

The only forward transitions are level 1 → 2 → 3 → 4; no level may be
skipped. A failed entry or exit condition returns to the previous level or to
`blocked`. Jev never owns mutation authority.

The offline extractor still rejects requests for levels 2–4 with
`capability_not_available`. The separate explicit-live controller implements
level 2 only. It starts in `diagnose_shadow`. A completed episode with
`verifier=true` (latest validations green, no blocking review; an episode that
ran no review still counts)
whose friction counters (`tool_errors`, `validation_failures`, `review_rework`,
`plan_rework`, `compactions`, `retries`) are all 0 or null ends as `no_op` with
reason `no_friction_signals` and zero Jev calls: this is eligibility, not a
diagnosis, so `diagnosis` stays null. Every other episode gets one Jev call with
zero retries. The controller makes no traditional-LLM call, and writes only a new direct child under
ignored `.workflow/jev-self-improvement/private/`. Its provider projection is
limited to lifecycle enums, verifier state, and numeric counters; trace text,
paths, run/session IDs, and fingerprints are not projected. Level 3 additionally
requires a current capability receipt and can emit only a non-executable request
for a later user-invoked READY run. It currently has no producer: single-episode
diagnosis stops at `investigate`, and cross-episode recurrence is not built. A same-repository receipt proves bounded
promotion evidence, not an independent root of trust for automatic mutation.

Ordered follow-up gates after level 2 are: (1) complete the synthetic branch
suite, (2) record three independently selected provider-backed real-format
diagnoses, (3) independently verify the controller and evidence, (4) enable
bounded reviewed proposal packets for the exact fingerprint, and only then (5)
evaluate any external promotion controller with atomic rollback. No current
gate authorizes automatic source mutation, PLAN promotion, commit, push, or
deployment.
