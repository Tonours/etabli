# Ticket Template - Solo MVP Slice

Use this template for every development ticket. One ticket = one behavior = one PR.

The goal is not to create more process. The goal is to make the next action obvious after a context switch, avoid scope drift, and leave enough validation detail for a solo developer or coding agent to finish the slice without rereading the whole repository.

## Title

`<verb> <single behavior>`

Examples:

- `Bootstrap the TUI shell and prove the app boots`
- `Validate mpv dependency read-only`
- `Render unauthenticated YouTube Music search results`

## Body

```md
<!-- Source of truth: workflow/ticket-template.md when present in the repo, otherwise ~/.codex/workflow/ticket-template.md. If a GitHub issue template is added later, it must stay synchronized with this file. -->

## Outcome

One sentence describing what becomes true when this ticket is done.

## Why now

- Milestone:
- Priority:
- Depends on:
- Unblocks:

## User story

As <role>, I want <action> so that <benefit>.

(Optional or merged into Outcome / Why now if a GitHub form provides the field.)

## Start here

- [ ] First concrete action that can be done in 5-10 minutes.

## Context

- Repo/workspace:
- Relevant docs:
- Likely files:
- Existing state:

## Scope

- [ ] One implementation slice.
- [ ] One behavior or contract change.
- [ ] One focused docs/update slice if needed.

## Non-goals / parking lot

- Do not build:
- Defer to later issue:

## Contract

Inputs, outputs, states, routes, persistence shape, or user-visible behavior that must stay true.

## Edge cases

-

## Acceptance criteria

- [ ] Given ..., when ..., then ...
- [ ] Given ..., when ..., then ...
- [ ] Given ..., when ..., then ...

## Implementation checklist

- [ ] Inspect current state and note any mismatch with this ticket.
- [ ] Add/update the smallest viable implementation.
- [ ] Add/update focused tests when behavior is testable.
- [ ] Update docs/API client only if this slice changes them.
- [ ] Check for out-of-scope changes before opening the PR.

## Validation

- [ ] Command/manual check:
- [ ] Test:
- [ ] Security/privacy check if relevant:

## Stop conditions

Pause and ask before continuing if:

- The implementation requires a second behavior.
- The ticket conflicts with the project's source of truth.
- The change would add destructive, security-sensitive, production-impacting, or broad out-of-scope behavior.

## Definition of done

- [ ] Acceptance criteria verified.
- [ ] Validation notes added to the PR.
- [ ] One coherent PR, with unrelated changes left untouched.
```

## Template rules

- Keep `Start here` concrete and small. It is an activation step, not a full plan.
- Keep acceptance criteria behavioral. Prefer `Given/When/Then`.
- Use `Non-goals / parking lot` to protect attention from attractive side quests.
- Put risky or ambiguous work in `Stop conditions` instead of hiding it in prose.
- Do not add a ticket unless it advances one clear behavior toward the active milestone.
- Maintenance rule: any future `.github/ISSUE_TEMPLATE/implementation_task.yml` must keep its markdown body synchronized with the ticket template used by the repo. A PR that changes one without the other is invalid once both files exist.
