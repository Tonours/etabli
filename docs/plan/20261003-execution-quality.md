# Implemented: current plan decisions and truthful review evidence

## Metadata
- Archived: 2026-10-03
- Source plan: `PLAN.md`
- Source plan SHA-256: `d3b7d2b850ee35f68dc300609d1a28478b1e2336180f41baf29d4f96f93d1f0e`
- Status: IMPLEMENTED
- Branch: `fix/execution-quality`; local changes, no commit or publication
- Baseline commit: `8b523a5425eaa7e10480f3690e9b47fe9a5abd99`
- Workflow initiative: `execution-quality`
- Candidate patch SHA-256: `572b12278f2237878f2824c63b40aacead9828dfb567be3366fd4c2fc6db8fa4`

## Outcome

New plan runs bind their reviewed execution contract to the mutation guards.
Material decision changes or a later blocking plan verdict invalidate permission.
Reviewer packs supply the current plan contract and decisions to Spec, adversary
and lead roles. Logic remains independent of plan criteria as correctness
authority. A positive Pi review cannot conceal unresolved inspection failures.
Correct archive bookkeeping closes a reviewed run without pretending the archive
is another implementation edit.

The root contract was approved as READY in native Grok 4.7 plan pass R4 before
implementation (`plan-r4-review.md`, session
`01a0fe24-3e15-73f2-ae8f-a3ce6bed2e0f`). Its current contract hash,
`3c86fe5734045b95f0fb63a2180451eb9d2281381a1eda25347c27ae858b9198`,
matches the frozen reviewed source under the delivered raw-byte algorithm.

The changes reuse the existing guard, event writer, CommonMark parser, review
receipts, archive validator and scaffold. Correction briefs now require domain
bounds, the failing case and neighboring valid and invalid cases. The arbitrary
three-read quota was removed. The user's final steering excludes cybersecurity
assessment; this record covers functional workflow correctness.

## Context and evidence

The original private trace analysis, `trace-analysis-20261002/analysis.md`, covered
four historical cases, 147 source files and 313 events; 11 Pi captures were
unavailable. It established failure mechanisms, not a population defect rate.
The goal prompt is `.workflow/execution-quality/goal.md` and the execution record
is `.workflow/execution-quality/events.jsonl`.

The frozen `case-manifest.json` contains 36 conceptual cases. AC2 clarified its
initial broad progress wording: only explicitly owned bookkeeping is excluded
from contract identity. Free prose in Review Changes and Handoff remains material.
The manifest was preserved; it is not a count of independently measured tasks.

`baseline-cases.json` and `candidate-cases.json` record the following local probes:

| Case | Baseline | Candidate |
| --- | --- | --- |
| READY without a current plan review | Pi and Claude accepted | Both refuse |
| READY with a CHALLENGED plan review | Pi and Claude accepted | Both refuse |
| READY with a stale contract review | Pi and Claude accepted | Both refuse |
| Current plan contract/decisions in review pack | Absent | Present |
| GO after failed Read, fixture transport | Capture exit 0 | Exit 2, review inadmissible |
| Current implemented archive as file_changed | Accepted | Refused, archive_written named |

The mocked Pi transport proves receipt/capture behavior locally. Actual native
cross-family review is a separate source inspection, not a live measurement of
future execution quality.

## Decisions and accepted clarification

- Contract identity retains normalized raw source bytes. CommonMark locates only
  the owned exclusions: simple Meta progress, nested command last-run results
  under the canonical Checks/Validation Plan headings, and actual task completion
  markers. Commands, link references, fenced content and task text remain material.
- New runs bind review hash/provenance. No-ledger and valid legacy unbound runs
  remain compatible; malformed or ambiguous run selection cannot grant permission.
  This initiative began before binding existed and was not retroactively rebound.
- Read/Grep inspection failures are matched to their exact tool and input. An
  observed successful retry can clear an error; missing results remain incomplete.
  Explicit final Verdict takes precedence over contextual Status.
- Observational events remain recordable when archive identity is unavailable.
  A positively identified current implemented archive is refused as file_changed;
  lifecycle operations still require valid identity.
- The existing cleanup selector accepts descendants of docs/plan. AC6's word
  "directly" describes the delivered convention; existing recursive compatibility
  was preserved. This record is directly under docs/plan. No new cleanup path
  policy was introduced.
- The initial agent-imposed cap of 180 active minutes was reassessed to 215 solely
  for the required FD/F2 review and exact closure after a confirmed functional
  defect and an unavailable Anthropic route. Scope and review counters stayed fixed.

## Validation evidence

All evidence below corresponds to the frozen candidate above:

- `node --test tests/plan-review-binding.test.mjs tests/review-evidence-pack.test.mjs tests/review-run-receipt.test.mjs`: 52/52, `FD-focused.log`.
- `bash tests/execution-quality-smoke.sh`: passed, `FD-integration.log`; the
  selected newly bound nominal path runs through both guards, fixture runner,
  capture and writer. Neighbor observations and proper archive closure are covered.
- `scripts/verify-agentic-infra core`: 32/32, `FD-core.log`.
- `scripts/verify-agentic-infra full`: 89/89, `FD-full.log`, including the writer,
  dual runtime guards, copied scaffold/helper dependency closure and 445 Pi tests.
- `node --test tests/etabli-session*.test.mjs`: 81/81, `FD-session.log`.
- `scripts/workflow-context-budget`: 8/8 surfaces within unchanged ceilings,
  `FD-context.log`.
- `scripts/token-bench --check`: passed within the declared static baseline
  tolerance, `FD-token.log`; no measured runtime token savings are claimed.
- `git diff --check`: passed, `FD-diff-check.log` and final identity check.
- `FD-red-smoke.json` records an expected pre-fix exit 1; the same neighboring
  observation scenario passes after the correction. It is not a passing baseline.
- Simplify: clean. Quality: pass, parent convention fallback against existing
  parser, writer, recovery and review-pack patterns; no third standards reviewer.

Private log paths are relative to `.workflow/execution-quality/`.

## Review evidence

The existing bounded sequence was retained: T1, T2, D1, F1, FD, F2. Accepted
functional findings were folded with neighboring regressions. Rejected claims
have source-based rebuttals in the private ledger; no new cycle was started.

| Pass | Actual xAI Grok 4.7 session | Result |
| --- | --- | --- |
| T1 | bed8f881-a4cb-4e01-ae04-c6c97819be70 | Findings folded |
| T2 | a67d3b58-e58d-4102-ad4e-b9217738dc1d | Functional findings folded |
| D1 | Fresh Codex Logic and Spec, exact model ID not exposed | Clean delta |
| F1 | d60c59fa-02e7-42f1-9ef2-962b19ab4658 | Check-heading progress defect folded in FD |
| FD | e8b95434-a57a-496a-a141-e55c076293bc | GO, clean functional delta |
| F2 | 1de0a99f-d00f-4bd7-b463-6331b22f6e8f | GO, fresh full candidate |

The native Anthropic FD attempt was rate-limited with zero inspection. It was
recorded as unavailable and contributes no positive review evidence. The verified
xAI route supplied the required cross-family review. Fresh Codex hunters were
read-only and non-delegating; the parent's lead retains their complete public
reports and deciding-code tables. Their exact inherited model ID is not exposed
by the collaboration API.

F2 public reports: `F2-logic-review.md`, `F2-spec-review.md`,
`F2-lead-review.md` and `F2-adversary-review.md`. Native inspection metadata
in `F2-native-inspection.json` confirms actual Grok 4.7, 32 paired unique
inspection identities, zero errors or malformed rows, and a complete public
verdict. The native suite was not executed by the read-only reviewer; the tests
above were executed by the parent. Native review elapsed 1013.2 seconds, one
run; no latency improvement is inferred from this sample.

## Follow-up state

- Verified: local guard/CLI behavior, regression checks, scaffold parity, final
  functional reviews and exact archive closure. Seven unrelated user documents
  were preserved byte-for-byte.
- Remaining risks: deliberate manual proof forgery is outside the cooperative
  event-writer boundary; legacy unbound compatibility remains intentional. Brief
  instructions cannot guarantee model execution quality.
- Not verified: fewer future review rounds, lower live token cost or a future
  first-pass success rate. Those require comparable live tasks.
- Not performed: commit, push, installation, deployment or publication. Projects
  using copied workflow files receive these changes only after a later authorized
  deployment.
- Final closure: this immutable record is journaled with archive_written; the
  exact matching root PLAN.md is removed with plan-cleanup; plan_removed and
  completed are required, followed by autonomous-completed ledger validation.

Relevant sources: `workflow/skills/execution-quality.md`,
`scripts/lib/plan-review-binding.mjs`, `scripts/plan-review-check`,
`scripts/lib/review-run-receipt.mjs`, `tests/execution-quality-smoke.sh`.
