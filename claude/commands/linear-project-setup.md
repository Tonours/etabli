---
description: Create a Linear Project plus its prioritized Epics from a spec
argument-hint: [spec URL or path + project context]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Linear Project Setup

User request: $ARGUMENTS

Use Linear MCP as the integration. No GitHub issues, no shell API, no custom wrapper.
This command is for the **Project + Epics** level. For one isolated ticket, use `linear-ticket-create`.

Read the `linear-conventions-forest-projects` memory first if present (live IDs + rules).

Forest conventions (Brice, PO):

- Initiative = **Project**. Under it, **Epics** = Issues directly under the Project. Re-split into sub-issues only when needed.
- Project overview = clear, self-contained, **readable by Claude** (business queries Linear through it). High-level for a tech project; depth stays in the Epics and the linked spec.
- Each Epic gets the `Epic` label + `Backlog` status (team `Product`) so it surfaces in the Epic backlog.
- **Prioritization of the Epics is what matters most.** Set priority deliberately and surface the order.
- T-shirt sizing at spec level is fine; don't force story points.

Contract:

1. Locate the spec (Linear Document URL or local file). If none, stop and ask — don't invent the work.
2. Derive Epics from the spec's major units (one per shippable unit, not per task). Carry its sizing/priority signal.
3. Resolve team, `Epic` label, `Backlog` status via MCP; check for an existing Project before creating a duplicate.
4. Draft the Project overview + ordered Epic list and confirm with the user BEFORE creating anything.
5. Create the Project (Claude-readable overview, link to spec), then each Epic (label `Epic`, status `Backlog`, explicit priority, behavioral ACs, spec link).
6. Return the Project URL, each Epic key + URL, the priority order, and assumptions.

Rules:

- Confirm before creating the Project or any Epic.
- Link the spec, don't duplicate it; embed only the 2-3 lines that save a round-trip.
- Epic titles name the thing: verb-first (`Migrate Zendesk onto the BFF`) or noun-phrase (`Workflow versioning`), sentence-case, no `[bracket]` and no `Scope:` prefix (the Project field carries the scope). Open every Epic description with `## Context`.
- Verify IDs through MCP; report drift. If `Epic` label or `Backlog` status is missing on the team, stop and ask.
- No Projects/Epics for destructive, security-sensitive, production, billing, or credential work without explicit scope confirmation.
