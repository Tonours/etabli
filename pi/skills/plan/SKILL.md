---
name: plan
description: Create a structured implementation plan before writing code
---

# Plan

Create a detailed implementation plan.

1. Check current state: `git status --short` and `git log --oneline -3`
2. Analyze the codebase to understand what needs to change
3. Write plan to ./PLAN.md:
   - **Goal**: What we're building and why
   - **Files to modify**: List with rationale
   - **Implementation steps**: Ordered, with verification for each
   - **Verification commands**: Test commands and expected output
   - **Risks**: What could go wrong, rollback strategy
   - **Dependencies**: External deps, blockers
4. Do NOT write code yet
5. Iterate on the plan until the user approves
