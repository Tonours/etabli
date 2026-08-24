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

---

## Run 2026-08-24 (d) — CR-A3 escaped-per-GO campaign (autoresearch)

Third replay campaign on the same surface, new question. CR-A1 asked *is the
deciding act mandated?*; CR-A2 asked *can a clause be satisfied by unverifiable
prose on a clean diff?*; CR-A3 asks **does the skip invalidate `Verdict: GO`?**
— the metric the loop contract names as its target: escaped defects per GO.

### Model

An escaped defect is one that ships behind a GO the contract itself accepts:

```
escape(d) = NOT ( surface mandates d's deciding act
                  AND  skipping that act invalidates Verdict: GO )
```

Pilot ledger: 20 real GO-marked review events — the two defect-carrying PRs
above (#1810 with R-001..R-004, #9917 with R-005) plus 18 clean gate-passed PRs
(H-007/#1809, C-01..C-08, and nine further etabli work commits). Defect events
keep their historical GO WITH NOTES (caught defects become fixed-before-ship
notes, as the corpus records for the two v2 findings); clean events must all
still reach GO (`go_rate_clean` 1.00 — a contract that stops issuing GOs is
broken, not better). No denominator is winnable by blocking clean diffs.

### Baseline: escaped_per_go 0.25 (5/20)

CR-A1's replay scored all five R-cases "caught" at the mandating level. At the
GO level they were not: the surface offered two skips that kept `Verdict: GO`
valid —

1. every lens row could be left `not run` (the rubric blocked GO only on
   *empty deciding-code rows*, never on `not run` lens rows), so R-001..R-004
   could all ship behind a GO with the lens table visibly skipped;
2. the whole-diff `n/a — no runtime behavior` was an unverifiable own-condition
   (the same class CR-A2 barred for findings), so the deciding-code table —
   the only catcher of R-005's capture-window writers row — was omittable.

Same adversary as CR-A2, other direction: the checklist-reporting reviewer
satisfying the letter of the output contract.

### The two levers (both lever-1, output contract)

- **Lens rows**: on a `Verdict: GO`, every lens row carries `file:line`,
  `absent`, or `deferred: Standards hunter` — a `not run` row blocks GO the
  same way an empty deciding-code row does (Convention §5's no-skill,
  no-sibling `not run` stays a recorded gap, never a pass). A skip is not a
  result.
- **Whole-diff `n/a`**: now an artifact-backed claim — the row lists every
  changed path, and each must be a document or pure rename; any other changed
  path makes rows mandatory and the bare `n/a` an invalid skip.

Mirrored compactly in the hunter template and the `code-review` skill. Result:
**escaped_per_go 0.00 (0/20)**, `deciding_code_complete_rate` 0.00 → **1.00**
(the GO gate now enforces complete deciding code), with recall 1.00,
precision_clean 1.00, held_out 1.00, H-006/H-007 clean, lens budget 8/8, union
surface 13 389 B (+8.7% over the CR-A1 base 12 321 B, cap 15%).

Mutation-checked at clause level (wording-independent ablation): deleting every
lens-block clause re-escapes R-001..R-004 (≥ 4); deleting every n/a-artifact
clause re-escapes R-005. The v1 tree still anchors at 5 escapes.

### Pipeline wiring (the "log vide" half of the topic)

`review-metrics.md` had zero rows, so the metric read `—`. Seventeen real etabli
GO events were backfilled (unknown fields left `n/a`/`unrecorded`, never
invented; work-stack events stay out per the storage rule), the loop contract
now appends the row **at the GO** (a GO with no row is an incomplete review
output — an unlogged GO silently shrinks the denominator), and the
escaped-defect template records its `metrics_row` side effect (update the PR's
row, never a second row). The bench enforces all-or-nothing coverage,
one-row-per-PR, and `escaped_later 0` on backfilled rows.

### Limits

Same as CR-A1/A2 (contract-level replay, no live reviewer; a live confirmation
pass remains the acceptance gate), plus two CR-A3-specific ones: per-behavior
deciding-code row enumeration is not mechanically forcible (a multi-behavior
diff can carry one row; only the whole-diff `n/a` is bar-able), and the "row
filled with a citation, conclusion wrong" shape (R-005's v2 miss, `evidence_bar`)
remains beyond any output contract by the loop contract's own measurement.
f-f-z#45 (`retrieval_gap`) is excluded from the ledger: the repo holds no case
detail for it, so it cannot be replayed honestly.

---

## Run 2026-08-24 (e) — CR-A4 lens-skip campaign (autoresearch)

Fourth replay campaign on the same surface. CR-A3 asked whether a skip
invalidates `Verdict: GO`; CR-A4 asks the row-level question the
`lens_existed_not_run` bucket names: can a checklist-reporting reviewer emit a
lens-table row as `not run`, a bare `deferred`, or a misplaced `absent` and
still produce an output the contract accepts, on **any** accepting verdict?

### Model

Per ledger event (the CR-A3 20-event ledger), the reviewer picks the accepting
verdict vehicle that maximizes skips, then writes the cheapest cell per row the
surface still accepts; the bench parses the emitted tables with the metric rule
(skip = `not run` / unsanctioned `deferred` / `absent` outside the Prose row;
fill = `file:line` or a sanctioned cell). `proseBehaviors` per event is computed
from diff bytes (added comment/doc lines), never hand-assigned. Two deployment
modes: full (rubric + template + skill) and skill-only (the foreign repo).

### Baseline: enforced skip_rate 1.00 (160/160 rows skippable)

The recorded cooperative runs show 0.00 — that was not enforcement. Three holes,
all lever-1:

1. **`GO WITH NOTES` vehicle** — the `not run` block named `Verdict: GO` only;
   the explicit "GO WITH NOTES is not a workaround" extension existed for
   deciding-code rows, never for lens rows. Both defect PRs shipped GO WITH NOTES.
2. **`absent` anywhere** — the GO enumeration offered `absent` as a valid cell
   for every row; it is defined only for the Prose row.
3. **bare `deferred` anywhere** (skill surface) — the skill's GO bullet blessed
   "`file:line`, `absent`, or `deferred`" on any row.

### The levers

Mirrored in rubric, hunter template, and `code-review` skill: the enumeration
becomes `file:line`, `absent` (Prose row only, no behavior named in prose), or
`deferred: Standards hunter` (Convention row only, `Standards: yes`); a `not
run` row blocks `Verdict: GO` and `Verdict: GO WITH NOTES` alike (a notes
verdict is not a workaround for a skipped lens); any other cell is a `not run`
skip. Result: **skip_rate 1.00 → 0.00**, `fill_rate` **1.00**, `cite_rate`
0.9812 (the three non-cite rows are the sanctioned cells: Prose `absent` on the
two no-prose diffs, Convention `deferred: Standards hunter` on #9917);
skill-only 0.00.

Mutation-checked at clause level: ablating the family sentence re-opens 1.00;
removing the Prose-row confinement re-opens ≥ 0.9; un-sanctioning
`deferred: Standards hunter` re-opens ≥ 0.9 in both deployment modes. v1
anchors at 1.00 (7 lenses listed → 0 run); v2 anchors at 1.00 — the mandatory
table alone never enforced the skip rate, which is CR-A3's verdict-level finding
restated at row level. Guards: CR-A1 recall 1.00 / held_out 1.00, CR-A2
precision_clean 1.00 / findings 0, CR-A3 escaped_per_go 0.00 / go_rate_clean
1.00 / metrics_row_coverage 1.00, lens budget 8/8, union surface 14 136 B (cap
14 169 B, +15% over the CR-A1 base), no forced-prose clause.

### Limits

Same class as CR-A1/A2/A3: the replay proves no accepted output can carry a
skipped lens row — it does not run a reviewer; a live confirmation pass (one GO
WITH NOTES review through the new contract, all 8 rows cited) remains the
acceptance gate. Row-level enforcement cannot force a *correct* citation (a row
may cite code the reviewer never opened — the CR-A3 "citation, conclusion
wrong" limit, unchanged), and the sanctioned cells stay trust-based until the
Prose `absent` / Standards-deferred claims are themselves diff-checkable.

---

## Run 2026-08-24 (f) — CR-A5 prose-catch campaign (autoresearch)

Fifth replay campaign on the same surface. CR-A3 asked whether a skip
invalidates `Verdict: GO`; CR-A4 asked it per row; CR-A5 asks the question the
corpus had left open (line 141: the lens "ran and reported" and still did not
catch): **at the finding level**, can a checklist-reporting reviewer fill the
Prose row and emit an accepted output with no finding that names the
prose-vs-declaration mismatch? CR-A1 had scored R-003 caught at the *mandate*
level — a citation duty existed in the lens bullet — but the bullet is an
instruction, and the v2 delta's own lesson is that instructions do not run.

### Model

Per case (prose behaviors each with a carrier kind and a declared flag), the
bench generates the cheapest legal Prose-row cell the output contract still
accepts, in adversary order, then parses it with the topic rule (caught iff a
finding mentions the prose-named behavior and the missing declaration):

1. `not run` — barred since CR-A3/A4 on accepting verdicts;
2. `absent` — open while the Prose line offered it as "or `absent` when none
   exists": the lazy reading takes *none* as *no declaration found* (Route A,
   the recorded v2 shape: row reported, no finding);
3. untyped citations — open while the cell contract accepted any `file:line`:
   the producer or the prose location itself looks like work (Route B, also
   "ran and reported");
4. typed per-behavior cells — for a behavior with no declaration, the only
   honest typed cell is `no declaration → finding`, but only if the contract
   names it; otherwise an adjacent untyped cite remains an invisible violation.

Features are read from output-contract positions only (rubric Mandatory output
tables, hunter template, skill Contract), never from the lens bullet.

### Baseline: r003_caught 0.00

On the post-CR-A4 tree the adversary writes `absent` (Route A) and, if that
were closed, untyped cites (Route B). v1 and v2 anchors both reproduce the
recorded miss. The three injected carrier cases (config key, parameter, schema
entry) all miss identically: `prose_findings_recall` 0.00.

### The lever (output contract, mirrored across the three surfaces)

The Prose row cell contract becomes: list **each behavior named in prose**
with its declaration — *parameter, schema entry, config key* — `file:line`,
or `no declaration → finding`; `absent` only when prose names none. The lens
bullet shrank to the question plus the discriminator ("a runtime producer is
not a declaration"), funding the row's growth inside the 15% cap (union
14 136 → 14 160 B). The retrieval heuristic follows: documented field → cross
**prose + declaration + runtime producer**.

Bars Route A (the tie names *what* is absent), Route B (a typed citation
names its carrier; runtime code is none of the three), and gives the
no-declaration branch its only legal, finding-shaped cell. R-003's replayed
row: `X-employer-Timezone → no declaration → finding; CountResponse → schema
entry file:line` — the sweep discriminates the declared sibling instead of
flagging everything.

### Results

| Metric | Baseline | Final |
|---|---|---|
| r003_caught (full surface) | 0.00 | **1.00** |
| prose_findings_recall (3 injected carriers) | 0.00 | **1.00** |
| skill_only_r003_caught | 0.00 | **1.00** |

Mutation-checked at clause level: ablating the absent-tie, the kind-typing, or
the no-declaration cell each re-opens the miss. Guards all held: CR-A1 recall
1.00 / held_out 1.00, CR-A2 precision_clean 1.00 with zero findings on clean
diffs, CR-A3 escaped_per_go 0.00 / go_rate_clean 1.00, CR-A4 skip_rate 0.00
/ fill_rate 1.00, lens budget 8/8, no instance tokens, no forced prose, and
the declared-behavior + no-prose controls stay finding-free (`absent`
remains the sanctioned no-prose cell, so CR-A4's cite_rate expectation is
unchanged).

### Limits

Same class as CR-A1..A4: the replay proves no accepted output can fill the
Prose row without the finding on these cases — it does not run a reviewer; a
live confirmation pass on b42eedcb remains the acceptance gate. A reviewer can
still fabricate a typed citation ("X → parameter file.ts:9" where none
exists) — the kind label makes that mis-cite *visibly checkable* by the parent
against the pinned diff, but the replay cannot verify referents (CR-A3's
"citation, conclusion wrong" limit, restated). The `absent`-when-no-prose
claim itself stays trust-based until prose lines are diff-enumerated in the
row.
