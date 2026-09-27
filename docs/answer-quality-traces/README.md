# Answer Quality Traces

These saved answer reviews are historical evidence from the earlier
answer-quality audit layer.

Use concise summaries, local paths, source URLs, commands, and explicit gaps.
Do not paste raw transcripts, secrets, environment dumps, tokens, cookies, or
private keys.

The active contract now uses `scripts/answer-quality-check` plus its versioned
fixture regression eval. These files are retained for provenance and are not a
canonical validation input.

Historical fields:

- `Status: verified|approximate|inconclusive|blocked|not verified`
- `Verdict: pass|needs-work|blocked`
- `## User Request`
- `## Answer Under Review`
- `## Evidence`
- `## Validation`
- `## Quality Verdict`
- `## Gaps / Follow-up`

Historical coverage metadata:

- `Category: <category>` corresponds to the archived `coverage.tsv` matrix.

## Representative Eval

Use `scripts/answer-quality-eval` to run the versioned fixture corpus in
`tests/fixtures/answer-quality/manifest.tsv`. The corpus covers typical, edge,
and adversarial examples for research, repo, handoff, obvault-backed, simple,
and overclaim behavior. This is a deterministic regression eval for the helper,
not a live-model eval or subjective score.

Historical answer reviews remain under `docs/answer-quality-traces/` as
inspectable evidence. They are not an active gate and do not add another
checker layer.

## Evidence Base

Status: verified for the design principle, approximate for future eval scores.

- RAG: <https://arxiv.org/abs/2005.11401>
- Self-RAG: <https://arxiv.org/abs/2310.11511>
- ReAct: <https://arxiv.org/abs/2210.03629>
- Reflexion: <https://arxiv.org/abs/2303.11366>
- Generative Agents: <https://arxiv.org/abs/2304.03442>
- SWE-agent ACI: <https://arxiv.org/abs/2405.15793>
- GraphRAG: <https://arxiv.org/abs/2404.16130>
- Anthropic effective agents:
  <https://www.anthropic.com/engineering/building-effective-agents>
- Anthropic contextual retrieval:
  <https://www.anthropic.com/engineering/contextual-retrieval>
- OpenAI evaluation best practices:
  <https://developers.openai.com/api/docs/guides/evaluation-best-practices>
- OpenAI agent evals:
  <https://developers.openai.com/api/docs/guides/agent-evals>
