# Investigation Contract

Harness-neutral contract for diagnosing repository, runtime, UI, and
performance questions. Diagnosis is read-only unless the active route and user
also authorize implementation.

## Evidence ladder

Use the strongest available evidence and name the ceiling when it is absent:

1. parent-observed runtime, test, trace, browser, or benchmark evidence;
2. controlled intervention or failing/passing counterfactual;
3. deterministic reproduction from exact inputs;
4. code, configuration, and history inspection;
5. reported symptoms or assumptions.

Source reading can support a mechanism, but it cannot by itself confirm that
the mechanism caused an observed runtime symptom. Hash durable artifacts with
`scripts/evidence-proof` (etabli repo only; scaffolded projects resolve it <!-- etabli-only -->
from the etabli checkout). `validate` is a gate by default: a non-VERIFIED
verdict exits non-zero — pass `--no-assert` only for inspection. Pack
integrity and execution provenance are separate.

## Sequence

1. State one falsifiable question and the exact target/ref.
2. Capture expected and observed behavior, reproduction status, environment,
   and the smallest decisive observable surface.
3. List the main mechanism plus at least two credible alternatives. Give every
   hypothesis an explicit falsifier before concluding.
4. Collect evidence that can reject alternatives. Keep runtime, UI, and
   performance artifacts distinct from source-only evidence.
5. When safe and authorized, change or isolate one mechanism and check whether
   the symptom changes as predicted. A failing/passing pair is acceptable.
6. Emit one verdict and the smallest next evidence or implementation action.

## Verdicts

- `CAUSE_CONFIRMED`: reproduced symptom; exactly one supported mechanism; at
  least two evidence-rejected alternatives; no open hypothesis; non-source
  runtime/test/trace evidence; and a controlled intervention or
  failing/passing counterfactual that changes the symptom as predicted.
- `CAUSE_SUPPORTED`: evidence supports a mechanism, but the causal
  intervention or equivalent proof is absent. This is the maximum verdict from
  source inspection alone.
- `NOT_REPRODUCED`: the stated symptom did not occur under the recorded target,
  environment, and steps.
- `INCONCLUSIVE`: the surface is blocked, intermittent, incomparable, or lacks
  the evidence needed to reject alternatives.

Do not replace these labels with vague confidence language.

## Modality gates

- Pre-existing capture (trace, log, profile, dump already on disk): read, hash
  with `scripts/evidence-proof`, and cite `file:line`. Do not re-run or <!-- etabli-only -->
  instrument that capture. Ceiling is `CAUSE_SUPPORTED` without a new
  intervention.
- User-asked instrument or reproduce: do that. Do not apply the capture-only
  stop when the user asked to instrument or reproduce the live process.
- Product/UI: follow `workflow/skills/product-dogfood.md`; record action,
  resulting state, side effects, concrete viewports, accessibility, console,
  network, responsive, and reduced-motion outcomes when in scope.
- Performance: freeze commands, subject/build and fixture hashes, environment,
  metric, direction, thresholds, arm order/seed, warmups, sample count, and
  outlier policy before the first warmup. Use at least 7 measured samples per
  arm for a median claim, or 20 plus 2 warmups per arm for the nearest-rank
  observed p95. The parent-observed runner output must bind the predeclared
  design, commands, subject/build hashes, and fixtures. Never call that observed
  p95 a population guarantee.
- External or unavailable surfaces: report `proxy_supported` or `blocked`, not
  live confirmation.

The closed pack shape is `workflow/evidence-pack.schema.json`; the executable
semantic validator is `scripts/evidence-proof validate`.
