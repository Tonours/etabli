# Automatic council follow-up

Fleet can submit a manual review through `requests/` when this watcher advertises
its version1 `requests/ready` marker for the same GitHub login. Requests contain
only a generated id, repository, PR number, full head SHA and actor. They contain
no Slack text or credentials. The existing watcher lock ingests at most64 per
tick, rechecks the actual open non-draft non-own PR and account, then writes an
atomic receipt before removing the request. Receipts expire after7 days.

Acceptance adds involvement only: it never replaces a council baseline,
watermark, completed decision, stopped head, existing actor or pending approval.
An accepted explicit request skips the120-second head-settling delay only for
its exact SHA and account. The actual first-seen timestamp is still recorded.
Automatic discovery and later unrequested heads keep that delay. A private
request marker is consumed when an attempt starts and removed when the PR closes;
it grants no review or approval proof. Pause, concurrency, daily/diff-size caps,
attempt limits and in-flight exclusion still apply.
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
status reserves a slot and defers imports until max(180 seconds, configured retry backoff); recovery cannot clear
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

## Launch ownership and diagnostics

Each attempt has an immutable private launcher and a one-shot token. Herdr and
headless fallback deliver the same token; a per-PR execution lock admits it once.
Delayed delivery after a retry, head change or imported report cannot execute.
Pending delivery reserves concurrency until max(180 seconds, retry backoff).
A pause before work preserves the per-head attempt budget; the global daily
submission cap still applies. Approval retries share exclusion and preserve the
council/verify attempt status.

Launch and transport output stays in private `diagnostics/` files (0600), under
private state directories (0700). Generated launchers are private too. They can
contain environment values: never attach these files to a PR or Slack message.
Old launchers and diagnostics expire after 30 days; active attempts are retained.
Reports remain private. Generic watcher summaries contain no raw launch errors.

Fleet waits for retryable failures rather than announcing failure on attempt one.
After 30 minutes without a fresh failed/interrupted attempt status it reports an
inconclusive retry timeout. A long configured backoff or queue can legitimately
outlast this notification deadline; the watcher may still finish later. Only a
fresh exact-head published GitHub review proves a posted review or approval.
This source change does not prove activation on another host. This Mac links the
source directory directly: verify the local service is absent (or paused with no
live runs) before editing. Pause before installing the complete watcher helper set
on another host; update Fleet for retry-aware notifications. Older Fleet can
report a pre-work pause as failed; it cannot infer an approval from that status.

## Configured verification skill

`PR_COUNCIL_VERIFY_SKILL` overrides the first line of
`~/.config/pr-council-review/verify-skill`. For a namespaced skill such as
`forest:verify-fixes`, the verify pass enables only matching plugin namespace
entries set to boolean `true` in the owner's `~/.claude/settings.json`.
It imports no other user settings or plugins. Hooks remain disabled, MCP stays
strict, and setting sources remain project/local after author configuration is
reset to the trusted base. Unnamespaced and project-provided skills keep the
existing behavior. When selecting a namespaced plugin, a malformed user settings file stops
verification before a watermark or approval. The watcher waits in the existing
unconfigured state without spending attempts. Repairing the JSON resumes the
same head at its previous attempt number, including at the cap, and reuses a
completed delta review. The log names both configuration repairs: select the
verification skill or repair the owner settings.
Plugin loading and provider availability are separate checks. This change does
not turn a provider error into completed verification or bypass approval gates.
