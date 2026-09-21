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
`chooseDecision`—selects
the diagnostic pattern, target, and actionability. The no-change result is an
atomic tuple (`no_material_friction`, `no_change`, `no_op`); mixing any one of
those values with an actionable result is incoherent and therefore abstains.
If any answer is uncertain,
the provider fails, consent is absent, or the observation is ineligible, the
path emits no diagnosis; deterministic code does not substitute one. Optional
execution requires `diagnose-self-improvement --live` and remains private
opt-in. A diagnostic `candidate` means “record for reviewed follow-up”, not
permission to edit or promote anything.

The narrower canary composes correlation, eligibility, and Jev-first request
preparation without writing an observation file:

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
| 2 | `diagnose_shadow` | Jev is the semantic diagnostician; deterministic control plane | native run/session binding, private real-format canary, dedicated held-in/held-out calibration and measured abstention | recurrent verifier-grounded patterns with measured error/abstention; currently blocked |
| 3 | `propose_reviewed` | bounded proposer under a `READY` plan | independent initiatives plus frozen objective and candidate surface | held-in gain, held-out/safety non-regression, fresh review; currently blocked |
| 4 | `promote_automatic` | external isolated controller | frozen base, external root of trust and allow/deny policy, atomic rollback, explicit human authority | reversible applied change plus post-apply verification; currently blocked |

The only forward transitions are level 1 → 2 → 3 → 4; no level may be
skipped. A failed entry or exit condition returns to the previous level or to
`blocked`. Jev never owns mutation authority.

The CLI rejects requests for levels 2–4 with `capability_not_available`. A
same-repository manifest proves provenance, not an independent root of trust.

Ordered follow-up gates are: (1) provider-backed private real-format canaries,
(2) a versioned held-in/held-out corpus for `self-improvement-diagnosis`, (3)
recurrent multi-initiative aggregation, (4) reviewed proposal generation under
a `READY` plan, and only then (5) an external promotion controller with atomic
rollback. The current additive diagnostic path satisfies none of those gates by
itself. The native correlation and offline canary harness are available; the
provider-backed leg remains blocked until a credential is explicitly available,
and level 2 still requires the dedicated corpus and measured abstention.
