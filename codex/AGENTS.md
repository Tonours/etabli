# AGENTS.md - etabli Codex

Codex adapter, linked as `~/.codex/AGENTS.md`. Codex has no import: read
`~/.codex/workflow/agent-rules.md` at session start, the shared rules Claude
and Pi load (ADR-0043).

## Sources
- Repo: `AGENTS.md`; shared rules: `workflow/agent-rules.md`; workflow: `workflow/spec.md`
  (entry and map, wins on conflict); review: `workflow/review-rubric.md`;
  tickets: `workflow/ticket-template.md`; plans: `PLAN_TEMPLATE*.md`, root `PLAN.md`.
- A `workflow/...` file missing from the current directory is read under
  `~/.codex/workflow/`; the plan templates sit in `~/.codex/`.

## Codex Workflow
- Follow the Etabli workflow (spec, then the route contract); infer the route
  yourself. The skill catalog is linked into `~/.codex/skills`.
- Questions to the user go through `request_user_input`.
- No hooks run here: the write guards Claude enforces (PR body, comments,
  read-only reviewers) are rules you apply yourself. Open PRs with the `pr`
  skill; commit subjects follow `workflow/git-contract.md`.
- Codex's sandbox and approval policy are the host that gates effects
  (`workflow/spec.md` § Human checkpoints): when it refuses an effect, report
  it; do not work around it.
- `/goal`: `workflow/skills/orchestration.md` (measurable condition plus a cap).
- Recurring automations: read their `memory.md` first, work as a delta since
  the last run, and update it before the final answer.
- Local Codex audits: read only scoped Codex state, history and log files,
  aggregate first, and never open auth files, keys or tokens.
- Shell commands: when `~/.codex/RTK.md` exists, read it and follow it.

## Safety
- Never expose or commit secrets.
