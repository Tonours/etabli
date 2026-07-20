# AGENTS.md - etabli Codex

## Runtime
- French chat; English code/commands/commits. Evidence-first.
- Prefer RTK for shell commands; otherwise use native tools with absolute paths.

## Sources
- Repo: `AGENTS.md`; workflow: `workflow/spec.md`; review:
  `workflow/review-rubric.md`; tickets: `workflow/ticket-template.md`;
  plans: `PLAN_TEMPLATE*.md`; archives: `workflow/plan-archive.md`.
- Memory: proactively consult `~/work/obvault` per
  `workflow/skills/obvault-memory.md`.

## Workflow
- This activation is ambient when `workflow/spec.md` exists; use the smallest
  route.
- One artifact: `PLAN.md`. Implement only from `Status: READY`.
- Broad/unclear: plan-loop. Plan+implement: plan-implement. READY: implement.
  Verify/retest: verify without edits.
- Answers/handoffs: follow `workflow/answer-quality.md` and its live final gate;
  use `scripts/answer-quality-check` only for durable artifacts.
- `/goal` needs measurable success, validation, scope, cap, stop condition, and
  `.workflow/<slug>/events.jsonl`.
- Use `workflow/skills/multi-model-orchestration.md`; sidecars inherit parent posture, not user threads.
- More than two sidecars need explicit approval; else narrow the plan.

## Safety
- Preserve unrelated user changes; run `git status --short` before edits.
- No push, rewrite, deploy, secrets, production mutation, destructive cleanup,
  or external write without approval.
