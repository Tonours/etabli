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

## Maturity

| Level | State | Authority | Entry evidence | Exit evidence / availability |
| --- | --- | --- | --- | --- |
| 1 | `observe_prototype` | deterministic read-only extractor | explicit trace and terminal ledger; supported identity shape | sanitized complete/partial/unavailable observation; available as `prototype_offline` |
| 2 | `diagnose_shadow` | deterministic policy; Jev shadow only | native run/session binding, private real-format canary, calibrated abstention | recurrent verifier-grounded patterns with measured error/abstention; currently blocked |
| 3 | `propose_reviewed` | bounded proposer under a `READY` plan | independent initiatives plus frozen objective and candidate surface | held-in gain, held-out/safety non-regression, fresh review; currently blocked |
| 4 | `promote_automatic` | external isolated controller | frozen base, external root of trust and allow/deny policy, atomic rollback, explicit human authority | reversible applied change plus post-apply verification; currently blocked |

The only forward transitions are level 1 → 2 → 3 → 4; no level may be
skipped. A failed entry or exit condition returns to the previous level or to
`blocked`. Jev never owns mutation authority.

The CLI rejects requests for levels 2–4 with `capability_not_available`. A
same-repository manifest proves provenance, not an independent root of trust.
