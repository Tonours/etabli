---
name: code-quality
description: Run the bounded convention and stack-quality pass after implementation or during review.
---

# Code Quality

Thin orchestrator for **convention + pattern fit** on a bounded change.  
It does not invent style rules. It loads the skill that already owns the practice
and compares the diff to **sibling implementations in this repo**.

## When to run

- After the simplification pass in `implementation-loop`
- During `review` / `pr-review` when the diff touches language or UI surface
- Explicit user request for quality, conventions, patterns, or best practices
- React convention pass on a bounded diff

## Procedure

1. **Bound the target** — current uncommitted diff, named paths, or PR diff. Never whole-repo audit unless asked.
2. **Detect domain** — match signals from the diff directly. This skill does
   not depend on another router or suite.
3. **Load practice skills** for the matched domain only:

   | Domain | Skills to apply |
   | -------- | ----------------- |
   | React / Next / TanStack UI | `vercel-react-best-practices`, `vercel-composition-patterns` |
   | Node / Fastify / API | `node`, `fastify-best-practices`, `typescript-magician` |
   | Lint / ESLint flat | `linting-neostandard-eslint9` |
   | CSS / layout / visual | Local sibling components and styles; apply a narrower CSS skill only when the runtime exposes one |
   | Project-specific code | Prefer the matching project skill when the runtime exposes one |

4. **Compare to local convention** — open 1–3 sibling files that already
   implement the same kind of change. The pattern to match is what the repo
   does, not a generic blog post. If a named practice skill is unavailable,
   continue with these siblings. If no relevant sibling exists either, report
   `quality: unavailable` and stop; do not call the pass clean.
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
quality: <domains> | mechanical fixed: N | findings: N | status: clean|findings|unavailable
```

## Rules

- Prefer the narrowest exposed skill.
- No style nits that the project's linter or formatter already owns unless the tool is broken on this diff.
- Do not widen scope to unrelated files.
- Quality pass does not replace correctness review or tests.
- If the diff has no language/UI convention surface, say `quality: none` and stop.

## Related

- `workflow/review-rubric.md` § Convention & pattern fit
- `workflow/skills/implementation-loop.md` quality pass
