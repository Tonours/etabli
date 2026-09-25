# T8b rulings (build-then-execute, 2026-09-25)

Minimal faithful readings where the v25 draft leaves campaign mechanics to
the tranche. All were fixed BEFORE their first governed paid run (freeze
v1–v5, probes A–D); none were adjusted on campaign results.

## R-T8b-1 — finding extraction per block (screening hunters)

Hunter/spec outputs are parsed per finding: 7 key-ordered `key: value`
lines validated by the FROZEN parser, plus slash-form lines (R-T8b-1b).
Lens tables, verdict lines, headers are not findings. Justification: the
draft's grader rule is phrased per finding block, R17-B2 forbids touching
prompts to bias variants, and the real templates mandate extra sections —
whole-text parsing would veto every template-compliant output. Screening
only; economic `--check-parity` keeps the frozen whole-text path.

## R-T8b-1b — slash-form findings (probe-D evidence)

Real hunters emit the template's literal format line slash-joined on one
line (`high / users.js / 2 / issue / impact / review_comment /
suggested_fix`). Grammar: ≥7 ` / `-separated parts, severity word first,
spaceless path second, int line third (a `line_range` does not localize),
tail parts joined for the keyword regex. Table rows/headers/lists excluded
by construction.

## R-T8b-2 — length stop grades FAIL, never veto

`stopReason=length` is a runner ceiling event, not model behavior.

## R-T8b-3 — pointer-task baseline surfaces

Baselines run WITHOUT `emit-pointer-follow` (no pointers by construction);
s10 baselines keep `dispatch-review`. Contamination is checked on traces.

## R-T8b-4 — prohibition 11 (conservative)

Any raw HTML tag outside fenced code while claiming READY fails the
prohibition. Positives use fenced HTML, which passes.

## R-T8b-5 — veto (ii) requirements

Plan-loop = the 11 gated items each (grader per requirement);
hunter-defective = ≥1 fully-conforming finding (without the every-finding
rule, so flips stay possible); hunter-clean = zero findings; pointer =
the single functional verdict. Baseline-satisfied = ≥2/3 baseline runs;
any candidate run failing it ⇒ GLOBAL veto (literal transcription).

## R-T8b-6 — plan-loop false completion

Veto (i) = claiming READY while applicable items fail (verdict contradicts
items). Honest NOT READY with failing items is a task FAIL, not a veto.

## R-T8b-7 — successful-read counting

A file counts "read" iff the trace holds a SUCCESSFUL (ok, non-error)
read call with the path in args, any range.

## R-T8b-8 — s11 candidate runner span + emission

The runner authors the `resolve_pointer` span AND the `pointer_follow`
emission (producer=runner); the hunter runs `--tools read,grep`. Same
STRONG predicate, verified by the frozen script on the runner-built trace.

## R-T8b-9 — economic strict whole-text verdicts

Economic run verdicts use the FROZEN whole-text parser so verdicts agree
with the frozen `--check-parity` (which cannot change). Diverges from
screening (R-T8b-1) on template-compliant outputs by frozen necessity.

## R-T8b-10 — pp-null-deref lines {2,3} (screening-only erratum)

The defect sits on NEW-file line 2 (`+  return getUser(id).name;`); the
manifest pins {3} (old-file numbering of the removed guard — inconsistent
with every other patch's new-numbering pins: off-by-one {2},
swallowed-error {2..6}, spec-breach {2} are all new-numbered). Screening
accepts {2,3} (true location + pinned value); findings elsewhere still
fail. The frozen economic gate keeps the manifest pin (forced).

## R-T8b-11 — plan-loop contract staging (v6 evidence)

Plan-loop runs carry a variant-IDENTICAL system role prompt
(`scripts/lib/t8b-plan-staging.md`, pinned): "You are a planner. Read
and follow the planning contract in `workflow/skills/plan-loop.md`,
beginning with its § Source resolution. Use only the read tool. Your
final message is the complete PLAN.md." Without staging, the candidate
validity rule (all five systematics read) is unsatisfiable by
construction — the frozen bodies never invoke the contract, so unstaged
models read only the subject file (v6: s1/candidate/r1 read exactly
{scripts/workflow-event} ⇒ INVALID-by-construction). The staging is
symmetric (same bytes both arms); only the contract files differ (the
treatment). Hunters are staged by their templates; pointer tasks by
their self-sufficient bodies (probe C/D validated).

## v8 instrument notes (v7 evidence, pre-completion)

- Citation detector completed with `→ Section` / `-> Section` forms
  (v7 s1/candidate/r1's canonical 11-item list used them exclusively).
- Candidate contract names the SKILL systematic explicitly
  (`pi/skills/plan-loop/SKILL.md` — matches the budget surface; the bare
  "route's SKILL.md" reference did not resolve, 4/5 reads observed).
- Keywords-per-cited-section and R-T8b-6 KEPT LITERAL (transcribed bar;
  keyword-sparse terse sections fail as written, veto on READY-claim).

## R-T8b-6 complement — verdict-claim line rule (v6 evidence)

A line is a verdict line iff it carries a verdict word
(verdict/status/final/decision, word boundaries) or starts with a bare
claim (READY / NOT READY / CHALLENGED, optional bold); the last
classified line wins (`**READY** — …` counts; mid-sentence claims do
not, by precision design).

## Reference-vs-paid-tuples ruling (blocker 5)

The T8a synthetic reference (`synthetic-1`, `report/reference.json`)
stays authoritative for ALL offline/frozen sets (linkages, oracles,
smokes) — byte-identical, never edited. Campaign artifacts are checked
with the UNMODIFIED frozen report against `campaign-reference.json`
(model zai/glm-5.3 tuple + pinned ZAI prices + campaign resources) via
`--reference` + `--corpus-manifest campaign-manifest.json`.

## Executability notes (disclosed, not rulings)

- sha256 is runner-attested from JSONL-recorded bytes (models cannot
  compute it; probe C also showed models hallucinate tool_call_ids, so
  the runner binds citations to real calls with a unique-path fallback).
  Anti-fabrication holds: exact-call binding + order + attested bytes.
- The dispatch Spec phase carries `spec: n/a` (no intent exists for the
  pinned patch); spec-phase format issues FAIL the task, never veto.
- Dispatch-child crash/timeout/non-terminal ⇒ run MISSING (crash path),
  never a soft verdict. Model-provenance mismatch ⇒ MISSING.
- Candidate `plan-loop.md` rewrite, `ready-gate.md` + generator + `--check`,
  5-file budget surface, `--patch-first` hunter, and the slot-10 pointer
  pair live ONLY in campaign worktrees (proposed inputs, unpublished);
  the repo contract rewrite stays gated on quality-PASS per the master
  table. The pi adapter copy needed no re-stamp (pure pointer).
- Lead filter inside dispatch is mechanical (parse + retain + id-chained
  verdict); Logic/Spec phases are real model calls.
