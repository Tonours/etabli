---
name: linear-project-setup
description: Turn a tech spec into a Linear Project plus its prioritized Epics, following Forest's Project→Epic conventions. Use when the user asks to set up a Linear project from a spec, create a project with epics, or stand up the backlog for a new initiative (e.g. "create the Linear project for X", "set up epics for this spec").
---

# Linear Project Setup

Stand up a Linear **Project** and its **Epics** from a spec, the way Forest's PO (Brice) wants the backlog shaped. Use Linear MCP only — no GitHub issues, no shell API, no custom wrapper.

This skill is for the **Project + Epics** level. For a single isolated ticket, use `linear-ticket-create` instead.

## Forest conventions (source of truth)

Read the `linear-conventions-forest-projects` memory first if present; it holds the live IDs and rules. The rules:

- **Hierarchy:** initiative = **Project**. Under it, **Epics** = Issues directly under the Project. Each Epic re-splits into sub-issues only when needed. `Project → Epic → sub-issue`.
- **Project overview:** clear, self-contained, **readable by an LLM** (the business queries Linear through Claude). High-level for a tech project — depth stays in the Epics and the linked spec Document. Do not paste the whole spec.
- **Epic template:** each Epic Issue gets the `Epic` label (parent `Type`) and a `Backlog` status so it surfaces in the Epic backlog. Team `Product`.
- **Prioritization is what matters most to Brice.** Set each Epic's priority deliberately; surface the ordering to the user.
- **Estimations:** t-shirt sizing at the spec level is fine. Don't force story points onto the Epics.

Known IDs (team `Product`, verify with MCP before relying on them — they can change):
- Team `Product`: `af184e47-69e4-4738-8b6f-ad119b46e118`
- Label `Epic`: `e3fc6689-90db-4958-9f6f-43a007497f3e`
- Status `Backlog`: `7f25f361-6fcf-4f12-8c80-d4cb3a975ec4`

## Contract

1. **Locate the spec.** Take the spec Document (Linear URL or local file) the Epics derive from. If none exists, stop and ask — this skill does not invent the work.
2. **Derive the Epic list.** Map the spec's major units (slices, workstreams, phases) to Epics — one Epic per shippable unit, not one per task. Carry the spec's own sizing/priority signal.
3. **Resolve targets via MCP.** Confirm team, `Epic` label, and `Backlog` status by listing them — do not trust hardcoded IDs blindly. Check whether the Project already exists (`list_projects`) before creating a duplicate.
4. **Draft, then confirm.** Show the user the proposed Project overview + the ordered Epic list (title, priority, size) BEFORE creating anything. Anthony wants explicit go-ahead each time.
5. **Create the Project** (`save_project`) with the Claude-readable overview and a link to the spec Document.
6. **Create each Epic** (`save_issue`) under the Project: `Epic` label, `Backlog` status, explicit priority, behavioral description. Link the spec section.
7. **Return** the Project URL, each Epic key + URL, the priority order, and any assumptions.

## Project overview shape

Write it for a non-technical reader skimming through Claude. Keep it tight:

- **What & why** — one or two sentences: what this delivers and the problem it removes.
- **Scope** — the surfaces/repos touched, in plain words.
- **First value** — what ships first and when the user-visible win lands.
- **Spec** — link to the full Document. "Detail lives in the spec and the Epics."

No payloads, no file:line, no API contracts in the Project overview — that's Epic/spec territory.

## Epic shape

One Epic per shippable unit. Each carries:

- **Title** — name the thing, not the work plan. Forest house style (verified across ~30 existing Epics) is short (≈5 words), sentence-case, **no emoji, no `[bracket]` prefix, no `Scope:` colon prefix, no trailing period**. Two accepted shapes: verb-first imperative (`Enable multi-selection in Workspaces`, `Migrate Zendesk onto the BFF`) or noun-phrase feature label (`Workflow versioning`, `Inbox assignment rules`). The **Project field already carries the scope** — do not repeat the project name as a title prefix. Keep one scope token inside the phrase only if it genuinely aids scanning a flat list.
- **Label** `Epic`, status `Backlog`, **priority** set deliberately.
- **Description** — open with a short `## Context` (1–3 lines: current state and why this Epic exists), the way every house Epic opens Context-first. Then the goal, key decisions, behavioral acceptance criteria (`Given…, when…, then…`), and a link to the matching spec section. The PO weights the description heavily — Context-first is not optional. Re-split into sub-issues only when the Epic is too big for one PR.

## Rules

- Confirm with the user before creating the Project or any Epic.
- Epic titles name the thing (verb-first or noun-phrase, sentence-case), never `Scope:`-prefixed — the Project field carries the scope. Every Epic description opens with `## Context`.
- Do not duplicate the spec into Linear — link it, embed only the 2-3 lines that save a round-trip.
- Do not create work for destructive, security-sensitive, production, billing, or credential changes without explicit scope confirmation.
- Verify IDs through MCP; report any that drifted from the memory.
- If the `Epic` label or `Backlog` status is missing on the target team, stop and ask rather than substituting.

## Output

```md
Project created: <name>
URL: <project-url>
Overview: <one-line recap>

Epics (priority order):
1. <KEY> <title> — <priority> · <size> · <url>
2. ...

Assumptions:
- None / ...

Next:
- ...
```
