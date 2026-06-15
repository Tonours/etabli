---
description: Create Linear tickets through Linear MCP
argument-hint: [ticket context]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Linear Ticket Create

User request: $ARGUMENTS

Use Linear MCP as the Linear integration. Do not use GitHub issues, web
scraping, shell-based Linear API calls, or a custom wrapper unless the user
explicitly overrides this.

Read `workflow/ticket-template.md` and `workflow/linear-ticket-template.md`
when available.

Contract:

1. Identify one behavior per ticket. Split multiple behaviors into multiple
   tickets.
2. Resolve team, project, cycle, labels, assignee, and parent issue through
   Linear MCP when partial context is provided.
3. If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`
   unless the user explicitly asked for a draft only.
4. Ask one blocking question only when the target Linear team or project cannot
   be inferred.
5. Create the Linear issue through MCP once ambiguity is resolved.
6. Return the created issue key, URL, title, and assumptions.

Rules:

- One ticket equals one behavior equals one PR.
- Keep acceptance criteria behavioral with `Given ..., when ..., then ...`.
- Do not invent product facts.
- Do not create external tickets for destructive, security-sensitive,
  production-impacting, billing, credential, or broad ambiguous work without
  explicit confirmation of scope.
