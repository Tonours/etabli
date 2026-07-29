# Linear Ticket Create Contract

Shared contract for creating or drafting Linear tickets from rough context,
bug reports, feature ideas, roadmap notes, or user requests.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the Linear MCP source-of-truth rule, one-ticket-one-behavior rule, or
external ticket creation safeguards.

## Purpose

Use Linear MCP as the Linear integration. Do not use GitHub issues, web
scraping, shell-based Linear API calls, or a custom wrapper unless the user
explicitly overrides this.

## Sources

Read, when available:

1. `workflow/ticket-template.md`;
2. `workflow/linear-ticket-template.md`;
3. any `linear-conventions-*` memory for the target org, covering team,
   project, label, title, and hierarchy rules;
4. relevant repo docs or code named by the user.

If the workflow files are missing, still create a ticket with the same section
shape and report the missing sources as a warning.

## Hierarchy And Level

Know where the ticket sits before creating it:

- A whole initiative is a Project, not an Issue. If the user is really asking
  to stand up a project with several Epics, stop and point them at
  `linear-project-setup` instead.
- An Epic is an Issue directly under a Project. When the ticket is an Epic,
  apply the org's Epic convention. For employer `Product`, use the `Epic` label
  and `Backlog` status so it surfaces in the Epic backlog.
- A normal Issue or sub-issue hangs under an Epic via `parentId`. Resolve and
  set the parent when the user names one.

## Implementation-Task Body

For a concrete implementation task, not an Epic, use this trimmed body. It is
the employer cut of the fuller Etabli `workflow/ticket-template.md`: Linear-native
fields replace some sections, and nothing is hard-required.

Core:

```md
## Outcome
One sentence: what becomes true when this is done.

## Context
Likely files, existing patterns, dependencies, constraints.

## Scope
- What this PR includes (one behavior).

## Non-goals
- What stays out of this PR, including tempting side quests.

## Acceptance criteria
- [ ] Given ..., when ..., then ...

## Validation
- [ ] Commands, manual checks, or fixture tests that prove it.

## Stop conditions
Pause and ask before continuing if:
- The work needs a second behavior (split the ticket).
- ...
```

Optional, when an AI agent will execute the task:

- `## User story`
- `## Start here`
- `## Implementation checklist`

Deliberately dropped:

- `Why now`: Linear carries priority, dependencies, and project natively.
- `Definition of done`: folded into Acceptance criteria and Validation.

An Epic stays light: Context-first, Goal, Acceptance criteria, and spec link.
Do not push the full task body onto an Epic.

## Contract

1. Identify the single behavior the ticket should cover. Split multiple
   behaviors into multiple tickets.
2. Use Linear MCP to resolve the team, project, cycle, labels, assignee, and
   parent issue when the user provides partial context.
3. If no Linear MCP tool is available, stop with `LINEAR_MCP_UNAVAILABLE`
   unless the user explicitly asked for a draft only. To enable Linear MCP
   (OAuth, no secrets in repo), follow `docs/mcp-strategy.md` § Linear MCP gap.
4. Ask one blocking question only when the target Linear team or project cannot
   be inferred.
5. Fill the body by level: an Epic stays light; an implementation task uses the
   trimmed body above. Keep acceptance criteria behavioral with
   `Given ..., when ..., then ...`.
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

## Rules

- One ticket equals one behavior equals one PR.
- Do not mark assignee, estimate, or cycle unless provided or clearly inferred
  from Linear MCP context.
- Do not mark priority by default, except for Epics where prioritization is
  expected: set the Epic's priority deliberately and surface the choice.
- Do not invent product facts. Put uncertain details under assumptions or
  questions.
- Do not create external tickets for destructive, security-sensitive,
  production-impacting, billing, credential, or broad ambiguous work without
  explicit confirmation of scope.
