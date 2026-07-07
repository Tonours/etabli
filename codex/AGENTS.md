# AGENTS.md - etabli Codex

## Runtime
- French chat; English code/commands/commits. Evidence-first.
- `lean-ctx is optional`: prefer it; if missing/failed/bad cwd, use native
  shell/read/search with absolute paths.

## Sources
- Repo: `AGENTS.md`; workflow: `workflow/spec.md`; review:
  `workflow/review-rubric.md`; tickets: `workflow/ticket-template.md`;
  plans: `PLAN_TEMPLATE*.md`; archives: `workflow/plan-archive.md`.
- Durable knowledge: `~/work/obvault` after its `CLAUDE.md`.

## Workflow
- This activation is ambient when `workflow/spec.md` exists; use the smallest
  route.
- One artifact: `PLAN.md`. Implement only from `Status: READY`.
- Broad/unclear: plan-loop. Plan+implement: plan-implement. READY: implement.
  Verify/retest: verify without edits.
- Answers/handoffs: follow `workflow/answer-quality.md`; use
  `scripts/answer-quality-check` for durable artifacts.
- Final answers: apply the live gate in `workflow/answer-quality.md`; answer
  the newest request, name unverified gaps, and do not promise a perfect score.
- `/goal` needs measurable success, validation, scope, cap, stop condition, and
  `.workflow/<slug>/events.jsonl`.
- Evaluate subagents only when useful and allowed. In Codex App,
  `multi_agent_v1.spawn_agent` is for internal sidecar workers/reviewers, not
  Pi Task* tools or user-owned Codex threads.

## Safety
- Preserve unrelated user changes; run `git status --short` before edits.
- No push, rewrite, deploy, secrets, production mutation, destructive cleanup,
  or external write without approval.
