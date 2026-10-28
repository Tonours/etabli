# Review Contract

Shared contract for reviewing local changes, branch diffs, or commits.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the read-only default, finding format, plan-compliance check, verdict
labels, deciding-code gate, or hunt/filter split.

## Purpose

Review changes for correctness, regressions, risks, validation gaps, convention
or pattern drift, and plan drift. Use `workflow/review-rubric.md` as the source
of truth when available.

Routing: any uncommitted change, branch diff, or commit pinned for
examination — whatever words the request uses (inspect, check, look at,
review) — IS a review: resolve the target, dispatch hunters, end with a
Verdict line. Free-form commentary without the contract is the failure mode.

## Hunt and filter

Parent pins the patch and Intent, then dispatches hunters. Lead filters.
Same-session Logic self-review is forbidden.

1. Resolve the target (below), then **pin the patch once** (capture `git diff` /
   `git show` bytes). Hunters receive that text and do not re-run `git diff`.
2. Supply Intent plus current plan/Decision Log to Spec, Threat and lead; omit
   these from Logic. Reconcile conflicts before dispatch.
3. Detect language/UI surface. Set `Standards: yes` or `Standards: none` on the
   Logic brief.
4. Write the pinned patch to a temp file (must be non-empty). Dispatch
   **Logic hunter** with `workflow/templates/review-logic-hunter.md` in a fresh
   context. First line: `Axis: Logic`. Do not hunt Logic in the parent.
   Every runner delivers the hunter template's full text in the brief (Pi:
   `--append-system-prompt`; Claude and Cursor: the `Axis:` line, then the
   template text, then the Intent and `Standards:` lines and the patch file
   path). A brief that only names the template path is not a dispatch: the
   Claude reviewer does not open it. Record `template: inline` once every
   hunter brief carried its template, else `template: missing`.
   - Claude: `Agent` → existing `reviewer` agent. `runner: claude-agent`.
   - Cursor: Task with model `claude-opus-5-thinking-high`. Do not spawn
     `pi -p` from Cursor. `runner: cursor-task`.
   - Pi: isolated child with this argv: `pi --mode text -p --no-session
     --no-skills --no-extensions --no-context-files --tools read,grep
     --append-system-prompt <hunter-template> @<patchfile>`. The prompt file is
     the hunter template plus `Axis: Logic`, Intent, and `Standards: yes|none`.
     Pass `--model` only when its id is not `cursor/`. Bound the run with a
     timeout (default 600 s). Spawn failure or nonzero exit →
     `HUNTER_SPAWN_UNAVAILABLE`; timeout → `HUNTER_TIMEOUT`. Either
     sentinel stops the lead verdict. Record `hunter_model:` (or
     `hunter_model: default` when `--model` is omitted). `runner: pi-child`.
   Hunter templates are self-contained; the parent reads the rubric for
   filtering. Open deciding APIs when needed. Unresolved inspection errors
   forbid GO. Helper executions capture native JSON. An empty patch is not a
   clean hunt.
   Dispatch **Spec hunter** (`workflow/templates/review-spec-hunter.md`,
   `Axis: Spec`) in parallel when the runtime can (Claude/Cursor), using the
   same runner and model as the Logic hunter; otherwise sequential. Daily Pi:
   Logic is the only child; after it returns, run Spec in the parent and
   record `spec: parent`. Accepted risk: that Spec pass shares the
   implementer's context (self-preference);
   Logic and the adversary stay independent.
5. If neither `PLAN.md` nor PR/user intent exists, record `spec: n/a` and skip
   the Spec spawn.
5b. **Threat trigger**: the diff adds or changes an access decision
   (authentication, authorization, permission, block, tenant or IP filter), a
   trust boundary (request headers, tokens, proxy chain), or a public API's
   accepted inputs or responses. Fired → dispatch **Threat hunter**
   (`workflow/templates/review-threat-hunter.md`, `Axis: Threat`) in a fresh
   context with the same runner and model as Logic (Pi: a second child with
   the same argv, after Logic), giving it the pinned patch, Intent and the
   repository tree; record `threat: isolated`. Not fired → `threat: n/a`.
   With no Intent, Threat derives the asset from the patch and takes its
   Deferrals claims from code comments only.
   Attack tests: inside an implementation loop, the parent writes each attack
   test the report lists into the project's own test suite, runs it, and
   records expected versus observed. Each Threat finding becomes `proven`
   (the named assertion ran and failed with the wrong result), `refuted` (it
   ran and passed through the real decision code, the protection under test
   unmocked, next to a control request that the same code accepts) or
   `unproven` (anything else: no run, import, setup or skip failure, a mocked
   protection, no control). Dispositions: `workflow/templates/review-lead.md`.
   Green attack tests ship as regression tests and are part of the shippable
   patch the final review covers; adding them after a review is a
   delta under the normal budget (`workflow/skills/review-rounds.md`). A pure
   review request writes nothing: every Threat finding stays `unproven`.
6. If `Standards: yes`, run `code-quality` when exposed, otherwise the narrowest
   exposed domain or project skill. If none is exposed, compare the diff directly
   with 1–3 local sibling implementations. If neither a skill nor a relevant
   sibling exists, report the convention lens as `not run`; never present it as
   clean (see rubric § Convention & pattern fit). If `Standards: none`, record
   `quality: none` in the lead report.
7. Lead-filter with `workflow/templates/review-lead.md`. Do not re-hunt.

## Target Resolution

1. Inspect `git status --short` and `git diff --stat` first.
2. Determine the target:
   - no args: review the cumulative workspace patch: committed branch diff,
     staged and unstaged changes, plus relevant untracked implementation files;
     a clean workspace falls back to the current branch against the default branch;
   - `uncommitted`: review staged, unstaged, and relevant untracked changes;
   - `branch <base>`: diff current branch against merge-base with `<base>`;
   - `commit <sha>`: review `git show <sha>`.
3. Read the shared rubric from `workflow/review-rubric.md`, or the harness
   fallback rubric only outside a workflow-scaffolded project.

## Review Scope

Review only the target scope; the Threat hunter reads the system around it. Cover:

- self-check;
- Logic-hunter correctness (lenses + deciding-code);
- Spec-hunter plan/intent fit;
- Threat-hunter attacker inputs, entry points, reused guards, deferrals and
  rollout, when the trigger fires;
- regressions, safety, validation;
- convention and pattern fit (Standards hunter, or Logic when `Standards: none`);
- plan drift;
- human checkpoint trigger when needed.

Do not edit files, install dependencies, or run broad/slow validation unless the
user explicitly asked for that level of review.

## Finding Format

Findings (fields, severity order, `No findings.`), the **lens table** and
**deciding-code table** (mandatory on the Logic hunter) and the final
`Verdict: GO | GO WITH NOTES | BLOCK` line follow `workflow/review-rubric.md`.
Keep findings axis-tagged. Lead output uses Act on / Consider / Dismissed.

`GO` is forbidden when any non-trivial runtime deciding-code row is empty or
`not run`, when any other lens row is `not run` (Convention §5's no-skill,
no-sibling gap excepted), when the whole-diff `n/a` lists a changed path that
is not a document or pure rename, or when `isolation: none`. `GO WITH NOTES`
is not a workaround for those gates. A triggered Threat axis without its
complete report (a table missing or `partial:`) blocks `GO` and `GO WITH NOTES`
the same way, as do `template: missing` and a hunter report whose last line
is not `STATUS: complete`.

## Rules

- No style nitpicks unless they affect correctness or maintenance.
- Convention findings need a sibling pattern `file:line` or a named skill rule.
- Prefer minimal fixes.
- If a human should arbitrate risk, replan, or broad-impact tradeoffs, say so
  explicitly.
- If the request is to prove completion rather than review a diff, route to the
  verification workflow instead of treating it as code review.
