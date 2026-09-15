# Escaped defect record

Fill when a defect is found after an internal review approval. One record per
defect, with a concise statement of observable evidence.

**Storage:** operational detail goes to the approved private knowledge base;
reusable synthetic cases may be linked from the public evaluation corpus.

```text
escaped-defect:
  reviewed_change:
  source_location:
  found_by: independent-review | human-review | ci | production
  defect: <source location + one sentence>
  bucket: lens_existed_not_run | retrieval_gap | lens_missing | evidence_bar | out_of_scope
  would_have_needed: <file to open | lens | output row>
  action: eval_case | retrieval_change | contract_change | no_op
  metrics_record: updated | created | missing
  public_surface: aggregate-only | none
```

`metrics_record` records the side effect on the private metrics record. `missing`
means the record is incomplete until one of the other values is set. Public
surfaces accept aggregate synthetic rows only; raw change records stay private.

Bucket meanings are defined by the reviewer improvement loop contract.
Default action is `eval_case`; one miss must not append a new prompt rule.
Keep the record bounded and reproducible.
Do not store credentials or raw provider output.
Re-run the relevant check before closing the record.
