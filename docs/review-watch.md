# Automatic council follow-up

Fleet can submit a manual review through `requests/` when this watcher advertises
its version1 `requests/ready` marker for the same GitHub login. Requests contain
only a generated id, repository, PR number, full head SHA and actor. They contain
no Slack text or credentials. The existing watcher lock ingests at most64 per
tick, rechecks the actual open non-draft PR (non-own unless a v2 dry-run) and account, then writes an
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

## Own-only mode

An `own-only` file in the state folder (`$PR_REVIEW_WATCH_STATE_DIR`) makes the
watcher serve the login's own pull requests only, as dry-runs that post nothing.
It is a file, not an environment variable, so launchers written before the
switch obey it too. Without the file nothing changes.

With the file:

- discovery of review requests is skipped;
- a council registration is refused and logged (`own-only`), whoever wrote the
  PR, and leaves no approval pending;
- a request is accepted only as an own-PR v2 `dry-run`; every other request gets
  the receipt `rejected` / `own-only`;
- `process_watched` drops an entry whose author is not the login and keeps one
  whose author cannot be read, without running it;
- `launch-run.sh` and `review-run.sh` exit before any work, and before posting a
  pending approval, when the PR author is not the login or cannot be read, or
  when their mode is not `dryrun` (an own PR in `council` or `verify` mode
  would post comments).

`watch.sh --purge-foreign` cleans `runs/` and `watched.tsv`. It runs at the
start of every tick, also while `off` exists. For each key, from the PR author:

- the login's own PR: the posting markers `registered`, `council-done`,
  `approval-pending` and `approval-body` are removed, with or without a status
  file. If its status records a mode other than `dryrun`, `token`, `claimed`,
  `launch` and `launch.*` go too and the status becomes the single line
  `skipped posting-off`;
- another author's PR: the same files go, and the status becomes the single
  line `skipped own-only`. Its entry leaves `watched.tsv`;
- an author that cannot be read: nothing is purged and nothing runs. The
  command exits 3 while such a key remains, 75 when a tick holds the lock.

Switch with `pr-review-watch/install.sh --own-only [interval]`. It refuses
unless the `off` switch exists and never removes it. It creates `own-only`,
stops every running review (`watch.sh stop`), runs the purge, and loads the launchd job only when no unread or foreign
reservation remains. Deploy order: `off`, new scripts, `install.sh --own-only`,
then remove `off`. The base scripts ignore the file, so installing the scripts
without `off` first lets a foreign launcher run. `install.sh` without the flag
leaves an existing `own-only` file. Delete the file to go back; purged
reservations are not restored.

`watch.sh stop` sends TERM to each run's process group and processes, KILLs what
is left after 10 seconds, and fails while one lives. A run leads its own process
group; a group is signalled only while its recorded leader lives. A process left
in a group whose leader is gone is never signalled: the stop fails, names it,
and records it in `stop-survivors`, so every later stop, and `install.sh
--own-only`, fails until that process has exited. Check it with `ps -p <pid>`
and end it by hand.

Known limits of `stop`, accepted: a child that leaves the run's process group
(`setsid`, `setpgid`) and whose parents exit before the next check is out of
reach, and the stop then succeeds while it lives. A stale pid file whose pid now
belongs to a process whose command line holds the runner path and the key is
taken for the run (`process_matches`). The checks between a live group leader
and its group signal, or a start time and a pid signal, are the usual
check-then-signal window.

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

## Request protocol v2: dry-run for own PRs

`requests/ready` keeps the v1 first line (`1<TAB>login<TAB>epoch`, what Fleet
parses today) and adds a second line `v2`. A producer writes v2 requests only
when it sees that line. A v2 request adds `mode` (`post` or `dry-run`) to the v1
keys; v1 files (no `mode`) keep working as `post`. Rules:

- An own PR (author is the watcher account) is accepted only with
  `mode: dry-run`; `mode: post` or a v1 file gets the `rejected own` receipt.
- `dry-run` on another author's PR is `rejected malformed`.
- `mode`, `version` and the key set are strict: a v1 file with `mode`, a v2 file
  without it or any other value is `rejected malformed`.
- A request file holds exactly one JSON object; a stream of several is
  `rejected malformed`.
- `dry-run` on a PR that already holds a posting decision (`.registered`,
  `.council-done` or `.approval-pending`) is `rejected registered-other-account`.

An accepted dry-run records `<key>.dryrun` and `<key>.requested` (head SHA and
account) and watches the PR. It registers nothing, so it grants no review or
approval authority. The PR is considered only on the requested head, with no
settling delay; any other head is ignored until a new dry-run request names it.
A dry-run keeps its outcome apart from posting: its status never counts as a
posting decision, a stopped dry-run writes `.dryrun-exhausted`, an accepted
posting request or registration retires `.dryrun`, and another account's
`.dryrun` never holds the registered account's posting flow.
The run (`review-run.sh dryrun`) calls the council without `--post`, then writes
`reports/<owner>_<repo>-<number>-<sha8>-findings.json`: `version`, `repo`,
`number`, `sha`, `findings` (count from the validator run marker), `body` and
`comments` (the last top-level `WOULD SUBMIT` object whose `commit_id` is the head,
with string `body`, `path` and comment `body`; a broken value fails the parse). A run marker that keeps findings
without a payload, a degraded council or a missing marker is incomplete and
removes any earlier findings file of that head. The run never posts, approves or registers; approval still
refuses an own PR (`gates.sh`, `cannot approve own PR`).

The watcher itself makes no `gh` write for a dry-run (the smoke test records
every `gh` write and asserts none). What the validator skill does inside the
council is outside this repo: its `--dry-run` contract withholds the PR POST,
the owner-item filing and the step 8 record on the `runs` issue, but a real
dry-run has not been observed here, so check the validator's own journal issue
for a run marker after the first live dry-run.

### Private follow-up after an own-PR council

The first requested head still runs the complete council. A successful result
can establish a private `.dryrun-last` receipt bound to the repository, PR,
authenticated account, full head SHA and SHA256 of the exact findings bytes.
It also binds the base ref and merge base the full council actually reviewed,
from its `COUNCIL_BASE` header. Retargeting the PR or changing that merge base
requires another full council. Base and head object IDs are pinned and checked
again before publishing a private result, so a base change during verification
cannot silently widen its coverage.
This is an optimization for later private reviews, never a council registration,
posting watermark or approval authority. Old installations without a receipt
perform a complete council before they can reuse private findings.

A complete initial result is reusable only when its comments represent at least
the number of findings the validator announced. A zero-finding result must have
an empty body and no comments. Body-only or partially represented findings remain
valid full-council results for Fleet, but establish no private baseline. The
body and every comment are presented to the follow-up reviewer; comment count
does not have to equal the initial finding count.

On a requested descendant head without intervening merge commits, the watcher
runs one private verifier using the existing verification model and effort
(`PR_REVIEW_WATCH_VERIFY_MODEL`, default `opus`, and effort default `low`). It
reviews the staged delta and checks every previous body/comment item against
the immutable target code and nearby callers/types. This is a targeted private
verifier, not another complete council or an invocation of the external
`verify-fixes` skill, whose finding source and writes live on GitHub. Its model
tools are restricted to `Read,Grep,Glob`; there is no Bash, delegation, skill
invocation, permission grant or MCP server. It cannot execute tests itself and
must not claim execution evidence from reading code.

Each source item needs exactly one structured verdict with concrete non-empty
evidence. Unsettled items stay in the result; a settled verdict removes them.
The body is one opaque item, so every actionable finding in it must be settled
before it can disappear. New findings are comments only. Retained comments name
their original full SHA because their line numbers have not been remapped.
Successful private per-head reports retain the structured verdicts and evidence.

The result keeps Fleet's version1 shape and adds `basis: "incremental"` (the
initial result says `"full"`). An incremental `findings: 0` attests to the delta
and settlement of the private source set following a complete council; it is
not a fresh run of all council lenses. Incremental counts cover remaining
body/comment units plus new confirmed findings. Fleet ignores the extra basis
field and retains its own two-pass autofix limit.

Missing, malformed, oversized, symlinked, changed-account or altered baseline
evidence, rewritten history, and deltas containing merges fall back to a full
council. A same-patch rebase also takes that safe full path. Receipt reads are
bounded to 4096 bytes; source and output findings to 256 KiB, matching Fleet's
reader. Paths still use the existing SHA8 filename, but contents and receipts
must agree on the complete SHA. Source bytes are snapshotted and hashed once.
The target is checked before model work and again before atomic publication.

Valid uncertainty (incomplete coverage, low confidence or an unverified new
candidate) retires the receipt and escalates once to the complete council in
that invocation. It never loops through another private pass. Malformed output,
missing/duplicate source verdicts, missing evidence, a stale SHA or an oversized
result fails with code4, publishes no fresh findings and retires the receipt.
That head is stopped under existing scheduler rules; the next requested changed
head recovers with a full council. Unavailable or moved GitHub targets/base refs,
transport failures/code1 and timeout/code124 retain the previous receipt for the
existing bounded retry. Existing
`claude_pass` refusal/code3 and incomplete-session/code4 semantics remain:
those stop the head and retire proof rather than being called transport errors.
If an escalated full council fails, subsequent retries are full councils.

Concurrency, attempts, daily caps, request settling, posting reviews and approval
behavior are unchanged. No process is cancelled by this optimization: work on
obsolete heads can still run until the existing timeout, and Fleet can abandon
a request after its progress deadline. The fake-harness regression demonstrates
one full council followed by two private passes and a technical retry; it does
not measure real token or quota savings. Historical rebases, body-only results
and incomplete proof may require full councils instead.

Deploy the complete watcher directory while paused and preserve state; remove
the new receipt to disable reuse for one PR. Closed PR cleanup removes it, and
expired/missing source reports safely force a full review. The existing scripts
directory symlink installs these helpers without a new service or installer.
The isolated source checkout does not activate them on macbook-work.

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
