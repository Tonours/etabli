# Linear Ticket Template

Use this as the Linear-specific wrapper around `workflow/ticket-template.md`.
One Linear issue should still represent one behavior and one PR.

## Linear Fields

- Team:
- Project:
- Cycle:
- Parent issue:
- Labels:
- Assignee:
- Priority:
- Estimate:

Only fill fields that were provided by the user or resolved through Linear MCP.

## Title

`<verb> <single behavior>`

## Description

Use the body from `workflow/ticket-template.md`.

## Creation Rules

- Resolve team/project/labels through Linear MCP before creating the issue.
- Ask one blocking question if the target team cannot be inferred.
- Do not invent priority, estimate, cycle, or assignee.
- Put uncertainty in assumptions or open questions.
- Split multi-behavior requests before creating issues.
- For bugs, include reproduction, expected behavior, actual behavior, and the
  regression check.
- For features, include user-visible outcome, non-goals, acceptance criteria,
  and validation.
