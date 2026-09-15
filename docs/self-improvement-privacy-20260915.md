# Privacy migration report

Date: 2026-09-15
Status: validated for the current tree; live RSI outcome: not verified.

This report records the current-tree privacy boundary for the reviewer
self-improvement evidence. Public files retain only a reusable contract,
synthetic fixtures, opaque fingerprints and aggregate results. Detailed
operational evidence is retained once in the approved private knowledge base;
no transcript, raw log, credential or secret is copied.

## Routing

- Evidence originating in the Etabli harness or personal research is routed to
  the private reusable store for this repository.
- Evidence originating in the internal project context is routed to its
  private store.
- No dual-write is performed. Destination notes contain each private unit once,
  with a marker and a receipt containing `content_review:"no-raw"`. The current
  tree does not claim to reconstruct the historical order of those writes.
- Classification manifests, receipts and worktree snapshots stay in the local
  ignored `.workflow/` control surface; they are not public replacement files.

## Validation status

- The source snapshot is locked to the reviewed commit and current tracked
  bytes are checked before every migration boundary.
- Public scans cover references, hashes, paths, provider labels and campaign
  and campaign identifiers; matched values are redacted from temporary output.
- The live RSI loop and a measured quality improvement remain unverified. This
  migration establishes storage and publication controls; it is not a runtime
  benchmark.
- The current snapshots are internally consistent; hashes are the only retained
  baseline for already-deleted local reports, so historical out-of-scope
  preservation and write chronology remain inconclusive.
- Reachable hosted history and immutable review references may still contain
  prior public material. Removing current-tree files does not purge that
  history; a separate history-remediation decision would be required.
