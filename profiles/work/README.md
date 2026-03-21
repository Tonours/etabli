# Work Profile

Primary fit:
- Claude for work use

## Intent

Optimize for clarity, bounded autonomy, and easier handoff in mixed-team or client-sensitive contexts.

## Expected defaults

- Runtime: Claude-first for work-facing flows
- Providers / models: prefer work-approved or easily auditable providers/models; avoid implicit personal-local dependencies in shared work flows
- Environment: worktree-based isolation, explicit plans, explicit review, explicit handoff
- Allowed commands / tools: Claude `/plan`, `/plan-review`, `/implement`, `/review`, `/handoff*`, repo worktree helpers, and only the smallest necessary local tooling
- Autonomy: tighter, with more visible contracts
- Extensions / integrations: prefer boring, auditable plumbing over local magic; avoid depending on personal-only local helpers in shared work flows
- Safety posture: favor explicit artifacts, auditable paths, and reversible changes; keep sensitive client/project context out of repo-tracked memory by default

## Practical differences

- Bias toward documented, shareable workflows over personal shortcuts.
- Keep client/project context out of repo-tracked memory by default.
- Prefer contracts that survive handoff across humans and runtimes.
- Profile selection is manual for now; use this profile when work-facing constraints matter more than local convenience.

## Non-goals

- This does not define a separate plan format.
- This does not require a different status model.
- This does not add automatic policy enforcement in this slice.
