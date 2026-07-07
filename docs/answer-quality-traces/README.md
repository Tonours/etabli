# Answer Quality Traces

Saved answer reviews live here when a response or handoff is important enough
to audit after the fact.

Use concise summaries, local paths, source URLs, commands, and explicit gaps.
Do not paste raw transcripts, secrets, environment dumps, tokens, cookies, or
private keys.

Validate with:

```bash
scripts/answer-quality-trace-eval docs/answer-quality-traces
```

Required fields:

- `Status: verified|approximate|inconclusive|blocked|not verified`
- `Verdict: pass|needs-work|blocked`
- `## User Request`
- `## Answer Under Review`
- `## Evidence`
- `## Validation`
- `## Quality Verdict`
- `## Gaps / Follow-up`

Coverage metadata:

- `Category: <category>` is required when `coverage.tsv` marks a trace as
  `covered`. The coverage validator checks that the category in the matrix and
  the trace metadata match.
