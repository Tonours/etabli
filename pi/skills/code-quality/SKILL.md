---
name: code-quality
description: Enforce project conventions, patterns, and stack best practices on a bounded diff. Routes to stack-suite, design-suite, linting, react-doctor, and frontend-css skills. Use during implement quality pass, review, front-quality, or when asked to check conventions/patterns/best practices.
---

# Code Quality

Thin orchestrator for **convention + pattern fit** on a bounded change.  
It does not invent style rules. It loads the skill that already owns the practice
and compares the diff to **sibling implementations in this repo**.

## When to run

- After the simplification pass in `implementation-loop`
- During `review` / `pr-review` when the diff touches language or UI surface
- Explicit user request for quality, conventions, patterns, or best practices
- Claude `/front-quality` (React subset of this skill)

## Procedure

1. **Bound the target** — current uncommitted diff, named paths, or PR diff. Never whole-repo audit unless asked.
2. **Detect domain** — invoke `suite-router` (or match signals yourself if already loaded). Activate `design-suite` and/or `stack-suite` as appropriate.
3. **Load practice skills** for the matched domain only:

   | Domain | Skills to apply |
   |--------|-----------------|
   | React / Next / TanStack UI | `stack-suite` React rows → `react-best-practices`, `composition-patterns`; optional `react-doctor-100` |
   | Node / Fastify / API | `stack-suite` Node rows → `node`, `fastify`, `typescript-magician` |
   | Lint / ESLint flat | `linting-neostandard-eslint9` |
   | CSS / layout / visual | `frontend-css-ui-ux` (+ primitives / debugging as needed) |
   | Project suites | Prefer `ember-employer-suite`, `employer-backend-suite`, `adonisjs-suite`, `tanstack-start-suite` when the codebase is theirs |

4. **Compare to local convention** — open 1–3 sibling files that already implement the same kind of change. The pattern to match is what the repo does, not a generic blog post.
5. **Classify findings**:
   - **Mechanical** — clear, local, no behavior change (import order already enforced by lint, missing `type` import, dead branch introduced by this diff, obvious composition smell with a sibling pattern). Fix directly when running inside implement.
   - **Behavioral** — would change runtime behavior or API. Report only; do not fix in a pure review.
6. **Evidence bar** — a finding ships only with:
   - changed `file:line` in the target diff
   - the **sibling pattern** `file:line` being violated (or the skill rule name when no sibling exists)
   - concrete impact (correctness, operability, or consistency that blocks maintenance)

   Abstract “best practice” opinions without a local anchor are discarded.

7. **Report** one line per pass run:

```text
quality: <domains> | mechanical fixed: N | findings: N | clean
```

## Rules

- Prefer the narrowest skill. Do not load every stack-suite row.
- No style nits that the project's linter or formatter already owns unless the tool is broken on this diff.
- Do not widen scope to unrelated files.
- Quality pass does not replace correctness review or tests.
- If no domain skill applies, say `quality: none` and stop.

## Related

- `suite-router`, `stack-suite`, `design-suite`
- `workflow/review-rubric.md` § Convention & pattern fit
- `workflow/skills/implementation-loop.md` quality pass
- Claude `/front-quality` (React-focused entry point)
