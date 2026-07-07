# Answer Quality Eval Cases

Status: verified for the fixture strategy, approximate for future live-model
quality targets.

## Purpose

`scripts/answer-quality-eval` runs a local deterministic fixture set for the
answer-quality contract. It does not grade live model output and does not prove
that a future response is subjectively "10/10". It proves that the current
quality-floor helper keeps accepting and rejecting the representative artifacts
we care about.

## Source-Backed Design

OpenAI's evaluation guidance frames quality as a repeated loop: define the
objective, collect a dataset, choose metrics, run comparisons, and keep growing
the eval set. It also calls for typical, edge, and adversarial examples. The
local fixture manifest follows that shape with a small starting corpus:

- typical: good research, repo, handoff, and obvault-backed answers;
- edge: a simple answer that should pass `general`, and a handoff with checks
  but no risk marker that should fail strict `handoff`;
- adversarial: web-research claims without URLs, repo answers from memory,
  obvault answers without entrypoints, and overclaims.

OpenAI's agent-eval guidance makes workflow behavior part of the eval surface:
tool choice, traces, policy following, and handoff quality matter. For Etabli,
that means the eval should target modes and evidence markers, not just prose
length or style.

Anthropic's agent guidance recommends starting with simple, transparent systems
and adding complexity only when it measurably improves outcomes. That supports a
Bash manifest runner before any model grader, API-backed eval, or graph of
trace metrics.

Self-RAG supports the same local rule from the retrieval side: retrieve on
demand, critique support, and avoid indiscriminate context. The fixtures
therefore include both source-backed answers and answers that claim research
without evidence.

## Local Evaluation Surface

- Manifest: `tests/fixtures/answer-quality/manifest.tsv`
- Runner: `scripts/answer-quality-eval`
- Smoke: `tests/answer-quality-eval-smoke.sh`
- Floor checker: `scripts/answer-quality-check`

Each manifest row declares:

```text
id<TAB>mode<TAB>expected<TAB>category<TAB>file<TAB>description
```

`expected` is `pass` or `fail`; `category` is `typical`, `edge`, or
`adversarial`. The runner compares the actual helper result to the expected
outcome and fails on any mismatch.

## What This Proves

Confirmed:

- The helper accepts representative artifacts with explicit source, validation,
  uncertainty, local-path, or obvault-entrypoint evidence.
- The helper rejects common missing-evidence patterns and unsupported
  perfection/correctness overclaims.
- The eval set can grow without changing the helper or smoke script shape.

Not verified:

- Real model output quality.
- User satisfaction.
- Factual correctness beyond the deterministic markers.
- A global 10/10 score.

## Sources

- https://developers.openai.com/api/docs/guides/evaluation-best-practices
- https://developers.openai.com/api/docs/guides/agent-evals
- https://www.anthropic.com/engineering/building-effective-agents
- https://arxiv.org/abs/2310.11511
