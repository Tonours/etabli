# Implemented: private incremental follow-up after own-PR councils

## Metadata
- Archived: 2026-11-16
- Source plan: `PLAN.md` - private incremental review follow-up
- Source plan SHA-256: `1b17a72eedf66171d6e9718b1fed61a9eaf117a427fd9fc53b1ba95d3e716407`
- Status: IMPLEMENTED
- Commit / branch: `fix/review-churn`, base `872f35f06762117312b60bd6ea31d9dd17c5dbef`
- Workflow initiative: private-review-followup

## Outcome
Own-PR dry-runs keep their full initial council, then can verify descendant
changes and all previous private findings in one targeted read-only pass.
Fleet still consumes version1 findings; `basis` identifies full or incremental
results. No private receipt supplies posting or approval authority.

## Context
Repeated full dry-run councils accounted for most generated tokens in the
observed morning. The watcher already supported incremental posted reviews,
but private findings had no reusable baseline. A per-PR cap of three would
have deferred none of the observed submissions and would constrain autofix retries.

## Decisions
### Reuse only complete private proof
The optional receipt binds account, repository, PR, complete source SHA, exact
findings digest and the actual council base ref/merge base. Initial comments
must represent at least the announced findings; clean initial sources must be
empty. Every body/comment unit needs an indexed evidence verdict; unresolved
units are retained by code and new confirmed findings are comments.

### Preserve coverage and bounded recovery
Rewrites, merges, retargets, changed merge bases, missing historical objects
and invalid baseline evidence require one full council. Valid uncertainty also
escalates once. Malformed model proof stops the head and retires the receipt;
transport or moved-target failures preserve valid proof for existing retries.
Successful publication rechecks head and base and writes atomically.

### Keep execution private
The verifier uses existing verification model/effort, `Read,Grep,Glob` only,
isolated settings and no MCP/grants. It cannot run tests or publish. This is a
private delta/finding verifier, not a new complete council or the external
GitHub-writing verify-fixes skill. Scheduler caps, locks and posting stay intact.

## Accepted Drift
Review found two missing recovery/coverage boundaries: actual PR base identity
and historical objects absent from a recreated clone. Both received real fixture
coverage. Moved-target errors were separated from malformed model output so
valid review proof survives a new push. No process-cancellation feature or new
scheduler was added.

## Validation Evidence
- `AGENTIC_INFRA_JOBS=2 scripts/verify-agentic-infra shell-docs`: final45/45.
- `bash tests/pr-review-private-smoke.sh`: Linux and isolated macOS fixtures pass.
- Missing-object regression: failed before the one-line existence guard;
  succeeds after it with exactly one full fallback and a new-head receipt.
- `git diff --check`: clean. simplify: clean. quality: shell/JSON clean using
  existing delta-review, receipt and missing-object sibling patterns.
- Mutation probe: unavailable on Linux because `sandbox-exec` is absent.
- Cross-family plan challenge: `claude-opus-5-5`, READY, snapshot
  `b1b9abcf42b048e1d9f834ecc67a80f308b7e1b72be13957b228b63db10e69be`.
- Full Logic/Threat and final delta Logic/Spec complete; Logic deciding-code
  tables filled. Cross-family D2 adversary `claude-opus-5-5` (Anthropic),
  GO WITH NOTES on delta
  `b21148ddfe2af8c9660416d0268fcd061ba7f0fe1a97709b6bc82485a96fa181`.

## Follow-up State
- Source delivery only: no installation, restart or live cancellation on macbook-work.
- Real token/quota savings remain unmeasured; fake call counts prove control flow.
- Strict base OID checks can prevent reuse on busy bases. Repeated retained
  comment prefixes can accumulate within the256KiB bound.
- Nonblocking review note: explicitly asserting the old receipt SHA before the
  fresh-clone fixture would strengthen future regression sensitivity. Current
  before-fix failure establishes that the receipt path is exercised.
- Install the whole watcher directory while paused; preserve existing state.
