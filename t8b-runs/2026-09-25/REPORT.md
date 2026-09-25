# T8b paid campaigns — execution record (2026-09-25, rounds 1+2)

## Round 1 — BLOCKED pre-launch (record preserved verbatim below)

Phase at round 1: **BLOCKED** (pre-launch, mechanism missing). Paid runs executed: **0**.
Spend observed: **$0.00**. Provider calls: **0**.

## Authorization (as delegated)

- Provider: `zai/glm-5.3` ONLY. Key `ZAI_API_KEY`: present in environment
  (presence checked, value never displayed).
- Hard cap: **$100** (stop before exceeding; run-by-run tracking — moot at 0 runs).
- Wall-clock: 45 min shared from 2026-09-25T14:56:37Z (~15:41:37Z deadline).
- Nominal spec cap noted: the v25 draft / spec.md:108 name $25 + 45 min; the
  delegation's explicit $100 is the operative hard cap. Neither cap was touched.

## STEP 1 — frozen starting point re-verified (GREEN, before any paid run)

- `scripts/token-corpus-check` → exit 0.
- `scripts/t8a-behavior-gate` → exit 0 ("0 frozen bytes changed — 14 files +
  8 budget rows").
- Fingerprints vs `docs/plan/20260925-t8a-ship-surfaces-offline-protocol.md`
  handoff: corpus-manifest `d0a59fb0…`, freeze-record `3ae116bf…`, corpus.json
  `60b54bcc…`, parity-manifest `8e43543c…`, slot-criteria `31128f1c…` — all match.
- Draft `docs/plan/20260925-t8-full-draft.md` sha256 `ea619770…0a181` — matches.
  Both docs above were treated READ-ONLY (no writes).

## Campaign freeze

NOT pinned: pinning is required before the FIRST paid run, and zero paid runs
executed. Graders stay as frozen in the corpus. Paid sampling params
(max_tokens / timeout / retries / temperature for real runs) are unspecified
by the draft — the frozen `report/reference.json` carries `synthetic-1` values
usable only for offline linkage, not transferable to paid runs without a
plan-level decision.

## Screening (0/72) — BLOCKED, campaign never launched

1. The runner has no paid path. `scripts/token-protocol-screen` implements only
   `--dry-run`, `--resolve-all`, `--validate-corpus`, `--local-run`
   (fake-must-fail / fake-canned); any other provider is REFUSED. The draft's
   campaign command lines (no mode flag) match no runner mode at all.
2. A faithful paid path is not minimal: 72 agentic runs need per-variant
   worktrees, `{read}`/`read,grep` tool loops with recorded traces,
   `emit-pointer-follow` + isolated ledger, the slot-10 `dispatch-review` tool,
   the 11-predicate plan-loop grader with proof keywords, §7.2 veto detection,
   read-trace candidate-validity, and per-run usage attribution. None exists;
   building it faithfully exceeds the remaining wall-clock by an order of
   magnitude. A single-call-per-run shortcut would manufacture
   INCONCLUSIVE-by-construction (no read traces → every candidate run INVALID),
   which is theater, not execution.
3. Candidate variant inputs do not exist (plan-loop rewrite, `ready-gate.md` +
   generator, defer-branch pointers). Building them is campaign setup, but it
   is ungated work the draft leaves to the campaign tranche, on top of (2).
4. No credible FULL-cost estimate is possible: no ZAI/glm-5.3 pricing exists in
   the repo (pi models config carries no cost for `zai/glm-5.3`), and the token
   profile of the nonexistent engine is unknown. The launch rule ("FULL
   estimated cost fits the REMAINDER") is therefore unevaluable — this alone
   forbids launch.
5. Frozen-reference incompatibility (protocol gap, reported not fixed):
   `--check-ceiling` / `--check-resources` compare artifacts against the
   manifest-pinned synthetic reference (`model synthetic-1`,
   `provider_endpoint fake`); any paid tuple fails by construction, and the
   report refuses alternate references. AC4/AC6 rows requiring green checks
   are structurally unsatisfiable for paid runs.

Verdict: **BLOCKED** (mechanism missing pre-launch). NOT NONRUN-DEFERRED:
authorization is present and no over-cap estimate exists, so neither
deferral trigger fires.

## Lead/archive replays (0/≤12) — UNCLAIMED-unapplied, 0 files deferred

Only actually-deferred files qualify. No AC3 branch was taken at T8b (T8b
applies the <20% rule against its own campaign-time measure, which never ran
because campaigns blocked before slot selection; T8a took no branch per plan —
its N=11 trial noted review.md at 36.4% but decided nothing). With 0 deferred
files, `tests/pointer-follow-smoke.sh` part (b) stays SKIPPED with reason and
no replay implementation was needed. Files stand UNCLAIMED-unapplied.

## Economic (0/36) — BLOCKED behind screening, campaign never launched

Launch order is screening → lead/archive → economic, and quality-PASS is
NECESSARY for every behavioral publication (R24-B3): with screening BLOCKED,
economic verdicts would be unconsumable orphans. Additionally the same
pricing/estimate gap applies, and the candidate construction (`--patch-first`
USER-concat) does not exist — `scripts/pi-review-hunter` is frozen without the
flag, so the shipped-flow comparison has no candidate arm.

Verdict: **BLOCKED**. Runs 0/36 shared by parity-(i) and cost-(ii); both
UNCLAIMED-by-block, not scored.

## Decision table (final)

Machine-readable: `decision-table.json` (same directory). Summary — obtained
vs UNCLAIMED: screening-quality 0/72 BLOCKED; economic-parity-(i) 0/36
BLOCKED; economic-cost-(ii) 0/36 BLOCKED; lead/archive 0/≤12
UNCLAIMED-unapplied (0 deferred); AC1/AC3/AC4 publications UNCLAIMED (gates not
obtained); contract rewrite NOT-APPLIED (master table demands no rewrite on
zero results — default holds).

## Verdicts applied / writes performed

- Ledger: one `validation_run` event on slug `token-protocol` carrying
  `t8b_phase: BLOCKED` + this decision table (append-only CLI use; no history
  edited).
- New untracked dir `t8b-runs/2026-09-25/` (this report + decision-table.json).
  Nothing written under frozen `tests/fixtures/token-protocol/`.
- No contract rewrite, no frozen-file modification, no commit/push/rebase, no
  secrets displayed. Frozen starting point left byte-identical.

## Unresolved + options (no guessing performed)

1. Build-then-execute split (recommended): a follow-up tranche builds the paid
   engine (runner paid path + tool loop + traces + graders + variant worktrees)
   offline against fake/local models with its own plan; a later funded tranche
   executes with a pinned campaign freeze. Resolves gaps 1–3.
2. Pricing + sampling decision: obtain zai/glm-5.3 unit prices and pin paid
   (max_tokens, timeout, retries, temperature) at plan level so FULL-cost
   estimates are credible. Resolves gap 4.
3. Reference-vs-paid-tuple ruling: decide how `--check-ceiling` /
   `--check-resources` apply to paid artifacts given the frozen synthetic
   reference (plan-level; the reference itself cannot change). Resolves gap 5.
4. Narrow pilot (only with an explicit waiver of screening-first ordering):
   economic-only via `pi --model zai/glm-5.3` + json-mode usage capture +
   out-of-tree `--patch-first` construction. Still needs options 2–3 and hours
   of build; not executable in the remaining window.

---

## Round 2 — build-then-execute (decision: build engine first)

Round 1's five gaps are all resolved and both campaigns EXECUTED under a
pinned campaign freeze. Paid runs executed: **108 consumed** (72 screening
+ 36 economic) + 4 setup probes + 42 discarded instrument runs (v5/v6/v7).
Spend observed: **$9.2509** (cap $100; unattributed bound ≤$12.00 more —
see below). Provider: `zai/glm-5.3` ONLY (key presence-checked, never
displayed). No wall-clock was delegated for round 2.

### Step 1 — readiness re-verified (before any writes)

- `scripts/token-corpus-check`: exit 0 (91 files, 8 prompt bodies, all
  pinned shas green).
- `scripts/t8a-behavior-gate`: exit 1 with ONLY the 2 known round-1
  new-file rows (`t8b-runs/2026-09-25/REPORT.md`,
  `t8b-runs/2026-09-25/decision-table.json`); all 14 frozen files + 8
  budget rows + tree equality green. (The T8a TREE RULE cannot cover T8b
  engine artifacts; T8b's contract differs — disclosed, not hidden.)
- 16 bundle paths hashed to `/tmp/t8b-bundle16-baseline.tsv` and
  re-verified BYTE-IDENTICAL at the end (see below).

### Campaign-time measure (own re-run, same protocol + population)

`parent-read-measure --traces /tmp/t8a-trial-traces --json` →
`ok N=11 spawnless=22`, identical branches to the T8a trial: only
`workflow/skills/review.md` 36.4% (≥20%, DEFER); rubric 0, logic 18.2%,
spec 18.2%, lead 9.1%, archive 0 (all <20%, removal). Taken: slot 10
pointer; slots 9/11/12 neutral; lead/archive 0 deferred (no replays).

### BUILD — the five blockers resolved (offline, $0)

1. **Paid path**: new engine `scripts/token-protocol-campaign` +
   `scripts/lib/t8b-{engine,graders,pi-tools,selftest}.mjs` +
   `scripts/lib/t8b-plan-staging.md`. The 16 bundle paths were never
   edited (re-verified identical at the end).
2. **Faithful screening engine**: real pi tool loops (`--mode json`
   event capture → single ordered trace + final text), per-run worktree
   copies + FS-diff write veto, `emit-pointer-follow` +
   `dispatch-review` runner tools (pi extension), plan-loop 11-predicate
   grader, hunter/dossier/dispatch/logic/spec graders, §7.2 vetoes
   (incl. veto-ii aggregation), candidate-validity + contamination, and
   100% per-run usage attribution. **162/162 offline fixtures GREEN
   before any paid call** (refusals, 12 plan-loop negatives + positives,
   hunter/dossier/dispatch/spec vectors, validity/veto vectors, trace
   mapping, STRONG attestation through the FROZEN verifier, spend math,
   construction equivalence, frozen-report integration, extension stub).
3. **Variant inputs** (campaign worktrees only, never published):
   plan-loop.md rewrite (5 systematics + verbatim triggers + step-1),
   ready-gate.md GENERATED from spec.md (§ Minimal READY gate) with
   generator + `--check`, 5-file budget surface + ceiling,
   pi-review-hunter + `--patch-first` (default path byte-identical argv
   to frozen), slot-10 pointer pair (pointer + verbatim canon target).
   Baseline tree = repo bytes snapshot. Minimal-faithful points are
   documented in RULINGS.md (adapter copy needed no re-stamp — pure
   pointer; mechanical lead filter; runner-attested sha).
4. **Pricing pinned + cited**: GLM-5.3 $1.40 in / $0.26 cached-in /
   $4.40 out per MTok, cache-write $0 (Limited-time Free) —
   https://docs.z.ai/guides/overview/pricing (fetched 2026-09-25).
5. **Reference-vs-paid ruling**: the T8a synthetic reference stays
   authoritative for ALL offline sets (byte-identical); campaign
   artifacts are checked with the UNMODIFIED frozen report against
   `campaign-reference.json` (paid tuple + real prices + resources) via
   `--reference` + `--corpus-manifest campaign-manifest.json`
   (offline-proven green in self-test).

Rulings R-T8b-1…R-T8b-11 (+ R-T8b-1b/10) are recorded in RULINGS.md; all
were fixed before their first governed paid run.

### ESTIMATE — freeze before paid runs, probe-grounded

`campaign-freeze.json` (final v8): model zai/glm-5.3, thinking low,
temperature provider-default (no pi CLI override), max_tokens 131072,
timeout 600s, retries 1 (one campaign-level retry pass over missing
runs), seed 20260925, max_concurrency 4, cap $100, worst_single $1.00,
12 screening tasks + 6 economic patches, 5 engine pins + 2 worktree pins
+ 24 corpus pins. Freeze versions v1→v8 (all pre-completion; v5/v6/v7
   screening attempts discarded as instrument fixes, runs preserved
   under `screening-v*-discarded/` with spend rows kept).
   Probes (under frozen invocation, spend-tracked): A tiny ($0.0006),
   B hunter-clean ($0.0041 — real template shape ⇒ R-T8b-1 blocks mode),
   C emit e2e ($0.0043 — model hallucinates ids ⇒ runner binding,
   STRONG verified), D dispatch e2e ($0.0318 — slash findings +
   pp-null-deref line erratum ⇒ R-T8b-1b + R-T8b-10). Full record in
   ESTIMATE.md + `probe/`.

### EXECUTE — screening (72/72 COMPLETE, freeze v8)

Verdict: **quality-FAIL** — `noninferiority: FAIL — GLOBAL VETO
(false_completion) on task s1 baseline run 1` (first of 42 vetoes).
Cost consumed: $4.3449. Zero missing runs (no retry needed).

| Task | Baseline | Candidate |
|---|---|---|
| s1–s4, s9n, s12n (plan-loop) | all fail+veto | all fail/invalid+veto |
| s5 | f / p / f+veto | p / p / f+veto |
| s6 | f / p / p | p / p / p |
| s7 | p / p / p | p / f+veto / p |
| s8 | f / f / f | f / p / p |
| s10p (pointer+dispatch) | p / f / p | p / f+veto / f+veto |
| s11n | p / p / f+veto | p / p / p |

Veto census (42): 36 plan-loop (literal transcribed bar — 101/336 items
miss on keyword-sparse cited sections, custom/uncited checklists, and
missing item tokens; READY-claimed ⇒ veto per R-T8b-6) + 6
hunter/dispatch FORMAT ARTIFACTS on substantively-correct outputs
(decorated `No findings.`, `none.`, multi-line slash, bulleted blocks,
bare-values blocks, Axis-prefixed `spec: n/a`). 3 INVALIDs (candidate
spec/FULL over-reads without trigger; all veto-coincident). Artifacts
are DOCUMENTED ONLY — the completed campaign is never re-graded, and
the verdict is unchanged either way (plan-loop vetoes suffice).
Notable: s8 hunters found a genuine `??`-widening the clean label
denies (label dispute; corpus rules per protocol); s5B1 (extra
finding) and s6B1 (wrong line) are substantive protocol fails.

### EXECUTE — economic (36/36 COMPLETE, freeze v8)

Verdicts: **parity-FAIL** (frozen `--check-parity` exit 1 on the first
run: template-compliant outputs fail whole-text parse) +
**cost-INCONCLUSIVE** (0/36 strict passes both arms ⇒ no $/task).
Cost consumed: $0.6427. Zero missing runs. Ceiling/resources report
runs exit 2 (same zero-success cause); the artifact tuples equal the
campaign freeze by direct diff (verified). The defects WERE found by
the hunters (see run outputs) but format-rejected by the frozen gate —
the template/parser mismatch, failing closed as designed.

### Lead/archive + smokes

0 deferred ⇒ no replays; pointer-follow-smoke part (b) stays SKIPPED
with reason. T8a smokes re-run post-campaign: hunter-parity (a) PASS,
pointer-follow (a) PASS, canonical-copy ok, prompt-order PASS ($0).

### Master-table application (on obtained results)

- quality-FAIL ⇒ ALL behavioral contract changes stay UNCLAIMED with
  REVERT: AC1 (candidate contract stays worktree-local, unpublished),
  AC2b, slots 9–12 neutral in-tree + pointer machinery UNCLAIMED
  (slot-10 defer branch taken by measure, pointer file UNCLAIMED).
- Economic parity-FAIL + cost-INCONCLUSIVE ⇒ AC4 UNCLAIMED + revert
  (the `--patch-first` flag stays out of the repo script).
- Lead/archive ⇒ UNCLAIMED-unapplied (0 deferred).
- **Contract rewrite: NOT executed** (the master table demands nothing
  on FAIL — reverts only, and nothing was published, so reverts are
  no-ops by construction).

### Spend (observed, run-by-run in spend.jsonl)

Probes $0.0409 (4) + discarded v5 $1.1793 (13) + v6 $1.5381 (15) + v7
$1.5049 (14) + screening v8 $4.3449 (72) + economic v8 $0.6427 (36) =
**$9.2509 observed** (154 rows, cap $100, guard never tripped).
Unattributed bound ≤$12.00 (in-flight runs killed across the 3
pre-completion instrument restarts, worst_single $1.00 each; actual
likely ~$1–2). Worst-case total ≈ $21.25 « $100.

### Integrity notes

- 16 bundle paths re-verified BYTE-IDENTICAL after all work; frozen
  corpus/report/oracle/smokes/templates imported, never edited; no
  files added under `tests/` or `tests/fixtures/token-protocol/`.
- Self-test 162/162 GREEN at freeze v8 (re-run post-campaign).
- New files: engine (6), worktrees, freeze/reference/manifest,
  RULINGS.md, ESTIMATE.md, probe/, screening/, economic/,
  screening-v*-discarded/, spend.jsonl, REPORT/decision-table updates,
  ledger appends. No commit/push.

### Unresolved

1. Hunter format-coverage gaps (6 screening vetoes + 36 economic fails
   on substantively-correct outputs) — documented; verdicts stand.
2. pp-clean-2 label dispute (genuine widening vs clean label).
3. R-T8b-10 erratum (frozen economic gate keeps {3}).
4. Screening hunter/s10 signals preserved but moot for the verdict.

