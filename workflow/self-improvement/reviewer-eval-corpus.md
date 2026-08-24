# Reviewer Eval Corpus

Regression cases for the `reviewer` agent, built from defects it let through.
Contract: `workflow/skills/reviewer-improvement-loop.md`.

Each case: the commit reviewed, the defect with its location, the bucket, and what
a correct review would have had to do. Held-in cases motivated a change; held-out
cases must keep passing.

Current lens count: **8 / 8** (includes Convention & pattern fit; the relational
seven are held-in; the eighth is active and provisional until ≥2 independent
convention misses if a merge is needed).

---

## 2026-08-06 — PRD-886, static OpenAPI document (agent-nodejs #1810)

`reviewer` on fable/xhigh returned GO WITH NOTES and found 5 real contract defects
(missing 502/413/429, 501 on the wrong route, invalid-operator misfiled under 422).
Macroscope then found 4 more on the same commit. Those 4 are the cases below.

### R-001 — precedence stated backwards

- **Bucket**: `lens_missing` (now covered by the Precedence lens)
- **Defect**: `packages/agent-bff/src/openapi/schemas.ts` described the body
  `timezone` field as overriding the `X-employer-Timezone` header. `resolveTimezone`
  (`packages/agent-bff/src/timezone/timezone.ts:32-34`) reads
  `[header, body, fallback]`, so the header wins.
- **Impact**: a generated client sending both would run queries in the wrong
  timezone. Silent wrong results, not an error.
- **What the reviewer did**: verified the body field was "genuinely honored" on
  every route, and stopped there.
- **What it had to do**: open `resolveTimezone` and read the array order. The bug
  is invisible from the description alone, and invisible from confirming the field
  works.
- **Proof**: `resolveTimezone({header:'Europe/Paris', body:'Asia/Tokyo'})` returns
  `Europe/Paris`.

### R-002 — degraded mode not considered

- **Bucket**: `lens_missing` (now covered by the Degraded modes lens)
- **Defect**: `501` was declared only on action execute. `createAgentStubMiddleware`
  (`packages/agent-bff/src/agent/agent-stub.ts:11-19`) returns `501 not_implemented`
  on **every** route when `AGENT_URL` is unset, a supported startup mode.
- **Impact**: a client generated against the document cannot model the response it
  gets from a BFF running without an agent.
- **What the reviewer did**: traced 501 producers in `action-execute-mapper.ts`.
- **What it had to do**: ask what each route returns when the agent is
  unconfigured. The stub is reachable, shipped code, not a test double.

### R-003 — prose promised what the schema omitted

- **Bucket**: `lens_missing` (now covered by the Prose versus machine-readable lens)
- **Defect**: `X-employer-Timezone` was described in the document's `info.description`
  but never registered as a request parameter, so no generated client exposes it.
- **Impact**: consumers cannot discover the header through tooling.
- **What the reviewer did**: compared the document against the code.
- **What it had to do**: compare the document against **itself** — every behavior
  named in prose should appear in a machine-readable declaration.

### R-004 — impossible states representable

- **Bucket**: `lens_missing` (now covered by the Impossible states lens)
- **Defect**: `CountResponse` modelled `count: number | null` and
  `countStatus: 'available' | 'deactivated'` independently, admitting
  `{count: null, countStatus: 'available'}`. `mapCountResponse`
  (`packages/agent-bff/src/data/response-mappers.ts:46-62`) only ever produces two
  pairings.
- **Impact**: consumers cannot narrow `count` on `countStatus`, and may handle
  states that never occur while missing the ones that do.
- **What the reviewer did**: verified both fields matched the mapper's types.
- **What it had to do**: ask which **combinations** the schema admits versus which
  the code produces. Field-by-field checking cannot see this.

### Cross-cutting conclusion

All four are the same shape: the reviewer verified that each thing **exists** and
never asked how two things **relate**. That is why the fix was four lenses framed
as relational questions, not "look harder".

Counted as two independent misses each for the precedence and relational classes,
which is what justified promoting them to lenses rather than leaving them as cases.

---

## Held-out: what the reviewer got right on the same commit

These must keep passing. A change that catches R-001..R-004 but loses these is a
regression.

- **H-001** — caught `502` missing from every path, reachable via
  `agent-error-mapper.ts:154` on any transport failure. Correctly identified as the
  most common proxy failure mode.
- **H-002** — caught `413` missing, reachable from the 16kb body cap
  (`cli-core.ts:32` plus `error-middleware.ts:10-13`).
- **H-003** — caught `invalid_filter_operator` documented under 422 while
  `validation-errors.ts:22-25` returns 400.
- **H-004** — caught `501` declared on action form where it is unreachable, and
  that the real 501 body carries no `message`, violating the declared envelope.
- **H-005** — caught `@redocly/cli` added as a dead devDependency, referenced by no
  script, test, or workflow.
- **H-006** — correctly cleared the mount point: probed api-key mode, the
  unavailable-guard, expired tokens, and path variants, and reported no leak. A
  correct "nothing found", which the loop must not punish.

## Run 2026-08-06 — held-in results on commit b42eedcb

The four cases above were replayed against the reviewer, twice: once after adding
the lenses to the agent definition and the rubric, once after constraining the
output with a mandatory lens table.

| Case | v1 (lenses listed) | v2 (lens table required) |
|---|---|---|
| R-001 precedence | miss | **caught**, opened `timezone.ts:32-34` |
| R-002 degraded mode | miss | **caught**, found the stub 501 on every route |
| R-003 prose vs declaration | miss | miss |
| R-004 impossible states | miss | **caught**, proposed the discriminated union |

Held-out H-001..H-006: all still caught in both runs. No false positives introduced.

**What the delta teaches.** v1 listed seven lenses in the agent definition and in
the rubric, and the agent ran neither: it reported against the rubric's three
section headings instead. Listing a lens does not cause it to run. v2 changed only
the output contract — a table with one mandatory row per lens, each naming the
`file:line` opened — and three of four misses flipped to caught.

So the lever was **the output contract, not the instruction**. A verification step
the agent can omit without the omission being visible is a step that does not exist.
Prefer constraining what must be reported over adding what should be considered.

Two findings appeared in v2 that no reviewer and no static analyser had produced:

- **the aggregator defect**: `aggregator` documented optional while
  `packages/agent/src/utils/condition-tree-parser.ts:121-123` requires
  `'aggregator' in raw`. A branch conforming to the document gets a 400 from the
  agent. Found by crossing a package boundary, which the retrieval phase asks for.
- **the security-scheme defect**: `bffSession` advertised on all six operations
  while `requireAgentToken` (`src/http/agent-route-helpers.ts:31-36`) 401s every
  OAuth-mode call. A client generated with session auth fails on 100% of requests.

Both are now fixed on the branch. R-003 stays open: the prose-vs-declaration lens
ran and reported, but did not catch its case. One miss, so it becomes an eval case
and does not justify a lens change. Revisit if it recurs.

## Run 2026-08-06 (b) — reviews on the merge-ready heads

Three reviews on the final commits of PRs #1809, #1810, #1811, with the hardened
agent (fable, xhigh, read-only tools) and the mandatory lens table.

### H-007 — #1809, dependency resolution: GO with zero findings

Held-out case. The reviewer independently semver-checked 4.3.6 against all nine
zod declarers in the installed tree, established the yarn v1 mechanism behind the
rejected alternative (the lockfile is keyed by exact spec string and never
re-resolves an existing entry, so a new `^4.3.6` spec resolves fresh to latest
while old entries persist), and confirmed the bare-name pin follows the eight
existing bare pins in the resolutions block.

It also surfaced a scope-correct open question the author had only half-stated: the
dual-copy hazard survives **downstream**, because `resolutions` is not published.
Follow-up check (main session): neither `ai-proxy` nor `mcp-server` declares zod as
a **peer** dependency, so the classic dual-package failure needs a consumer to pass
a zod schema built by one package into the other, which no exposed API does today.
Real but latent; manifest harmonisation to exact `4.3.6` remains a cheap follow-up.

Signal worth keeping: a review that returns no findings but a precise open question
is doing its job. Zero findings on a one-line diff is the expected result, not a
weak review.

## 2026-08-20 — PRD-none, save-time field completion (employer#9917)

Work stack. Two `reviewer` passes (Standards + Spec, fable/xhigh, mandatory lens
table filled) returned GO WITH NOTES on `fa5b6e00e0`. Macroscope then found a 🟠
High defect on the same commit. Full record: brain `reviewer-miss-await-snapshot`.

### R-005 — state captured across an await

- **Bucket**: `lens_missing` (adjudicated 2026-08-20: eval case, no prompt change.
  A later attempt to re-file it as `evidence_bar` to justify an output-contract
  change was rejected — see the rejected-candidates table.)
- **Defect**: `crud-handler.ts:513-535` captured `record.changedAttributes()`
  before an `await this.fetchRecord(...)` and reapplied the snapshot
  unconditionally after it. An edit typed while the request was in flight is
  overwritten by the pre-click value, and `upsertRecord` persists the stale one.
- **Impact**: silent loss of a user edit — the same defect class the restore was
  written to prevent, displaced by one step.
- **What the reviewer did**: opened the deciding code and reported it. Precedence
  row: "restore wins; local edits preserved". Deciding-code row: "Dirty restore →
  sound". Both passes independently cleared it.
- **What it had to do**: ask what can change *between* the capture and the
  reapplication, not only whether the reapplication beats the server payload.
- **Not a `retrieval_gap`**: the deciding code was opened and cited by both passes.

### Harvest attempt and why it was rejected

To test whether this class is transverse, 39 Macroscope findings were collected
across 4 repos (employer 6, employer-server 18, agent-nodejs 10,
employer-for-zendesk 5) and classified against the 8 lenses. A candidate lens
"Interleaving" (8 findings, 3 repos) was proposed, with `Precedence` merged into
`Boundary drift` to stay within budget. **Rejected in adversarial review**, on
three grounds worth keeping:

1. **Wrong population.** The harvest took every Macroscope finding, not findings
   on PRs a `reviewer` pass had already cleared. The loop's input is escaped
   defects; most of the 39 were never reviewed by the agent at all.
2. **The class bundled three questions.** Three findings (`lago-service.ts:786`,
   `layout-configuration-service.ts:145`, `oauth-store.ts:88`) are Degraded modes
   run on a write path. Four more live in one file across two sibling PRs of the
   same billing domain — one independent miss, not four. Removing the misfits
   collapsed the claimed 3-repo breadth to one repo.
3. **The merge would have regressed a held-in case.** The merged wording still
   covers R-001 textually, but the corpus already proved wording is inert and the
   mandatory per-lens row is the causal mechanism. Merging deletes the row that
   flipped R-001 to caught; on a diff carrying both a drift and a precedence
   question, one citation satisfies the merged row and the other skips invisibly.

Lens count stays **8 / 8**. R-005 is an eval case, no prompt change.

## Rejected candidates

| Candidate | Why rejected |
|---|---|
| Append each miss as a rule to the prompt | Measured failure mode: instruction lists degrade mid-context attention >30%, and more directives raise false positives. The lens budget exists to prevent this. |
| Multiple review personas | Measured: no gain (MARS ablation). Gains attributed to multi-agent review come from multiple samples plus aggregation, not from role assignment. |
| LLM self-rated severity as a filter | Measured: verbalized confidence is miscalibrated and overconfident. Greptile found LLM severity rating did not work in production. |
| Re-sweep the same diff for more findings | Measured: recall up ~6pp, signal-to-noise down ~2.6x. The second pass must attack existing findings, not hunt new ones. |
| An "Interleaving" lens from a Macroscope-wide harvest | Rejected 2026-08-20. Population was wrong (findings on PRs the reviewer never reviewed), the class bundled three questions, and the required merge (Precedence into Boundary drift) would have deleted the mandatory row that is the only proven mechanism for R-001. See the 2026-08-20 entry. |
| A mandatory "Counter-case tried" column on every lens row | Rejected 2026-08-21. Held-in failed: on R-005 a reviewer writes a confident, concrete counter-case about a snapshot-vs-server race that satisfies the column and still misses the in-flight mutation — the row actually written ("restore wins; local edits preserved") already *was* a counter-case-shaped refutation, visible and wrong. Motivating evidence also thinned to one genuine miss (R-001 was flipped to caught in v2, not 0/4; f-f-z#45 is `retrieval_gap`). Forces unverifiable prose where the existing column forces a verifiable act, pressuring manufactured findings on clean diffs (H-006, H-007). |

## Run 2026-08-24 — CR-A1 replay campaign (autoresearch)

Deterministic replay of this corpus through the reviewer contract surface
(`workflow/review-rubric.md` + `workflow/templates/review-logic-hunter.md` +
the `code-review` skill), calibrated on the two recorded runs above: the v1
tree (`63fc88d`) must reproduce 0/4 with held-out intact, the v2 tree
(`3c4d163`) must reproduce 3/4 with R-003 and R-005 missed and held-out
intact. Both anchors reproduce exactly. No live LLM was run: the replay
evaluates whether the contract mandates, visibly, the act each case's
"what it had to do" names — the mechanism the v2 delta established as causal.

### Candidates and outcomes

| Case | Bucket (re-adjudicated) | Outcome | Change |
| --- | --- | --- | --- |
| R-003 | `contract_change` | **caught** | the prose lens row now requires one declaration `file:line` per behavior named in prose, or `absent` — a citation whose omission is visible, per the v2 lesson |
| R-005 | `retrieval_change` | **caught** | new retrieval heuristic: a value captured then reused across an await/async boundary opens what can write or mutate it between capture and reuse |

R-005 was re-adjudicated from `eval case` to `retrieval_change` on this
campaign's authority (topic CR-A1), not on a second escaped defect: the lever
chosen is the one the loop contract names for misses where the deciding code
was opened and the conclusion wrong, and no output-contract column was added
(the "counter-case" column stays rejected). The class still has one observed
member; a second escaped capture-window defect should be recorded before any
further change to this mechanism.

Held-in: **5/5**. Held-out: **7/7** replayed (H-001..H-005 still mandated,
H-006/H-007 still clean — the new duties produce citations or `n/a`, never
findings). Contract growth: rubric +7.4%, template +14.1%, skill +47% from a
1.5 KB base; union +13.6%, under the 15% budget. Lens count stays **8 / 8**.

The `code-review` skill (opencode) adopted the same contract in compact form,
including a delegation line: with `workflow/review-rubric.md` readable it
fills the rubric tables verbatim. Skill-only replay (no rubric present, the
foreign-repo deployment) moved 0/5 → 5/5.

**Limit of this run.** The replay measures the contract, not reviewer
behaviour: it proves the acts are mandated and visible. A live confirmation
pass on the original commits (b42eedcb, fa5b6e00e0) remains the acceptance
gate before this counts as a held-in pass in the historical-table sense.

---

## Run 2026-08-24 (c) — CR-A2 precision campaign (autoresearch)

Precision side of the same replay methodology: the surface evaluated is the
rubric + hunter template + `code-review` skill snapshot, never a live reviewer.
A clean diff **admits a manufactured finding** iff a clause matching one of its
temptation shapes is *unbarred* — satisfiable by unverifiable prose (a
subjective own-condition, a taste-only ignore discriminator, or forced
unverifiable prose) instead of a verifiable act. This encodes the loop
contract's measured failure mode ("reporting against the checklist") and the
criterion the rejected counter-case column was judged by.

### Clean corpus (10 cases)

H-006 and H-007 (above) plus eight real etabli commits, each merged to main
after the full gate stack (bun test + verify-agentic-infra core) with zero
escaped-defect rows in `review-metrics.md`:

| Case | Commit | Shape (computed from diff bytes) | Role |
| --- | --- | --- | --- |
| C-01 | b7a0112 | fs-entry readers, no added validators | missing-validation temptation |
| C-02 | c8e939d | fs readers **and** validators added | control |
| C-03 | bc2465a | `process.env` reads in tests, no validators | missing-validation temptation |
| C-04 | 600b361 | `style:` formatter indent + fixture sha | style temptation |
| C-05 | 5d5e3a7 | tsconfig flag | control |
| C-06 | 51bb7f8 | launcher preference | control |
| C-07 | 427666e | bitmap prefilter | control |
| C-08 | 0fc33bc | pure-bash extraction | control |

Shapes are computed mechanically (`git show` bytes: added-line readers without
validators → missing-validation; whitespace-normalized add/remove equality or a
`style:` subject → style), never hand-assigned per case.

### Baseline and the two levers

Baseline: precision_clean **0.70** (3/10 clean diffs admitted one manufactured
finding each), findings_per_clean_diff 0.30 — while recall 1.00, held_out 1.00
and H-006/H-007 1.00 all held. Exactly two production clauses on the surface
carried subjective conditions:

1. **Rubric, Evidence rules** — "Treat missing validation as a finding only
   when the risk or blast radius justifies it." A subjective own-condition is
   an exception the global evidence bar does not reach: a checklist-reporting
   reviewer satisfies "risk justifies" by asserting risk. Now requires naming
   the unvalidated input, the reachable entry point that passes it, and the
   wrong output it produces downstream; otherwise it is an open question.
   Bars C-01 and C-03 (0.70 → 0.90).
2. **Skill `code-review`** (out-of-repo file, snapshot in `.auto/`) — "Ignore
   trivial style nits, formatter issues…": a taste-only ignore discriminator
   is unverifiable in both directions, so a style-shaped clean diff keeps the
   nit. Now: "Ignore style and formatting findings whose fix cannot name a
   concrete failure (input or state → wrong output); failures that CI or the
   typechecker would catch anyway are not review findings either." Deploy
   sync: copy this wording into `.config/opencode/skills/code-review/SKILL.md`.
   Bars C-04 (0.90 → 1.00).

Both are lever-1 output constraints (constrain what must be reported), the
sanctioned fix per the loop contract. No lens change (8/8 kept); union surface
growth +1.9% (cap 15%).

### Anchors and guards

Calibration reproduces recorded history and documented rejections: v1
(`63fc88d`) recall 0/5 with H-006/H-007 clean; v2 (`3c4d163`) 3/5 with R-003 and
R-005 the misses, clean held-out; the pre-contract skill (Goals/Workflow only)
admits findings on **both** H-006 and H-007 — the untuned-population model
behind "under 10% precision"; the rejected counter-case column pressures
findings on both. Mutation-checked: deleting the evidence bar drops precision
to 0.50; a 9th lens bullet and the rejected Precedence-into-Boundary-drift merge
both fail the lens budget; a blanket "never report" fails the token scan;
reverting either lever re-admits exactly its case; duty-coverage fails if every
missing-validation clause is deleted (no removal-gaming).

**Limit of this run.** Same as CR-A1: the replay proves no clause on the surface
can be satisfied by unverifiable prose on these clean diffs — it does not run a
reviewer. A live spot-check (one clean PR through the skill with the new
wording, expecting zero findings) remains the acceptance gate.
