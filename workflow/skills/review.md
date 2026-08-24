# Review Contract

Shared contract for reviewing local changes, branch diffs, or commits.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the read-only default, finding format, plan-compliance check, verdict
labels, deciding-code gate, or hunt/filter split.

## Purpose

Review changes for correctness, regressions, risks, validation gaps, convention
or pattern drift, and plan drift. Use `workflow/review-rubric.md` as the source
of truth when available.

## Hunt and filter

Parent pins the patch and Intent, then dispatches hunters. Lead filters.
Same-session Logic self-review is forbidden.

1. Resolve the target (below), then **pin the patch once** (capture `git diff` /
   `git show` bytes). Hunters receive that text and do not re-run `git diff`.
2. Write one-paragraph Intent (user message, PR body, or commits).
3. Detect language/UI surface. Set `Standards: yes` or `Standards: none` on the
   Logic brief.
4. Write the pinned patch to a temp file (must be non-empty). Dispatch
   **Logic hunter** with `workflow/templates/review-logic-hunter.md` in a fresh
   context. First line: `Axis: Logic`. Do not hunt Logic in the parent.
   - Claude: `Agent` → existing `reviewer` agent. `runner: claude-agent`.
   - Cursor: Task with model `claude-opus-5-thinking-high`. Do not spawn
     `pi -p` from Cursor. `runner: cursor-task`.
   - Pi: isolated child (`scripts/pi-review-hunter` when present, else this
     argv): `pi --mode text -p --no-session --no-skills --no-extensions
     --no-context-files --tools read,grep --append-system-prompt
     <hunter-template> @<patchfile>`. The prompt file is the hunter template
     plus `Axis: Logic`, Intent, and `Standards: yes|none`. Pass `--model` only when it is not a
     `cursor/` id. Timeout default 600s (`PI_REVIEW_HUNTER_TIMEOUT`). Spawn or
     nonzero → `HUNTER_SPAWN_UNAVAILABLE`. Timeout → `HUNTER_TIMEOUT`.
     Either sentinel is a hard stop: report it and stop; do not continue to a
     lead verdict. An empty patch is not a clean hunt. Record `hunter_model:`
     (or `hunter_model: default` when `--model` is omitted). `runner: pi-child`.
   Dispatch **Spec hunter** (`workflow/templates/review-spec-hunter.md`,
   `Axis: Spec`) in parallel when the runtime can (Claude/Cursor), using the
   same runner and model as the Logic hunter; otherwise sequential. Daily Pi:
   Logic is the only child; after it returns, run Spec in the parent and
   record `spec: parent`.
5. If neither `PLAN.md` nor PR/user intent exists, record `spec: n/a` and skip
   the Spec spawn.
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
   - no args: review uncommitted changes if present, else review current branch
     against the default branch;
   - `uncommitted`: review staged, unstaged, and relevant untracked changes;
   - `branch <base>`: diff current branch against merge-base with `<base>`;
   - `commit <sha>`: review `git show <sha>`.
3. Read the shared rubric from `workflow/review-rubric.md`, or the harness
   fallback rubric only outside a workflow-scaffolded project.

## Review Scope

Review only the target scope. Cover:

- self-check;
- Logic-hunter correctness (lenses + deciding-code);
- Spec-hunter plan/intent fit;
- regressions, safety, validation;
- convention and pattern fit (Standards hunter, or Logic when `Standards: none`);
- plan drift;
- human checkpoint trigger when needed.

Use bounded read-only inspection of nearby code, tests, config, or docs only
when it materially confirms or rejects a suspected finding.

Do not edit files, install dependencies, or run broad/slow validation unless the
user explicitly asked for that level of review.

## Finding Format

Report concise actionable findings grounded in the reviewed diff:

```text
severity:
file:
line: or line_range:
issue:
impact:
review_comment:
suggested_fix:
```

Then the **lens table** and **deciding-code table** from the rubric (mandatory
on the Logic hunter). Keep findings axis-tagged. Lead output uses Act on /
Consider / Dismissed.

If there are no actionable issues, put exactly `No findings.` as the only
finding and do not wrap it in severity/file fields.

End with one final line in this exact shape:

```text
Verdict: GO | GO WITH NOTES | BLOCK
```

`GO` is forbidden when any non-trivial runtime deciding-code row is empty or
`not run`, when any other lens row is `not run` (Convention §5's no-skill,
no-sibling gap excepted), when the whole-diff `n/a` lists a changed path that
is not a document or pure rename, or when `isolation: none`. `GO WITH NOTES`
is not a workaround for those gates.

## Rules

- No style nitpicks unless they affect correctness or maintenance.
- Convention findings need a sibling pattern `file:line` or a named skill rule.
- Prefer minimal fixes.
- If a human should arbitrate risk, replan, or broad-impact tradeoffs, say so
  explicitly.
- If the request is to prove completion rather than review a diff, route to the
  verification workflow instead of treating it as code review.
- Never use `OK`, `APPROVED`, `PASS`, or other verdict words.
