# CLAUDE.md - etabli

Claude Code adapter. Shared identity, style, cognition, code, review, ticket,
anti-sycophancy, contrarian, and git rules live in `pi/AGENTS.md`; read it.

## Sources
- Repo: `AGENTS.md`; shared rules: `pi/AGENTS.md`; workflow: `workflow/agent-quick-card.md` first, `workflow/spec.md` (full map,
  wins on conflict) when the route or a gate is in doubt; review: `workflow/review-rubric.md`; tickets:
  `workflow/ticket-template.md`; plans: `PLAN_TEMPLATE*.md`, root `PLAN.md`.
- Memory: proactively consult the memory vault (scope-resolved root: work -> ~/work/brain when present, else ~/work/obvault) per
  `workflow/skills/obvault-memory.md`.

## Claude Workflow
- Follow the Etabli workflow (quick card, then the route contract); infer the
  route yourself. Claude hooks guard
  writes only; route classification is library-only (ADR-0014).
- `/goal` only for measurable long loops with validation evidence and a cap.
- For routes with a plan, use only root `PLAN.md` and implement only from `Status: READY`.
- After validating that plan's implementation, archive to `docs/plan/YYYYMMDD-short-slug.md`, then delete root `PLAN.md`.
- Answers/handoffs follow `workflow/answer-quality.md` and its live final gate;
  use `scripts/answer-quality-check` only for durable artifacts.
- Use `/verify-workflow` for workflow evidence; do not shadow native `/verify`.
- Orchestration parity: `workflow/skills/orchestration.md`; Pi Task* state is
  Pi-only unless equivalent runtime capability is exposed.

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

@RTK.md
