# Escaped defect record

Fill when a defect is found after an internal review approval. One record per
defect, with a concise statement of observable evidence.

**Storage:** operational detail goes to the approved private knowledge base.

```text
escaped-defect:
  reviewed_change:
  tier: small | standard | high-risk | unknown
  source_location:
  found_by: independent-review | human-review | ci | production
  defect: <source location + one sentence>
  bucket: lens_existed_not_run | retrieval_gap | lens_missing | evidence_bar | deferral_accepted | out_of_scope
  would_have_needed: <file to open | lens | output row>
  action: retrieval_change | contract_change | project_constraint | no_op
  constraint: <tool> <rule-or-test path> | none
  public_surface: aggregate-only | none
```

`deferral_accepted`: a review saw the defect and waived it as pre-existing,
intended, out of scope or owned elsewhere, while the change's goal depended on it.
`tier` is the recorded tier of the reviewed change (plan or archive `Tier`, or
the implementation report `tier:`); `unknown` when no reliable source gives one.
Public surfaces accept aggregate synthetic rows only; raw change records stay private.

`project_constraint`: the miss is mechanizable in the subject project
(`workflow/project-constraints.md`). One miss must not append a new prompt rule.
Keep the record bounded and reproducible.
Do not store credentials or raw provider output.
Re-run the relevant check before closing the record.
