# Implemented: check interactive workflow routing and routine records

## Metadata

- Archived: 2026-11-18
- Source plan: `PLAN.md`
- Source plan SHA-256: `552f508333a40520e107007648e99c9a184ed38760b2c7d4b1cb4e1f038cec02`
- Status: IMPLEMENTED
- Branch: test/workflow-assurance, base aebb5244
- Workflow initiative: workflow assurance

## Outcome

- The [workflow assurance guide](../workflow-assurance.md) records a six-case
  headless routing exercise for the three interactive agent hosts, guard fixture
  checks, prompt measurements, weekly incident triage and routine record tests.
- The shared Pi skill paragraph retains the four original directives in three
  lines. The README links the procedure.
- Etabli already ships the v1 producer. A real wrapper record was verified
  against the Fleet reader at `ae73a6fd78d14e4b82d481acfbb9c982fb7cc4f5`.
  The integrated Fleet branch remains under its own rollout.

## Decisions

- Use quoted synthetic cases in an isolated no-remote fixture. This exercises
  intended routing and stop conditions without executing the requests.
- Reuse the existing hook and extension fixtures. Treat a Codex read-only
  sandbox as caller-owned authority. The Codex adapter documents its PR body
  instruction, and the shared validator has its own fixtures.
- Keep the live linked checkout and its uncommitted Claude overrides outside
  the change. Use live skill metrics as separate observations.
- Rehearse a known incident in a throwaway copy and carry the triage procedure
  in the guide. Track candidates for future owner review.

## Validation Evidence

- `CI=1 scripts/verify-agentic-infra shell-docs` returned 48/48 checks,
  including routine run and adoption checks on fixtures.
- `CI=1 scripts/verify-agentic-infra pi` returned 5/5 groups, with 174 Pi
  tests passing. Focused guard and subagent coverage passed 113/113.
- The Claude hook admitted the read-only control and denied a write event.
  Removing `onFailure: block` in a temporary reviewer turned the agent smoke
  red and the current snapshot passed. The approved fix already shipped in
  PR #119. The earlier host stall experiment is in
  [the agent gates archive](20261118-agent-gates.md).
- The Codex sandbox admitted `cat fixture` and refused writing to the same
  fixture with exit 1. The content remained unchanged.
- Entry chain 326 to 325 lines and 18,133 to 18,071 UTF-8 characters. The live Pi
  block measured 7,316 characters against 7,800. The live Claude index
  returned 2,457 characters with repo/live override divergence and one
  existing keeper mismatch. The report distinguishes those states.
- Routing pilot with Claude Code 2.1.327, Codex CLI 0.170.0 and Pi 1.5.2
  returned 13/18 semantic matches before and 15/18 after. Codex and Pi each
  omitted the explicit patch pin in both review samples. Four DRAFT answers
  proposed editing the plan and all six stopped short of implementation.
  Native event output showed no tool invocation for the Codex or Pi batches.
  This single batch per revision cannot isolate the effect of the editorial
  change. The pinned input is shared and ambient context can vary by host.
  Interactive skill activation was outside this pilot.
- Fleet full crate build on Linux required macOS peer APIs. Pinned portable
  reader fixtures passed 23/23. A separate probe passed with real wrapper
  outputs for success, exit 3, an interrupted record and missed slots, using a
  synthetic plist and clock and a stub at the native birth-lookup seam.
- Simplification clean. Markdown links, whitespace and focused smoke checks
  passed on the reviewed patch. No language or UI convention surface changed.

## Review

- Planning adversary reviewed three pinned snapshots and approved
  `b0d2a7c86f4165a6df6355d22a55c0fac58c7477a97899981b0af5e1713ad208`
  (Claude Opus 5.5, Anthropic, requested and effective).
- Fresh Logic and Spec passes led to a strict DRAFT stop oracle, event
  inspection for tool calls and a reproducible portable Fleet reader recipe.
  Logic covered the deciding sources. Spec confirmed the scoped criteria.
- Independent Claude Opus 5.5 code-diff review returned GO WITH NOTES
  on `f457248c`. The Fleet delta `1abd1de2` passed the independent delta
  review. The final doc addition names target resolution before the patch
  pin, per `workflow/skills/review.md`. Final patch SHA256
  `1266d786820666bb192dd324afe98675936fdd3bdea7b44ce07980f07647df7d`.
  No access control behavior or review template changed.

## Follow-up State

- Repeat routing cases in real interactive fixture sessions to measure ambient
  skill selection and confirm patch-pin and DRAFT decisions. Fix only recurring
  misses with a reproducible test.
- Finish the Fleet reader branch's separate integration and rollout on macOS.
  Rebase with its owner and verify the disposable board and launchd path before
  activation. The Linux compatibility result does not cover alert delivery.
