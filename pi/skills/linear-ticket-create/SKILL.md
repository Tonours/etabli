---
name: linear-ticket-create
description: Create Linear tickets from rough context, bug reports, feature ideas, roadmap notes, or user requests. Use when the user asks to create, draft, split, write, or open Linear tickets/issues.
---

# Linear Ticket Create

Use Linear MCP as the Linear integration. Do not use GitHub issues, web
scraping, shell-based Linear API calls, or a custom wrapper unless the user
explicitly overrides this.

## Sources

Read, when available:

1. `workflow/ticket-template.md`
2. `workflow/linear-ticket-template.md`
3. relevant repo docs or code named by the user

If the workflow files are missing, still create a ticket with the same section
shape and report the missing sources as a warning.

## Contract

1. Identify the single behavior the ticket should cover. Split multiple
   behaviors into multiple tickets.
2. Use Linear MCP to resolve the team, project, cycle, labels, assignee, and
   parent issue when the user provides partial context.
3. If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`
   unless the user explicitly asked for a draft only.
4. Ask one blocking question only when the target Linear team or project cannot
   be inferred.
5. Fill the ticket from `workflow/ticket-template.md`; keep acceptance criteria
   behavioral with `Given ..., when ..., then ...`.
6. Keep scope narrow enough for one PR.
7. Create the Linear issue through MCP only after team/project ambiguity is
   resolved.
8. Return the created issue key, URL, title, and any assumptions.

## Output

For created tickets:

```md
Created: <KEY> - <title>
URL: <linear-url>

Assumptions:
- None / ...

Next:
- ...
```

For draft-only or blocked runs:

```md
Status: DRAFT | BLOCKED
Reason: ...

Title:
...

Body:
...
```

Rules:

- One ticket equals one behavior equals one PR.
- Do not mark priority, assignee, estimate, or cycle unless provided or clearly
  inferred from Linear MCP context.
- Do not invent product facts. Put uncertain details under assumptions or
  questions.
- Do not create external tickets for destructive, security-sensitive,
  production-impacting, billing, credential, or broad ambiguous work without
  explicit confirmation of scope.
