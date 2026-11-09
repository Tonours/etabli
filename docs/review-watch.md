# Automatic council follow-up

Fleet can submit a manual review through `requests/` when this watcher advertises
its version1 `requests/ready` marker for the same GitHub login. Requests contain
only a generated id, repository, PR number, full head SHA and actor. They contain
no Slack text or credentials. The existing watcher lock ingests at most64 per
tick, rechecks the actual open non-draft non-own PR and account, then writes an
atomic receipt before removing the request. Receipts expire after7 days.

Acceptance adds involvement only: it never replaces a council baseline,
watermark, completed decision, stopped head, existing actor or pending approval.
The ordinary scheduler chooses full council or delta plus verify-fixes. Existing
same-head work is joined or its completed result reused; no new model call is
needed for a known result. The configured kill switch pauses manual requests too.

Pause before updating the scripts. Before rolling back to an older watcher,
remove `requests/ready` first; an old watcher does not ingest this protocol. Fleet
never switches an already-committed request to a competing worker if its receipt
is missing. It reports an unavailable watcher instead. Runtime heartbeat and
versioned readiness are separate: readiness is written only after authentication
and executable checks under the watcher lock.

After a completed `pr-council-review --post`, the launcher sends its canonical
report to `pr-review-watch`. Dry runs, incomplete markers, unposted positive
findings and own PRs do not grant reviewer approval authority. A clean council
posts no review; its complete matching run marker is the evidence.

The terminal line describes the handoff:

- `following <sha> (approval not queued)`: Fleet retains its initial verification
  and approval. The watcher handles later commits. This also covers a council
  whose earlier validator still has findings open.
- `submitted <sha> (approval by the watcher once ingested)`: a direct council
  submitted its evidence to a ready watcher on the same GitHub account. Approval
  authority is established only after ingestion validates the current head and
  preserves any existing initial approver or follow-up verification decision.
- `not queued (<reason>)`: automatic follow-up was not registered.

The watcher ingests immutable records under its existing lock. It remains the
single writer of the watched list. A current-head approval stays followed until
the PR closes or merges. A later commit waits for the existing settle interval,
runs delta review and verify-fixes, then approves only after the current-head,
CI and unresolved-thread gates pass. A clean baseline still requires verification.
A rewritten history uses a full council. Models, efforts, caps and breakers stay
unchanged. Approval needs no additional owner prompt and never merges the PR.
An actual failure or unavailable required council member cannot register a clean
baseline or grant approval. Supported exact-patch reuse and explicit opt-outs
retain their existing semantics. Rejected approval imports generate one notice.
Stale-head imports cannot rearm a veto; same-head verification decisions remain
authoritative. Already-followed PRs use their normal delta and verify-fixes path,
so another direct or Fleet council cannot bypass that verification. A dead runner's
status defers imports only during the existing launch grace; recovery cannot clear
another head's stopped decision. The batch stays bounded.

Approval retries first check actual reviews from the same account on the exact
commit. This recovers an accepted POST whose response was lost. Deterministic
GitHub refusals stop retrying; unknown or transient failures remain pending.
Changing the GitHub account cannot reuse another reviewer's cached proof. Legacy
unbound proof needs a fresh council before approval.

Install with the existing `pr-review-watch/install.sh`; the default launchd tick
is 60 seconds. State is `$PR_REVIEW_WATCH_STATE_DIR`, defaulting to
`~/.claude/state/pr-review-watch`. Its `off` file pauses execution. The dedicated
heartbeat is written only after CLI, executable and authentication checks pass.
The report and state stay local. Fleet reads the configured state folder and
does not run a second watcher.

Deploy `run.sh`, the watcher, its registration helper and runner together. Pause
the watcher before updating or rolling back this release; preserve its state.
An isolated source branch does not activate installed symlinks. No activation,
provider review or live approval was used to test this change.

The pre-existing race between an independently running direct council and a
watcher discovering its review request remains: before the council completes
registration, discovery can launch an initial review after its settle interval.
There is no new global pre-start lease.
