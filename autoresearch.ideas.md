# Autoresearch Ideas — AGENTS.md / CLAUDE.md optimization

## Completed
- Baseline 68 → 93/100 (+37%) via profile-anchored rewrite from Hermes persona sources
- Density maintained (~87‰), pi_compat maxed (9/9), zero contradictions
- Profile keywords 21→45 (+114%)

## Plateau reached at 93/100
- Benchmark uses keyword grep patterns — genuine semantic improvements (internal critic, management rules) don't register
- Profile keywords stuck at 45/54 — the 9 missing points require matching exact regex patterns that are already partially covered

## Future ideas (deferred)
- **Evolve the benchmark**: replace grep-based keyword matching with LLM-as-judge semantic scoring. Would capture quality of rules, not just presence of words.
- **Semantic density metric**: measure information content per rule (e.g., does each rule have a trigger + action + constraint?) rather than word-level keyword counting.
- **A/B test with real sessions**: run 5 coding tasks with old vs new AGENTS.md, measure actual behavioral alignment (does the agent actually follow the rules?)
- **Cross-reference with Hermes corrections.jsonl**: feed Anthony's real corrections back into the benchmark to measure if new rules would have prevented past mistakes.
