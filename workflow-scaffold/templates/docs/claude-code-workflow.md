# Claude Code Workflow

Use the simplest workflow that can finish with evidence.

```text
plan -> implement -> review -> validate
```

Escalate only when one context may miss scope, UI quality, or risk:

```text
planner -> builder -> evaluator -> builder fixes -> evaluator signoff
```

## Goal Loop
Use Claude Code `/goal` only for measurable "keep working until done" tasks
with named validation and an explicit cap.

For Etabli parity, follow `workflow/skills/orchestration.md`: Claude uses
`/goal`, commands, hooks, and current runtime capability evidence; Pi Task*
semantics are Pi-only unless exposed.

## Guardrails
- Ground progress in current-session tool results.
- Do not stop because visible context is low; write a handoff only for a real
  reset.
- Use a fresh evaluator for risky work when available; otherwise label the limit.
- UI work needs screenshots, browser checks, or an honest blocked status.
