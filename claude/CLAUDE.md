# CLAUDE.md - etabli

Claude Code adapter. Shared identity, style, cognition, code, review, ticket,
anti-sycophancy, contrarian, memory, answer and git rules live in `pi/AGENTS.md`,
imported below through its deployed link `~/.pi/agent/AGENTS.md`.

## Sources
- Repo: `AGENTS.md`; shared rules: `pi/AGENTS.md`; workflow: `workflow/agent-quick-card.md` first, `workflow/spec.md` (full map,
  wins on conflict) when the route or a gate is in doubt; review: `workflow/review-rubric.md`; tickets:
  `workflow/ticket-template.md`; plans: `PLAN_TEMPLATE*.md`, root `PLAN.md`.

## Claude Workflow
- Follow the Etabli workflow (quick card, then the route contract); infer the
  route yourself. Claude hooks guard
  writes only; route classification is library-only (ADR-0014).
- `/goal` only for measurable long loops with validation evidence and a cap.
- Use `/verify-workflow` for workflow evidence; do not shadow native `/verify`.
- Orchestration parity: `workflow/skills/orchestration.md`; Pi Task* state is
  Pi-only unless equivalent runtime capability is exposed.

## Compact instructions
When compacting, keep the root `PLAN.md` subject and status, the active ledger
run, files modified, frozen check commands and last results, open findings, and
the exact next action. Drop stale exploration output.

## Safety
- Runtime: Node.js/TypeScript, local tests.
- Autonomous mode: Claude Code runs with bypass permissions here; never pause
  to ask for approval — act, then report. This overrides the pause rule in
  `pi/AGENTS.md` for Claude Code. Ask only when the missing information is
  strictly user-only (e.g. a credential value) and cannot be found locally.
- Never expose or commit secrets, in any mode.


SOLUTION EFFICIENCY: stop at first level that applies:
skip (YAGNI) → reuse codebase → stdlib → native platform → installed dep → one-line → minimum code.
Never skip: validation, security, error handling.

@~/.pi/agent/AGENTS.md
@RTK.md
