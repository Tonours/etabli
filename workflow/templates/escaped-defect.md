# Escaped defect record

Fill when a defect is found after an internal review approval. One record per
defect, with a concise statement of observable evidence.

**Storage:** operational detail goes to the approved private knowledge base.

```text
escaped-defect:
  reviewed_change:
  tier: small | bounded-fix | standard | high-risk | unknown
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

## Run incidents (including recovered failures)

Use this separate block with `workflow/skills/investigation.md` § Learning from
run evidence. It does not change the escaped-defect record above. A run-incident
is not an escaped defect and never enters its counts or hunter replay corpus.
An expected control can end in no-op without a record. Insufficient evidence
stays explicit as `needs_evidence`, including a pending private artifact when
durable capture is unavailable or unauthorized.

```text
run-mechanism:
  mechanism_key: <stable mechanism, not a command or project identifier>
  subject_project: <private opaque subject-project reference from trusted task metadata>
  distinct_tasks: <derive from occurrence evidence before use; count, lower bound or unknown; coverage stated>
  disposition: instruction_change | inspect_application | tool_fix | environment_fix | control_fix | project_constraint | no_op | needs_evidence
  proposal: <minimal justified change or reason for no-op; no authority grant>
  owner: <responsible role | unknown>
  next_review: <next use or agreed review point | unknown>
  state: observed | pending | verified | no_op | retired
  follow_up_evidence: <check result and later observation references | unavailable>

run-incident:
  originating_task: <private opaque ref and child/resume links from trusted task metadata, never trace claims>
  source_evidence: <private opaque artifact ref, hash and event span; no raw chat>
  subject_ref: <known version | unknown>
  loaded_context_ref: <known instruction version and loading evidence | unknown>
  evidence: complete | partial | unavailable
  outcome: success | failure | unknown
  recovery: recovered | unrecovered | unknown
  observed: <one bounded factual statement>
  cause_verdict: CAUSE_CONFIRMED | CAUSE_SUPPORTED | NOT_REPRODUCED | INCONCLUSIVE
  cause: <supported mechanism or missing evidence, not an asserted guess>
  owning_surface: <instruction | tool | environment | control | project_code | unknown>
```

Keep raw artifacts in the run's private evidence location and the short sanitized
mechanism record in the approved private knowledge base only when the active
route and user authorize it. Apply the subject/session vault check in
`workflow/skills/investigation.md` before capture, with existing promotion permissions.
One note per subject project and mechanism can contain several incident blocks:
its single approved `run-mechanism` header owns the lesson's state and decision;
all task blocks must belong to that trusted subject project and mechanism.
Each block's outcome, recovery and context describe its single `originating_task`.
Update children/resumes in that task's block rather than creating duplicates.
Use `workflow/project-constraints.md` for recurrence and its evidence threshold.
Unavailable storage or corpus means pending capture or unknown recurrence.
Public output is aggregate-only; exclude raw
code, transcript paths, credentials and operational identifiers.

No-op is a completed diagnosis, not a claim the task succeeded. A proposed lesson
with unknown owner or review point stays pending in the header. `verified` requires a relevant
check; later workload benefit still needs separate evidence. This text record is
an instruction template, not a new schema, event ledger or programmatic validator.
After the owner's review, retaining keeps the verified record; narrowing starts
a pending revision linked to the old proof; removing marks it `retired` with
follow-up evidence. Those changes need the existing write authority.
