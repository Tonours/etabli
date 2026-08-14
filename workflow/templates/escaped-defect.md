# Escaped defect record

Fill when a defect is found **after** an internal `GO` / `GO WITH NOTES`
(Macroscope, colleague, CI, production). One record per defect.

**Storage:** personal stack → obvault (bounded shadow per
`workflow/skills/obvault-memory.md`); work stack → brain. Always keep a
pointer or copy in the repo eval corpus when the case is reusable
(`workflow/self-improvement/reviewer-eval-corpus.md`).

```text
escaped-defect:
  pr:
  commit_reviewed:
  found_by: macroscope | colleague | ci | prod
  defect: <file:line + one sentence>
  bucket: lens_existed_not_run | retrieval_gap | lens_missing | evidence_bar | out_of_scope
  would_have_needed: <file to open | lens | output row>
  action: eval_case | retrieval_change | contract_change | no_op
  storage: obvault | brain | corpus
```

Bucket meanings: see `workflow/skills/reviewer-improvement-loop.md`.
Default action is `eval_case`. Do not append prompt rules from a single miss.
