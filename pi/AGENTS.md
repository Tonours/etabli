# AGENTS.md - Pi global

## Identity
- French chat; English code/commands/commits. Evidence-first.
- Challenge weak assumptions with facts.

## Workflow
- Read local sources first: `AGENTS.md`, `CLAUDE.md`, docs,
  `workflow/agent-quick-card.md`, then `workflow/spec.md`.
- If `workflow/spec.md` exists, activate the Etabli workflow automatically.
- Smallest route. Current Pi profile: parent-only execution and mutation.
- Skills are instruction folders, NOT tools. To use a skill: read its SKILL.md,
  then run its scripts with the bash tool (e.g. cd <skill-dir> && ./search.js "query").
  Never invent a tool named after a skill; never claim bash cannot be used.
  Read-only `pi -p --no-session` review hunters are not writer subagents.
- For routes with a plan, use only root `PLAN.md` and implement only from `Status: READY`;
  archive implemented/validated plans in `docs/plan/`; discard unrelated/
  abandoned root plans with `scripts/plan-cleanup --discard <reason-slug>`
  instead of staying blocked.
- Answers/handoffs follow `workflow/answer-quality.md` and its live final gate;
  use `scripts/answer-quality-check` only for durable artifacts.
- Assessment/review/diagnosis: findings then stop. Otherwise act once evidence is enough.
- Pause only for destructive/irreversible work, external writes, secrets,
  production, real scope changes, or user-only input.

## Code, Review, Git
- YAGNI, KISS, DRY. Preserve unrelated user changes.
- Implement routes apply the simplification pass in
  `workflow/skills/implementation-loop.md` section 12b.
- TypeScript strict, no `any`, ES modules, local runner.
- Run focused checks; type-check code changes when available.
- Reviews lead with severity-ordered findings and file/line evidence.
- Memory: proactively consult the memory vault (scope-resolved root: work -> ~/work/brain when present, else ~/work/obvault) per
  `workflow/skills/obvault-memory.md`.
- Tickets: `workflow/ticket-template.md`; one behavior per PR.
- Branches and commits: `workflow/git-contract.md`. Branch
  `<type>/<ticket-id>-<short-slug>`, slug 3 words max, under 50 chars. Commit
  subject only, conventional, lowercase imperative, no body, no trailers.
- PR bodies: `workflow/pr-body-contract.md`. English always, repo template
  intact, lead with what changed, densest draft wins, state the stack when the
  base is not the default branch.
- Do not rewrite, amend, push, or credit AI tools unless requested.
