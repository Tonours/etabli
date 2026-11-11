# Implementation Loop Contract

Shared implementation contract; adapters supply harness syntax. Select the route
in `workflow/spec.md` before the risk tier. Plan routes and high-risk work use
the full sequence. A bounded runtime fix follows the bounded-fix variant below
unless a plan is requested; an existing DRAFT/CHALLENGED plan blocks implementation.
Review-only requests and host-restricted effects follow `workflow/spec.md`
(routing obligations, § Human checkpoints).

## Risk tiers

Record `tier: small|bounded-fix|standard|high-risk` before step 0; upgrade when needed,
never downgrade mid-run.

- **small** — docs-only, config-only, or a bounded single-surface edit with no
  runtime behavior change, outside contractual and AGENTS high-risk surfaces.
  Also includes non-semantic editorial text on contractual paths: wording,
  links, examples, comments or test failure messages. Exclude AGENTS high-risk
  surfaces, directives, prompt/heredoc strings, smoke-pinned contract text,
  executable/assertion logic, routes, gates, obligations, schemas and locks.
  Verified generated `skills-lock.json` hashes may follow editorial skill text;
  other lock changes are excluded. Runs **outside the plan gate**: scoped recon
  (0), implement (8), applicable product-flow check (11), focused checks (12),
  combined simplify/quality (12b+12c), report (17). Self-review replaces hunters
  and adversary passes (accepted risk: no external feedback). No plan or READY
  gate unless requested. A contractual path alone does not upgrade editorial text.
- **standard** (default) — runtime code change on a known surface. Full
  sequence below; step 13b falls back to a documented same-family
  double-sample only when every eligible cross-model route is unavailable.
- **bounded fix** — a standard variant: a reproducible defect fixed on one
  known surface that is not a contract, guard, installer/deploy script,
  settings sync, migration, or high-risk surface. No plan file, no plan
  adversary, no READY gate. Journey: recon (0), a failing reproducer plus a
  valid and an invalid neighbor (8), focused checks and mutation probe (12),
  simplify (12b), quality (12c), then exactly one fresh-context independent
  review of the cumulative diff in place of steps 13 and 13b: by default a
  fresh Claude `reviewer` subagent (a read-only Pi hunter on Pi),
  cross-family preferred when a route is available, a same-family review
  labeled `same-family` in the report; then report (17). Evidence the sequence
  records in `PLAN.md` goes in the final report. Re-review follows
  `workflow/skills/review-rounds.md` § Bounded fix. Any high finding, a fix
  that leaves its surface, or one that touches a contract upgrades to
  standard with a plan.
- **high-risk** — kernel guards, installer/deploy scripts, security, multi-surface contract changes, or a third
  recurrence of the same failure. Full sequence, cross-model adversary
  mandatory (13b), both hunters mandatory (13).

## Standing rules

`workflow/spec.md` § Rules governs every step and wins on conflict.

- Before a mutable local-device or server action, name the exact target, the
  control path, and the post-check.
- Golden principles: `workflow/contract-details.md`.
- Phase changes load the active route; prior procedures, decisions and tasks are
  evidence, not active work. User authority, safety gates and open findings persist.
  Keep review context isolation (`workflow/skills/review.md`).
- At the next stable checkpoint after a material unexpected failure, recovered
  or unresolved, use `workflow/skills/investigation.md` § Learning from run evidence.
  This adds no retry allowance, per-tool judge or change to the no-progress stop.
- A session handoff goes in `PLAN.md` § Notes / Handoff: goal/phase, branch/SHA,
  proved checks, open findings, evidence paths, next action and do-not-redo.
  Replace stale state, never paste a transcript. Finish or hand off a started migration.
- Keep the handoff within 400 words, including owner decisions/constraints,
  acceptance criteria and all open safety findings. Link full reports and hashes;
  indispensable state may exceed the target with an explanation, never truncation.
  At a stable checkpoint, persist this packet before a session transition; the
  next session reads it and verifies the live plan status/ref before continuing.
  No automatic clear, compaction or restart. Phase changes do not unload skills;
  do not replay old procedures as current work or erase their unresolved decisions.

## Required Sequence

Steps 1–7 apply to plan routes only; the **small** tier and the **bounded fix**
follow their journey in Risk tiers instead (no plan file, no plan adversary, no READY gate).

0. Understand before planning: run a scoped local recon of the affected area
   and carry file:line findings into the plan (the task, for small).
   Recon is parent-only unless the user opts into a scout. Small tasks need a quick read.
1. Choose the route before entering the plan loop: ordinary reproducible,
   single-surface bugfixes may use the **bounded fix** journey above. Explicit
   plan requests (including `/plan-implement`) and existing plans keep their
   plan gates; do not silently reroute those invocations.
   Uncovered task: run `workflow/skills/plan-loop.md`; another task's READY
   plan does not cover it.
2. Otherwise read root `PLAN.md` and verify task coverage.
3. Continue only when the actual root `PLAN.md` has `Status: READY`; prompt
   wording such as "PLAN.md ready" is not proof.
4. Stop from `DRAFT`, `CHALLENGED`, missing `PLAN.md`, or missing concrete
   checks/required evidence.
5. Run `workflow/skills/adversary.md` before editing.
6. Fold accepted findings; reconcile criteria and Decision Log.
7. Re-review material deltas; implement only the approved current contract.
   At READY, an interactive user may choose a fresh `/implement` session
   using the plan handoff to avoid carrying planning exploration into code.
   Continue the current run by default; never automatically clear, compact,
   restart or impose a session transition.
8. Implement the still-`READY` plan steps (the task, for small) in order with minimal, scoped
   changes. A code behavior change ships with its tests per
   `workflow/spec.md`; a bug fix starts from a failing test that reproduces
   the issue, a valid neighbor and an invalid neighbor. Preserve the bounded
   input domain and verify the decisive runtime/corpus when applicable. Repeated
   findings in one family trigger a method reassessment before another patch.
   At most one worker writes at a time: invoke it in the
   foreground, or wait for the worker and do not write until it returns.
   On Claude, prefer an existing fresh-context `worker` for a bounded slice
   when it saves substantial intermediate reads/edits/tests: its configured
   Sonnet/medium defaults apply. Delegation stays optional. Codex may use its
   available native worker when authorized; Pi keeps execution parent-only.
   Give only the slice, relevant files/invariants and proof commands; the
   parent verifies the diff and results before updating the plan.
   The parent remains the only `PLAN.md` writer and reads every integrated diff: a worker report locates the work,
   it does not evidence it.
9. Record progress in task markers or nested check `last run`.
   Material plan facts require reconciliation and fresh approval; see
   `workflow/skills/execution-quality.md`.
10. If facts materially invalidate route, scope, checks, or required evidence,
    stop as `plan drift detected`; update `PLAN.md` and do not continue until it
    is refreshed to `READY`.
11. For product-flow changes, exercise the affected flows through existing
    tests or a direct run. Human-only legs stay `blocked`.
12. Re-run the plan's focused checks after the product-flow check and each
    accepted fix — readiness never rests on checks predating the latest product-flow edit.
    Save verbose check output to a private artifact; capture the command's exit
    code before summarizing counts, failures and the artifact path. Read relevant
    ranges on demand. Preserve raw machine-consumed data, canonical council
    streams and required review tables; summaries never replace decisive evidence
    or turn a failed command into success. No blanket output-rewriting hook.
    Small tier and bounded fix (no plan): run the surface's own focused checks instead —
    the checks named by the task or the touched surface's suite.
    Mutation probe (standard, bounded fix included, and high-risk tiers, diffs touching executable
    sources: `.sh`, `.bash`, `.js`, `.mjs`, `.cjs`, `.ts`, `.tsx`, or an
    extensionless `bash`, `sh` or `node` script), once these checks are green: run
    `node <probe> --base <base> --test "<focused test command>"` with the
    plan's base commit (`git merge-base HEAD <default branch>`), adding
    `--check "<type-check command>"` when TypeScript is touched and one exists,
    and `--allow-write <dir>` only for a directory the test is known to write
    (from its code), recorded with its reason.
    Resolve `<probe>`: workspace `workflow/runtime/mutation-probe.mjs`, then `~/.pi/agent/workflow/runtime/`, then `~/.claude/workflow/runtime/`.
    It needs the macOS write sandbox and refuses inside another sandbox (on
    Claude Code, run it in the unsandboxed Bash mode) and where a denied write
    does not stop the writer (measured on macOS 14.4). Each survivor gets a
    killing test or a one-line justification (equivalent mutant, untestable
    side effect) in `PLAN.md` § Checks (the final report without a plan).
    Record in § Review Changes:
    - `mutation: N survived of M, K justified` (append `, no type check` when
      TypeScript was mutated without `--check`);
    - `mutation: n/a (<reason>)`: no mutable lines, no runnable test command;
    - `mutation: inconclusive (<reason>)` after fixing the check or test
      command once, as residual risk;
    - `mutation: unavailable (<reason>)` when the tool cannot be resolved or
      run (no sandbox, refusal), as residual risk, never a block.
12b. Combined local pre-review pass once checks are green: run 12b+12c together,
    keeping both scopes and records. Simplify **this diff only**.
    Stop at the first rung that holds; delete or rewrite what a higher rung
    already covers. No behavior change.

    1. Does this addition need to exist for the READY plan (the task, for small)? If not, delete it.
    2. Already in this repo? Reuse it; do not reimplement a nearby helper.
    3. Language builtin or stdlib?
    4. Native platform feature (HTML/CSS/OS/DB constraint)?
    5. Already-installed dependency?
    6. One straightforward expression or early return?
    7. Only then: the minimum that works.

    Cut from this change: unrequested interfaces/factories/config, comments
    restating the code, `any`/defensive try-catch hiding types, dead
    branches, duplicate helpers — readable beats clever. Never drop
    trust-boundary validation, data-loss handling, security, accessibility,
    or required tests.

    Re-run focused checks if anything was edited. Record `simplify: clean` or
    `simplify: removed N` in `PLAN.md`.
12c. Quality lens in that same pass, on the cumulative diff: invoke `code-quality` when the
    runtime exposes it, else the narrowest exposed domain or project skill,
    else compare the diff with 1–3 local sibling implementations. Record
    `quality: pass` (naming the producer) when a pass ran, or
    `quality: unavailable` (naming what is missing) with neither — then stop
    before completion; never present
    the missing pass as clean. Fix mechanical convention findings;
    report behavioral ones. Re-run focused checks if the pass edited anything.
    Skip only for pure docs or plan-only changes, and say so.
13. Review the **cumulative workspace patch that can ship** against `PLAN.md`
    per `workflow/skills/review.md` and `workflow/review-rubric.md`. Pin staged,
    unstaged, and relevant untracked implementation files in addition to the
    committed `git diff <merge-base-with-base-branch>...HEAD`. A clean
    single-commit branch may review that commit; per-slice reviews are insufficient.
    Pin once; dispatch fresh Logic and Spec hunters: both for high-risk;
    standard may use Daily Pi per `workflow/skills/review.md`. When its
    trigger fires, add the Threat hunter and write and run its attack tests
    (`workflow/skills/review.md` step 5b). Autonomous
    runs require fresh context (subagent reviewer or cross-model).
    Record `reviewer_model` and whether deciding-code rows were complete. A
    `GO` without runtime deciding-code is invalid: `blocked` / re-review.
    Missing eligible runner or required authorization: `blocked`.
13b. Code-diff adversary per `workflow/skills/adversary.md`: tiered —
    **high-risk and standard require cross-model**; **small skips**. Standard
    falls back to a documented double-sample only when every eligible route is
    technically unavailable (`workflow/skills/adversary.md` § Code diff mode).
    An answer without effective-model provenance, or truncated, is rerun once;
    still unproven or truncated → `blocked`, never the fallback.
    Single same-family pass alone → `blocked` (the bounded fix's labeled single review aside).
    Name `adversary_model` (or `same-family-pass` ids plus
    `cross_model: unavailable (<category>)`).
    **High** findings: accept/reject via cross-model (or second sample), not
    the implementer alone. Fold accepted findings and re-run checks. Any
    accepted fix invalidates cumulative review and code-diff adversary evidence
    it can affect: re-review follows the review budget below.

    Review budget: one T/D counter per run.
    Default path: T1 clean → VALIDATE; only blocking findings (high, unmet
    AC, `BLOCK`) spend a round, residual non-blocking ones go in the final
    report. Otherwise follow the bounded machine in
    `workflow/skills/review-rounds.md`; never validate past its ceiling.
    Record every pass in the review evidence: tour (T/D + number),
    scope (full/delta), base SHA, patch SHA, reviewers, round outcome, in
    `PLAN.md` § Review Changes.
14. Archive the final implemented plan in `docs/plan/YYYYMMDD-short-slug.md`:
    fill `workflow/templates/plan-archive.md` (convention, hash gate and
    multi-repo rules: `workflow/plan-archive.md`); distill it as memory, do
    not raw-copy `PLAN.md`.
15. After archive and validation succeed, delete only root `PLAN.md`.
16. Otherwise keep it and report why.
17. Return files changed, tier, adversary result, validation, review result
    (including deciding-code completeness), archive path, deleted `PLAN.md`
    status (both N/A for small: no plan, no archive), remaining risks,
    next action if any, and final status.
18. Before any push, run the project's complete relevant check group on the
    final diff. A red group blocks push even when focused checks passed. When
    the branch has an open PR, re-read its body against the final diff first
    (`workflow/pr-body-contract.md` § Honest status).

## Long loops

Open-ended improvement/benchmark loops follow `workflow/skills/long-loop.md`.

## Completion Evidence

Autonomous completion requires:

- recorded risk tier;
- adversary plan review (standard/high-risk; not a bounded fix);
- adversary code-diff review (standard/high-risk: named model; standard
  fallback: double-sample with `cross_model: unavailable (<category>)`;
  a bounded fix has its one review instead);
- focused validation;
- product-flow evidence when required by the plan;
- mutation probe result (`mutation: …`) on standard (bounded fix included) and high-risk diffs
  touching executable sources;
- simplification pass result (`simplify: clean` or `simplify: removed N`);
- quality pass result (or explicit skip for docs/plan-only);
- Logic+Spec lead review on the cumulative shippable workspace patch with a
  complete deciding-code table for runtime diffs (self-review only for small
  tier; one fresh-context review, cross-family or labeled `same-family`, for a bounded fix);
- review and adversary provenance in `PLAN.md` § Review Changes;
- implemented-plan archive under `docs/plan/` and root `PLAN.md` cleanup
  after successful archive and validation (when a plan existed; small tier
  has none).

