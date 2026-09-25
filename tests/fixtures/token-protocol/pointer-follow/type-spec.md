# `pointer_follow` ledger event — TYPE SPEC (T8a bundle, UNWIRED)

> T8a status: this spec lives as bundle code/fixtures ONLY. It is NOT wired
> into `scripts/workflow-event`, the detail schema, or any ledger. T8b wires
> it with the contract rewrite (AC3 defer branch only).

## Event shape

```json
{
  "run_id": "r1",
  "type": "pointer_follow",
  "detail": {
    "path": "workflow/review-rubric.md",
    "sha256": "<hex of the bytes the producing call returned>",
    "tool_call_id": "call_1"
  }
}
```

- `detail.path`: repo-relative path of the file behind the pointer.
- `detail.sha256`: sha256 over the bytes THAT producing call returned —
  never over the live file.
- `detail.tool_call_id`: designates EXACTLY the successful producing call in
  the run's single trace sequence (same run, return ok, `detail.path` in
  its args) — a MODEL read call, or the RUNNER's `resolve_pointer` span for
  slot 11 (id + success + returned bytes, same causal predicate,
  producer = runner).

## STRONG predicate (screening)

Verified by `scripts/pointer-follow-verify --trace <file>`:

1. `detail.tool_call_id` designates EXACTLY ONE producing call (same run,
   ok, path in args).
2. The producing call sits BEFORE the emission call.
3. `detail.sha256` == sha256 of the producing call's returned bytes.
4. The emission payload == the ledger event (same run, same detail).
5. The emission sits BEFORE the verdict call.

Exit 0 prints `STRONG`; any violation exits 1 with the reason.

## Strengths (normative)

- STRONG in screening (full trace walk, this validator).
- ATTESTATIONAL in production (ledger order + detail only).

## Fixtures (this directory)

- `positive-strong.json` — conforming trace, exit 0.
- `negative-1-read-after-emission.json` … `negative-6-payload-mismatch.json`
  — the six v25 negatives (read after emission, wrong sha, unknown
  tool_call_id, cross-run tool_call_id, emission after verdict, emission
  payload != ledger event), each exit nonzero.
