# Shared agent rules

## Identity
- French chat; English code/commands/commits. Evidence-first.
- Challenge weak assumptions with facts.

## Workflow
- Read local sources first: `AGENTS.md`, `CLAUDE.md`, docs, then
  `workflow/spec.md` (entry and map, wins on conflict).
- If `workflow/spec.md` exists, activate the Etabli workflow automatically.
- A `workflow/...` file missing from the current directory is read under
  `~/.claude/workflow/` (Claude) or `~/.pi/agent/workflow/` (Pi).
- Smallest route. On Pi, execution and mutation stay parent-only; Claude may
  delegate one READY plan step to a `worker` (`workflow/skills/implementation-loop.md`).
- On Pi, skills are instruction folders, not tools: read its SKILL.md, then run
  its scripts with the bash tool (e.g. cd <skill-dir> && ./search.js "query").
  Never invent a tool named after a skill; never claim bash cannot be used.
  Read-only `pi -p --no-session` review hunters are not writer subagents.
- For routes with a plan, use only root `PLAN.md` and implement only from `Status: READY`;
  archive implemented/validated plans in `docs/plan/`; discard unrelated/
  abandoned root plans with `scripts/plan-cleanup --discard <reason-slug>`
  instead of staying blocked.
- Answers/handoffs follow `workflow/answer-quality.md` and its live final gate.
- Assessment/review/diagnosis: findings then stop. Otherwise act once evidence is enough.
- No approval pauses: destructive work, pushes, deploys, and external writes
  run directly, except under a host that gates effects (`workflow/spec.md`
  § Human checkpoints). Pause only for user-only input (a credential value, a
  real scope decision). Never print or commit secrets.

## Code, Review, Git
- YAGNI, KISS, DRY. Preserve unrelated user changes.
- Implement routes apply the simplification pass in
  `workflow/skills/implementation-loop.md` section 12b.
- TypeScript strict, no `any`, ES modules, local runner.
- Run focused checks; type-check code changes when available.
- macOS has BSD `sed`: `sed -i ''`, and no `N,+M` ranges (`sed -n 'N,Mp'`).
- Reviews lead with severity-ordered findings and file/line evidence.
- Memory: before investigating, check the memory vault first: `alambic-brain` / `~/work/brain` for repos
  whose GitHub org is listed in the machine-local `~/.config/etabli/work-orgs`; all other projects use
  `alambic-obvault` / `~/work/obvault`. Match GitHub remote organization, not machine scope; no
  cross-vault fallback. See `workflow/skills/obvault-memory.md`.
- Fleet: when you run under fleet (`FLEET_SESSION_ID` set) or operate it, read
  brain `ref/fleet-memory.md` first (`vault_read`, or the file in `~/work/brain`),
  whatever the repo; it is fleet's global memory. Skip when brain is absent.
- Tickets: `workflow/ticket-template.md`; one behavior per PR.
- Branches and commits: `workflow/git-contract.md`. Branch
  `<type>/<ticket-id>-<short-slug>`, slug 3 words max, under 50 chars. Commit
  subject only, conventional, lowercase imperative, no body, no trailers.
- PR bodies: `workflow/pr-body-contract.md`. English always, repo template
  intact, lead with what changed, densest draft wins, state the stack when the
  base is not the default branch.
- Never credit AI tools.
