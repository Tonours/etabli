# Claude Code Workflow

Use the simplest evidence-backed route: plan -> implement -> review -> validate.
Escalate when one context may miss scope, UI quality, or risk.
Escalated shape: planner -> builder -> evaluator -> bounded repair.

## Goal Loop
Use `/goal` only for measurable long tasks with named validation and a cap.
Follow `workflow/skills/orchestration.md`; Pi Task* semantics stay Pi-only.

## Guardrails
- Ground progress in current-session tool results.
- Do not stop because visible context is low; write a handoff only for a real
  reset.
- Use a fresh evaluator for risky work when available; otherwise label the limit.
- UI work needs screenshots, browser checks, or an honest blocked status.
