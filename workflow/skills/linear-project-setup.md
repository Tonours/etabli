# Linear Project Setup Contract

Shared contract for turning a spec into a Linear Project plus prioritized
Epics.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the draft-before-create rule, Linear MCP source-of-truth rule, or
Project/Epic hierarchy.

## Purpose

Stand up a Linear Project and its Epics from a spec, following employer's
Project-to-Epic conventions. Use Linear MCP only: no GitHub issues, shell API,
or custom wrapper.

This contract is for the Project plus Epics level. For a single isolated ticket,
use `linear-ticket-create` instead.

## employer Conventions

Read the `linear-conventions-employer-projects` memory first if present. It holds
live IDs and rules. The rules:

- Hierarchy: initiative equals Project. Under it, Epics are Issues directly
  under the Project. Each Epic re-splits into sub-issues only when needed.
- Project overview: clear, self-contained, readable by an LLM. High-level for a
  tech project; depth stays in the Epics and the linked spec Document.
- Epic template: each Epic Issue gets the `Epic` label and `Backlog` status for
  team `Product`, so it surfaces in the Epic backlog.
- Prioritization matters most. Set each Epic's priority deliberately and surface
  the ordering to the user.
- T-shirt sizing at the spec level is fine. Do not force story points onto
  Epics.

Known IDs can change and must be verified with MCP before relying on them:

- Team `Product`: `af184e47-69e4-4738-8b6f-ad119b46e118`
- Label `Epic`: `e3fc6689-90db-4958-9f6f-43a007497f3e`
- Status `Backlog`: `7f25f361-6fcf-4f12-8c80-d4cb3a975ec4`

## Contract

1. Locate the spec. Take the spec Document, Linear URL, or local file the Epics
   derive from. If none exists, stop and ask; this contract does not invent the
   work.
2. Derive the Epic list. Map the spec's major units to Epics: one Epic per
   shippable unit, not one per task. Carry the spec's own sizing/priority
   signal.
3. Resolve targets via MCP. Confirm team, `Epic` label, and `Backlog` status by
   listing them. Do not trust hardcoded IDs blindly. Check whether the Project
   already exists before creating a duplicate.
4. Draft, then confirm. Show the user the proposed Project overview and ordered
   Epic list before creating anything.
5. Create the Project with the LLM-readable overview and a link to the spec
   Document.
6. Create each Epic under the Project: `Epic` label, `Backlog` status, explicit
   priority, behavioral description, and spec section link.
7. Return the Project URL, each Epic key and URL, the priority order, and any
   assumptions.

## Project Overview Shape

Write it for a non-technical reader skimming through an assistant:

- What and why: one or two sentences.
- Scope: the surfaces/repos touched, in plain words.
- First value: what ships first and when the user-visible win lands.
- Spec: link to the full Document. Detail lives in the spec and the Epics.

No payloads, file:line references, or API contracts in the Project overview.

## Epic Shape

One Epic per shippable unit. Each carries:

- Title: name the thing, not the work plan. Use short sentence-case titles, no
  emoji, no bracket prefix, no `Scope:` prefix, and no trailing period.
  Accepted shapes are verb-first imperative or noun-phrase feature label.
- Label `Epic`, status `Backlog`, and deliberately set priority.
- Description: open with a short `## Context`, then goal, key decisions,
  behavioral acceptance criteria, and a matching spec section link.

## Rules

- Confirm with the user before creating the Project or any Epic.
- Link the spec; do not duplicate it. Embed only the 2-3 lines that save a
  round trip.
- Do not create work for destructive, security-sensitive, production, billing,
  or credential changes without explicit scope confirmation.
- Verify IDs through MCP and report any drift.
- If the `Epic` label or `Backlog` status is missing on the target team, stop
  and ask rather than substituting.

## Output

```md
Project created: <name>
URL: <project-url>
Overview: <one-line recap>

Epics (priority order):
1. <KEY> <title> - <priority> - <size> - <url>
2. ...

Assumptions:
- None / ...

Next:
- ...
```
