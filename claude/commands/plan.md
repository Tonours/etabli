Enter plan mode. Create detailed implementation plan for: $ARGUMENTS

Current state:

```bash
git status --short
git log --oneline -3
```

Include in plan:

- **Goal**: What we're building and why
- **Files to modify**: List with rationale
- **Implementation steps**: Ordered, with verification for each
- **Verification commands**: Test commands and expected output
- **Risks**: What could go wrong, rollback strategy
- **Dependencies**: External deps, blockers

Write plan to ./PLAN.md
Do NOT write code yet. Iterate on plan until approved.
