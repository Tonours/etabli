# Linear Work Contract

Shared contract for implementing work from existing Linear tickets.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the Linear MCP source-of-truth rule, `PLAN.md` READY gate, external write
confirmation rule, or one-ticket-one-slice boundary.

## Purpose

Use Linear MCP as the source of truth for Linear issues. Use the shared Etabli
workflow for execution.

## Sources

Read, when available:

1. the Linear issue through MCP, including description, comments, labels,
   status, project, parent/sub-issues, links, and attachments;
2. `workflow/spec.md`;
3. `workflow/ticket-template.md`;
4. `PLAN_TEMPLATE.md` or `PLAN_TEMPLATE_FULL.md`;
5. relevant repo files.

If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`. Do not
work from memory when the user asked to use Linear. To enable Linear MCP
(OAuth, no secrets in repo), follow `docs/mcp-strategy.md` § Linear MCP gap.

## Contract

1. Resolve the Linear issue from URL, key, title, branch name, or user context.
2. Classify the work:
   - bug fix: require observed behavior, expected behavior, reproduction path,
     and a regression check when feasible;
   - feature: require acceptance criteria, scope, non-goals, and validation;
   - unclear: create or update `PLAN.md` as `CHALLENGED` and ask the narrow
     blocking question.
3. Create or refresh root `PLAN.md` with:
   - Linear key and URL under observed facts;
   - route: `linear-work`;
   - role: implementer with planner/challenger as needed;
   - stop condition: validation complete and Linear handoff ready;
   - required evidence: focused checks plus ticket acceptance criteria.
4. Never implement from a `DRAFT` or `CHALLENGED` plan.
5. Implement the smallest slice that satisfies the Linear ticket.
6. Run focused validation from the plan and ticket.
7. Prepare a Linear update comment with files changed, validation, risks, and
   remaining work.
8. Use Linear MCP to post comments, change status, or assign labels only when
   the user's prompt explicitly asks for that external update, or after asking
   for confirmation.

## Output

```md
Linear: <KEY> - <title>
Status: IMPLEMENTED | BLOCKED | PLAN_READY | PLAN_CHALLENGED

Changed:
- ...

Validation:
- command:
  - result:

Linear update:
...

Remaining risks:
- None / ...
```

## Rules

- Preserve unrelated worktree changes.
- Do not close or mark Done in Linear until validation passed.
- Do not broaden a Linear ticket into adjacent cleanup or product work.
- Link PRs only when a PR exists and the user asked for the external update.
