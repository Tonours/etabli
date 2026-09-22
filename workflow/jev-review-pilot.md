# Jev review pilot

This candidate prepares evidence and typed advisory judgments. It does not replace
Logic, Spec, quality or adversary obligations, change permissions, or issue a GO.
The installed checkout is separate from the candidate worktree. Shared-source
changes invalidate historical promotion fingerprints; keep deterministic fallback
until a separately reviewed promotion has fresh evidence.

## Local flow

1. `scripts/jev-judge health` reports legacy routing, capsule configuration and
   promotion, profile authorities, calibration freshness and process credential
   availability. Execution coverage remains unknown without observed receipts.
2. `scripts/review-evidence-pack --root PROJECT --base BASE_SHA` captures the
   cumulative tracked diff and untracked files. Optional `--selection FILE.json`
   supplies `excerpts: [{path,start,end}]` and explicit criteria. Unreadable or
   binary content stays visible as unavailable; no silent completeness claim.
3. `--role logic|spec|adversary-code|lead` renders role inputs from that snapshot.
   Logic receives no prior conclusions or plan criteria. Every role retains the
   full patch and may retrieve more deciding code. The pack is data, not a
   substitute for mandatory contract reads.
4. Use `scripts/jev-judge review-findings|review-obligations|review-groups|review-evidence
   --state-file INPUT.json --fixture-response RESPONSE.json` for offline transport
   fixtures. The response may be an ordered array for multiple batches. Fixture
   receipts say `injected_provider`; they are not live observations.
5. Provider execution instead requires `--live` and approved input scope. Review
   finding input contains `pack` and `findings` with stable `id`, `snapshot_sha256`,
   `claim`, `severity`, `path`, `line`, and `evidence_ids` referencing excerpt hashes.
   Missing deciding code or a mismatched snapshot escalates without a provider call.
   Empty findings perform no triage call. Batch defaults to four, adjustable for
   measured task size. A locally oversized batch splits before egress; oversized
   singletons escalate without truncating evidence. High severity always escalates;
   dismissal is a recommendation.
6. Lead consumes the structured findings and escalation list. Grouping annotates
   candidate pairs without removing IDs or merging transitively. Required fresh
   review passes remain mandatory, including both high-risk hunters and the
   cross-family adversary. A fix requires new cumulative review evidence.

For bounded Spec checks, `review-obligations` accepts `obligations` with `id`,
`text`, `source` and `evidence_ids`. It only assesses explicit requirements.
`review-evidence` accepts `purpose` and `{id,text,...}` candidates; scores annotate
all candidates and never hide changed files. Scalar values have explicit
`relevance_status` / `contradiction_status`; uncertain values are null. Test
presence is not test success.

## Claim evidence

```
scripts/jev-judge evaluate-claims --claims-file claims.md --claim-indices 0,2 \
  --root /path/to/project --fixture-response responses.json
```

Use `evaluate-claim --candidate-v2 --claim-index N` for a singleton. V1 remains
available for historical comparisons. V2 resolves relative paths in the consumer
root, supports `file:line`, `file:start-end` or `file:start:end`, and includes file
and excerpt hashes. Large files need explicit ranges; no silent truncation.
Absolute paths are explicit input scope; relative paths cannot escape the root.
External URLs require supplied `--evidence-file` text and are never fetched.
`--conclusion TEXT` enables the optional materiality question. A relation result
is not annulled by uncertain optional materiality. Structural rejection uses no
provider call. Evidence-identical claims share one request and one usage receipt.
Materiality is a boolean when accepted, `uncertain` when undecided, and
`not_evaluated` when no conclusion was supplied.

## Native review accounting

```
scripts/pi-review-hunter --prompt-file prompt.md --patch patch.diff \
  --capture-dir /existing/private/parent/new-run --pass-id logic-1 \
  --parent-id review-1 --role logic
```

Capture is opt-in and invokes Pi. `--print-argv` remains offline. Default text mode
and timeout sentinels remain compatible. Capture uses isolated JSON mode plus one
explicit metadata observer; automatic extension/skill discovery remains disabled.
The private run directory holds native events, stderr, final text, usage receipt,
and prompt inventory. The observer records hashes/bytes of assembled prompt and
provider payload blocks plus provider/model/reasoning-effort metadata, never
payload text or request headers. A malformed inventory row retains native usage
and the remaining metadata but prevents a complete measured receipt. An unsupported or
missing observer leaves effective prompt coverage unknown.

Capture accepts `--sources-file sources.json`: `{"root":"/project",
"selections":[{"kind":"contract","path":"workflow/review-rubric.md","start":1,"end":20}]}`.
Kinds are contract, plan, diff and evidence. Exact source excerpts, file/range
hashes and explicit checkbox obligation IDs are matched against strings in the
actual provider payload; absent segments leave source coverage unknown. This
does not infer implicit obligations or replace required full contract reads.
The private `prompt-sources.json` contains the selected source text; public
inventory rows contain only metadata. Role boundaries still apply to what is
actually supplied to each hunter.

The observer uses monotonic request/message boundaries. Receipts separate local
capture preparation, first-request delay and per-call request intervals. Provider
queue, network and model compute are not individually observable and remain
unknown. Evidence packs separately report their preparation time. Use
`reviewTelemetry({passes, jev, preparationMs})` to combine these receipts with
Jev wait/backoff measurements, cache details and per-role counts.
`usage-event.json` is an `outcome_metric` detail compatible with the ledger;
its success field means terminal completion, not a quality verdict.

`aggregateReviewRuns(expectedPasses, receipts)` requires the dispatch inventory,
parent/role/patch bindings and native coverage. Missing children make the total
unknown while retaining known usage. Parent-inclusive accounting is refused until
its provider semantics have an adapter. Native Pi response IDs prevent double
counting. Shell child discovery is conservative, not universal process tracing.
Silence in a general parent trace now leaves child coverage unknown. The
read/grep-only isolated hunter can prove it has no child-launch capability.
A general parent must explicitly carry `child_inventory: {status:"complete", evidence:"..."}` from the dispatch authority; two empty lists do not establish completeness.
The complete dispatch inventory remains required for aggregation; every observed
dispatch ID must bind to a declared child and its receipt. Stats-only observations
carry capture-local `stats_key` values. The scheduler may explicitly map these to
unique declared child pass IDs through `child_inventory.stats_bindings`; this
never infers identities from counts or certifies parent-inclusive accounting.
Prompt and patch bytes are copied to private exclusive files before Pi starts,
so concurrent edits to the original paths cannot change the reviewed input.

The candidate transport has an overall deadline in addition to per-attempt
limits. Backoff consumes that budget; cancellation reaches fetch. Default legacy
per-attempt semantics remain unchanged when no overall deadline is requested.
No persistent verdict cache is introduced. Provider failure means escalation or
deterministic fallback, never a successful review.

## Evaluation and remaining evidence

`scripts/jev-candidate-calibrate validate tests/fixtures/jev-candidates/claim-evidence-v2.json`
checks the separate 20-development/30-held-out candidate corpus. Bilingual families
never cross that boundary; repeated variants are not independent observations.
The diagnosis corpus is separate from historical `--all` and remains level 2.
Identical counter projections cannot establish a hidden cause.

`scripts/jev-efficiency-review plan INPUT.json` prepares twelve pinned review
cases, three repetitions and three arms (108 cells, not 108 provider calls), plus
two functional canaries. A keeps current passes; B uses deterministic packs; C
adds Jev with the same passes. The dry-run intentionally requires runner inventory
and a budget before it can bound provider launches. `compare RESULTS.json` rejects
incomplete populations, missing usage, changed models/oracles, false GO and lost
critical findings. A threshold pass is not promotion or proof of zero risk.
Missing Jev usage, phase telemetry or inconsistent role totals also makes comparison
inconclusive. Results include per-repetition and per-role totals, LLM plus Jev
tokens (the frozen efficiency thresholds target LLM tokens, not monetary savings), explicit unknown costs and paired bootstrap token intervals over twelve
patches; repetitions are not treated as independent patches.
Each result includes `expected_passes` from dispatch and native `passes`
receipts. The manifest requires parent, Logic, Spec and the tier's adversary
passes; quality and lead duties remain on the parent unless separately captured.
Independent passes require distinct `capture_id` values from fresh isolated executions.
`input_context_sha256` separately binds the supplied prompt, patch and source inputs;
identical input hashes are expected across independent repetitions and never imply
shared conversation state. The capture ID is an invocation identity, not a content hash. High-risk manifests
also declare `authorFamily`; effective adversary receipts must prove a distinct
family. A missing role cannot be counted as a token saving. Combined LLM + Jev
tokens must not increase relative to either control arm, even when LLM-only
thresholds pass. Missing Jev usage remains inconclusive.

`capsule-plan` describes the separate 81-cell plus three-canary experiment:
no capsule / deterministic capsule / same capsule gated by Jev. Keep user prompts
identical and inject through the system prompt. This campaign is not automatically
launched after the review pilot.

Before live collection, seal labels outside agent context, pin evaluators and
provider/model/effort, obtain functional clean/bug canaries and approve the exact
budget. Count failed attempts, cache usage, all children and Jev separately. Publish
paired uncertainty by independent patch, not by repeated sample. The bounded
live results below do not establish production savings or authorize promotion.

Validation commands: `node --test tests/jev-review.test.mjs
 tests/review-run-receipt.test.mjs tests/review-evidence-pack.test.mjs
 tests/jev-review-campaign.test.mjs tests/jev-candidate-corpus.test.mjs
 tests/typesafe-transport.test.mjs tests/typesafe-architecture-version.test.mjs`,
`env -u TYPESAFE_API_KEY bash tests/jev-shadow-smoke.sh`, and
`scripts/verify-agentic-infra core`. These are offline checks; live quality is
not inferred from those checks. The separately collected, synthetic claim/evidence
pilot is summarized in `docs/jev-claim-pilot-20260922.json`: batching reduced Jev
request tokens, with two fewer accepted held-out cases. It does not establish
end-to-end LLM workflow savings or authorize review-pass substitution.

## Candidate state and incomplete historical collection

Every candidate version has an explicit state shape and projects allowed fields.
The state budget scales the source profile's `max_state_chars` by the number of
independent items, with an overall 96 KB ceiling; questions retain a 32,000-character
limit. Candidate receipts identify the version, state limit, threshold source and
`calibration: not_verified`. Historical singleton calibration is not batch evidence.
Claim batches must be built from structurally checked v2 states with identical
proof/conclusion. A process-local content binding rejects fabricated or mutated
batch state before egress. Invalid shape, size or binding escalates without a call.

The baseline and candidate efficiency collectors persist a terminal cell's native
receipts, grade and partial `known_usage` even when child coverage is unknown.
Complete chain totals stay null. The orchestrator writes a `non_comparable` result
and stops before the next provider launch; comparison returns `inconclusive`.
Resume revalidates native evidence and may recover a completed incomparable cell
without relaunching it. An incomplete baseline cannot authorize a candidate run.
Unknown child coverage is never converted to `not_triggered` to force a result.

Resume uses the original persisted process exit code. Failed terminal attempts
remain failed, with known native cost retained; resume never silently deletes or
relaunches them. Missing or modified evidence remains an error. The historical
plan-implement collector now uses the same conservative coverage calculation;
its frozen evaluator fingerprints stay visibly stale instead of being rewritten.

## Completed live pilot — 2026-09-22

The bounded results are in `docs/jev-review-pilot-20260922.json`. Twelve small
synthetic code cases (six critical, three clean, three intent-drift), three
repetitions and three arms completed all 108 cells. The main campaign used 440 isolated
Pi launches including two canaries; 15 separate setup launches bring the complete
attempt count to 455. All used direct `zai/glm-5.3`: high effort for
Logic/Spec/lead and observed maximum effort for adversaries. All required passes
and complete native usage were retained; no reviewer substitution was tested.

| Arm | LLM tokens | Jev tokens | Combined tokens | Median ms | p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| A — required passes | 757,846 | 0 | 757,846 | 79,427.5 | 131,244 |
| B — same passes + deterministic pack | 827,493 | 0 | 827,493 | 98,543 | 162,115 |
| C — same passes + pack + Jev | 863,557 | 74,370 | 937,927 | 91,954 | 133,395 |

The candidate passes the frozen semantic-quality gate but **fails efficiency**:
C uses 13.95% more LLM tokens and 23.76% more combined tokens than A; its median
is 15.77% slower. Against B, C uses 4.36% more LLM tokens and 13.35% more combined
tokens. The paired-patch 95% intervals for LLM token ratios are C/A [1.077, 1.203]
and C/B [0.999, 1.085]. Result: `rejected`, `promotion: false`.
Keep review triage opt-in; do not append it automatically to every review.

All 54 critical-case cells detected their expected defects, and all 108 final
verdicts matched the sealed oracle: zero false GO and zero false BLOCK. Exact
retained-finding scoring gives A 35/36, B 35/36 and C 36/36 successful cells. A and
B each retained one style-note identifier alongside the correct defect, even
though the note was under Consider. The frozen ID-based oracle counts these as
extra findings (precision 27/28 for A/B, 27/27 for C). This small sample does not
establish a general quality advantage, nor certify every prose-format rule.

Three observation-only parser corrections accepted explicit equivalent output
formats. Offline parity preserved every previously parsed report. Prompts, cases,
oracles, runtime sources and thresholds did not change; no completed paid pass
was relaunched. The p08/r1/B, p02/r3/A and p07/r3/B durations include the full
operator interruptions. Keep them in the primary totals and disclose them; do not
present those observations as uninterrupted provider latency. Native tokens include
cache usage; billed dollars and provider queue/compute breakdown are unknown.
Canaries, setup attempts and their known costs are separate in the JSON summary.

The pack reduced Logic calls (83 in A to 43 in B/C), but additional context and
lead work outweighed that reduction across the full chain. This is an observed
cost distribution, not proof that removing required review passes would be safe.
The separate capsule experiment remains prepared offline; no causal capsule gain
or plan-implement promotion is claimed. The diagnosis remains at level 2.

## Adoption order

This sequence orders evaluation and adoption; it does not authorize grouped
activation. Each candidate keeps its present authority until its own gate passes.

| Order | Candidate and present state | Gate before broader adoption |
| --- | --- | --- |
| 1 | Native receipts, health and claim batching: available as explicit tools | Keep native completeness and structural checks; measure representative claim workloads including extra abstention/escalation cost before generalizing the bounded claim gain. |
| 2 | Deterministic review packs: opt-in; fewer Logic calls but higher full-chain cost here | Reduce repeated lead context and demonstrate a complete-chain benefit against the same required passes. |
| 3 | Reviewer-finding and Spec judgments: advisory candidates; automatic triage rejected by this pilot | A fresh, separately frozen comparison must pass both L4 efficiency and L5 quality; preserve independent first passes and every finding ID. |
| 4 | Finding grouping and evidence ranking: executable but not independently calibrated live | Verify duplicate-group precision and evidence-retrieval recall on held-out cases, preserve all IDs/files, then measure incremental full-chain cost. |
| 5 | Route capsules: three-arm protocol prepared; stale promotions use deterministic fallback | Fresh no-capsule/deterministic-capsule/Jev-gated comparisons must preserve protected routes and demonstrate Jev's own benefit before a new promotion; plan-implement remains excluded. |
| 6 | Diagnosis: level 2 with a separate offline corpus | Validate useful diagnoses beyond counter-only projections and satisfy the existing higher-level gates before any increase in authority. |
| 7 | Other advisory/shadow profiles: retain their existing consumers and authority | Select one concrete consumer at a time, refresh its stale calibration, prove quality on held-out labels, and measure its cost before wider use. |

Post-collection hardening normalized optional claim materiality and classified malformed
nested inputs as input errors before egress. Offline replay preserved all 29
main-pilot Jev state/question fingerprints, including canaries; the claim request
comparison covers all 75 singleton/batch shapes. These checks are request-equivalence
evidence, not new provider observations or rewritten historical runtime identities.
