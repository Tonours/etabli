# Trace — answer quality coverage gap

Status: verified
Verdict: needs-work
Category: coverage-gap

## User Request

Continue the active goal to analyze Etabli and obvault, ground the work in
research, and make future answers consistently high quality and efficient.

## Answer Under Review

The current answer-quality system now has a source-backed contract,
deterministic helper checks, a versioned fixture eval, a consolidated audit
command, and one passing handoff trace. That is useful progress, but it is not
enough evidence to claim broad coverage for future live answers.

## Evidence

- workflow/answer-quality.md:8
- workflow/answer-quality.md:57
- workflow/answer-quality.md:63
- docs/answer-quality-eval-cases.md:8
- docs/answer-quality-eval-cases.md:69
- docs/answer-quality-traces/20260707-answer-quality-audit-handoff.md:1
- scripts/answer-quality-trace-eval:1
- command: scripts/answer-quality-trace-eval docs/answer-quality-traces
- command: scripts/answer-quality-audit --obvault /Volumes/Crucial/work/obvault

## Validation

- command: scripts/answer-quality-trace-eval docs/answer-quality-traces
- expected result: passes with two trace files after this trace is added
- command: scripts/answer-quality-audit --obvault /Volumes/Crucial/work/obvault
- expected result: passes with `answer quality audit: ok`
- command: bash tests/workflow-docs-smoke.sh
- expected result: passes with this trace pinned

## Quality Verdict

Needs work: the deterministic checks and saved traces create a better quality
floor, but the trace corpus is still too small to verify real-answer behavior
across repo maintenance, obvault-backed memory answers, research summaries,
implementation handoffs, and direct user explanations.

## Gaps / Follow-up

Add traces from real high-impact responses as they occur, especially failures or
near-misses. Useful next trace categories are live repo explanation, obvault
memory answer, source-backed research answer, implementation handoff after a
large diff, and a blocked or inconclusive answer that handled uncertainty well.
