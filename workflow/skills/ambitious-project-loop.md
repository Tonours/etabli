# Ambitious Project Loop Contract

Shared contract for taking a broad project from rough intent to validated
delivery without losing scope, evidence, or authorization boundaries.

Use this when a request says "A to Z", "de a a z", "end to end", "projet
ambitieux", or equivalent long-running project wording. For one explicitly
requested ship task, `/ship` keeps its separate push and PR consent contract.

## Lifecycle

1. Intent: restate the measurable outcome, users, constraints, and non-goals.
2. Context discovery: inspect the repo, source docs, prior plans, tickets,
   architecture, risks, and validation surfaces.
3. Spec: create or refine a spec when the product or architecture target is not
   already concrete.
4. Decisions: add ADRs only for durable architectural choices.
5. Slicing: split the project into shippable vertical slices with ownership,
   validation, and rollback/handoff points.
   - When the user explicitly authorizes bounded autonomy for one project, use
     `workflow/project-autonomy-envelope.md` to declare the allowed files/tools,
     caps, checkpoints, forbidden actions, and final-state/held-out proof before
     continuing. Its controller reports ledger-derived transitions only; it does
     not execute a slice or broaden authorization.
6. Orchestration: use `.workflow/<slug>/` packets or runtime subagents only
   when the active runtime supports them and the user authorized delegation.
7. Implementation: follow `workflow/skills/implementation-loop.md` from a
   `READY` root `PLAN.md`.
8. Product dogfood: for user-facing flows, map scenarios and prove observable
   behavior through the strongest available surface.
9. Review and validation: run focused checks, fresh-context review when
   authorized/available, and adversarial diff review according to the active
   command contract.
10. Handoff or ship: record done/pending/next action. Push, PR, merge, deploy,
    release, and external write-back require an explicit command contract.
11. Retrospective: record recurring workflow issues as candidates for
    `workflow/skills/self-improvement-loop.md`.

## Scope Controls

- Prefer one project goal, then multiple slices; do not create one giant
  implementation blob.
- Keep each slice tied to user-visible behavior, an integration boundary, or a
  validated infrastructure milestone.
- Ask only for blocking decisions; otherwise choose reversible defaults and
  document them.
- Stop as `blocked` when required product, account, secret, production, billing,
  hardware, or live-provider evidence is unavailable.
- Preserve the two-failed-hypothesis / three-red-check no-progress stop and the
  eight-candidate maximum; write the existing `no_progress` event rather than
  silently retrying or creating a ninth proposal.

## Work Packets

Each packet names:

- objective and owner;
- files or sources to inspect/change;
- allowed and forbidden actions;
- expected output;
- validation command or evidence;
- integration dependency;
- blocked stop condition.

Simulated packets under `.workflow/<slug>/` are valid when no subagent runner is
available. Do not describe simulated packets as real delegation.

## Completion Evidence

An ambitious project run is complete only when the final handoff names:

- project outcome and slices completed;
- spec/ADR/ticket links when created;
- validation and dogfood evidence;
- review/adversary verdicts or explicit reviewer blocker;
- event ledger path;
- archive path;
- remaining risks and next action.
