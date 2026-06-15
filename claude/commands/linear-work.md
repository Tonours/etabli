---
description: Work from an existing Linear ticket through Linear MCP
argument-hint: [Linear issue URL/key or task]
allowed-tools: [Read, Glob, Grep, Bash, Edit, MultiEdit, Write, AskUserQuestion]
---

# Linear Work

User request: $ARGUMENTS

Use Linear MCP as the source of truth for Linear issues. Use the shared Etabli
workflow for execution.

Read, when available:

1. the Linear issue through MCP, including description, comments, labels,
   status, project, parent/sub-issues, links, and attachments
2. `workflow/spec.md`
3. `workflow/ticket-template.md`
4. `PLAN_TEMPLATE.md` or `PLAN_TEMPLATE_FULL.md`
5. relevant repo files

If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`. Do not
work from memory when the user asked to use Linear.

Contract:

1. Resolve the Linear issue from URL, key, title, branch name, or user context.
2. Classify the work as bug fix, feature, or unclear.
3. Create or refresh root `PLAN.md` with Linear key and URL, route
   `linear-work`, stop condition, required evidence, acceptance criteria,
   focused checks, risks, and open questions.
4. Never implement from a `DRAFT` or `CHALLENGED` plan.
5. Implement the smallest slice that satisfies the Linear ticket once
   `PLAN.md` is `READY`.
6. Run focused validation from the plan and ticket.
7. Prepare a Linear update comment with files changed, validation, risks, and
   remaining work.
8. Use Linear MCP to post comments, change status, or assign labels only when
   the user's prompt explicitly asks for that external update, or after asking
   for confirmation.

Rules:

- Preserve unrelated worktree changes.
- Do not close or mark Done in Linear until validation passed.
- Do not broaden a Linear ticket into adjacent cleanup or product work.
