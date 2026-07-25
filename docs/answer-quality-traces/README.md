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
