# Result P3: hardening design

Status: accepted

## Accepted Changes

- Add source-backed hardening notes under `docs/agentic-workflow-hardening.md`.
- Extend `workflow/skills/orchestration.md` with:
  - sandbox, approval, tool, and cost/token context before delegation;
  - retry attempts that record observation, failure hypothesis, next action, and
    validation;
  - packet acceptance evidence that includes runtime adapter plus permission
    context;
  - Claude hook scope clarification;
  - Codex sandbox/approval inheritance and budget note.
- Extend Codex-specific docs and trigger recipe with sandbox/approval posture and
  evidence-consuming retry requirements.
- Add smoke-test assertions so these rules cannot silently disappear.

## Rejected Changes

- No new orchestrator or runner.
- No extra prompt ceremony that lacks a testable effect.
- No claim that Codex, Claude, and Pi expose the same subagent primitive.
