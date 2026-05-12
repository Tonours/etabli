# Autoresearch Ideas — AGENTS.md / CLAUDE.md optimization

## Completed
- Baseline 68 → 100/100 via profile-anchored rewrite from Hermes persona + corrections.jsonl
- Density 83→96‰, pi_compat 6→9/9, zero contradictions, profile keywords 21→48 (max)
- Compression pass: 1343→1024 words (-24%) while maintaining 100/100
- Added real corrections: 'moins assistant, plus opérateur', register separation

## Session converged at 100/100 (9 iterations)
- Benchmark is grep-based — can't distinguish quality beyond keyword presence
- All real Anthony corrections from Hermes are now covered in the files
- Further iterations would overfit

## Future ideas (require new benchmark)
- **LLM-as-judge semantic scoring**: replace grep patterns with semantic quality evaluation. Would measure whether rules are actionable vs decorative.
- **A/B test with real sessions**: run 5 coding tasks with old vs new AGENTS.md, measure behavioral alignment
- **Cross-reference with Hermes corrections.jsonl continuously**: wire corrections back as a living benchmark that updates when Anthony gives new feedback
- **Register-specific rules**: evolve benchmark to measure per-register (chat, email, commit, PR) rule quality
