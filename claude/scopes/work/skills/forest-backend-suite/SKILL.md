---
name: forest-backend-suite
description: Route Forest server, agent-nodejs, BFF, MCP, OAuth/JWT, permissions v4, workflow execution and Zendesk work to existing KB knowledge.
version: 0.1.0
author: Anthony Guimard
license: Proprietary
---

# Forest backend suite

Router for backend and integration work on the Forest stack. Frontend Ember work
routes through `ember-forestadmin-suite` instead.

**Read the note before opening the repos.** Every entry below is a sourced
finding that already cost an investigation. Re-deriving it across repos is waste.
Notes live in `~/work/brain/kb/<name>.md`; the index is
`~/work/brain/kb/_index.md`.

Repo paths, URLs, secret pointers, and the Node version are in
`~/work/brain/ref/forest-constants.md`. Read it instead of asking.

## Route by subject

Start at `forest-bff-gateway` for anything BFF-shaped: it is the entry note for
the initiative and carries the Mode 1 / Mode 2 arbitration the table below
assumes.

| Task touches | Read first | Then |
|---|---|---|
| Permissions, RBAC, role scoping | `forest-permissions-v4`, `private-api-permissions-route` | `forest-custom-action-authorization` for record-dependent actions |
| BFF, anything | `forest-bff-gateway` | the specific row below |
| Agent auth, JWT, token minting | `forest-auth-jwt`, `bff-agent-token-no-type-claim` | `forest-oauth-provider-mcp` on the OAuth path |
| BFF API keys | `bff-api-key-store`, `bff-api-key-admin-authz`, `bff-api-key-resolve-identity` | — |
| BFF OAuth / token lifecycle | `bff-oauth-code-replay-guard`, `bff-refresh-token-rotation` | — |
| BFF data/action endpoints, contract shape | `agent-bff-data-endpoints`, `agent-bff-read-model` | `agent-bff-runtime-stub` for what is still stubbed |
| BFF relations, leaf vs branch, filters | `bff-relation-read-model-refresh`, `bff-leaf-branch-parsing-divergence`, `bff-filter-validation-hardening` | — |
| Premium/plan gating | `bff-feature-gate-pattern` | `plan-feature-premium-enums` when a plan enum moves |
| MCP transport, tool allowlist | `mcp-gateway`, `mcp-oauth-client-allowlist` | `ai-proxy-mcp-loadtools-hang` on timeouts/504 |
| MCP search, filters, operators | `mcp-search-filters`, `forest-capabilities-operators` | — |
| MCP actions | `mcp-get-action-form`, `action-slug-collision` | — |
| Agent error shapes, client errors | `agent-client-error-shape` | `agent-list-relation-authz-gap` on relation reads |
| Zendesk app, auth, refresh | `zendesk-integration`, `zendesk-refresh-logout-gating` | `zendesk-qa-environment` (in `ref/`) before any QA |
| Zendesk user matching | `zendesk-context-field-mapping`, `zendesk-external-id-role`, `zendesk-requester-id-matching` | — |
| Zendesk operator lessons, search modes | `zendesk-operator-lesson-cache` | `mcp-search-filters` |
| Zendesk observability, versioning | `zendesk-monitoring-datadog`, `zendesk-app-version-header` | — |
| Workflow executor / orchestrator | `workflow-executor`, `workflow-orchestrator-service` | `workflow-history-navigator` for sub-workflow stacks |
| Workflow front, team duplication | `workflow-visualizer-front`, `team-duplication-workflow-exclusion` | — |
| Migrations, enums, fixtures | `migration-enum-replay`, `test-loadfixtures-drop` | — |
| Server env vars, private-api deps | `forest-service-env-vars`, `private-api-joi-15` | — |
| Why the permissions evaluator fork keeps upstream bugs | `bff-fork-fidelity-over-robustness` | — |

## Before concluding

1. **Check the note's `status`.** `verified` is trustworthy; `stale` means the
   note records the state *before* a fix and the current code wins.
2. **Re-verify `file:line` on the current HEAD.** Notes are dated; code moves.
   The note tells you where to look and what the mechanism is, not what today's
   line number is.
3. **A note is evidence, not authority.** When it contradicts the code you just
   read, the code wins — and the note needs updating.
4. `~/work/brain/ref/current-work.md` holds the active initiatives and the
   explicit next action. Read it when the task is open-ended.

## Non-negotiables

- Do not re-investigate a mechanic that has a note until you have read the note.
- Do not copy note content into code comments or plans; cite the note name.
- Do not write into the vault from here. Writing goes through
  `~/work/brain/CLAUDE.md` (strict frontmatter, `sources:` with `file:line`,
  `_meta/validate-kb.sh` must exit 0).
- Do not treat a `stale` note as current state.

## Definition of done

- The relevant note was read before the repos were opened.
- Claims taken from a note were re-checked against current HEAD.
- Any contradiction found between note and code is reported, so the note can be
  corrected later.
