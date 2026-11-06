---
status: accepted
date: 2026-11-06
tags: [harness, codex, skills, deploy]
affected_components: [scripts/lib/surfaces.mjs, scripts/deploy-agent-workflow, codex/AGENTS.md, docs/symlink-layout.md, docs/adr/0031]
---

# Deploy Codex as a managed runtime

Codex is back in daily use for planning and implementation, so Etabli
deploys it like Claude and Pi. `scripts/deploy-agent-workflow` links
`~/.codex/AGENTS.md` to `codex/AGENTS.md`, `~/.codex/workflow` and the plan
templates to the repo, and every active-scope catalog skill into
`~/.codex/skills` (the Claude set: `pi_core` does not gate it, and `adr` is
withheld under `work` as on Claude). `--check` reports Codex drift like any
other link. This supersedes ADR-0031's Codex clause; its Devin and
`~/.agents` clauses stand, and ADR-0031's "a new harness needs a new ADR and
its own deploy block" is this ADR.

Codex has no import, so the adapter tells the model to read
`~/.codex/workflow/agent-rules.md` at session start. It names what Codex
lacks: no hooks, so Claude's write guards are rules the model applies
itself, and `request_user_input` is the question tool. A live `codex exec`
under a fixture `CODEX_HOME` listed the symlinked catalog skills and quoted
the symlinked adapter.

The former hand-kept `~/.codex/AGENTS.md` was mapped directive by directive:
rules already in `workflow/agent-rules.md` are shared, the RTK include and
the automation and audit rules are kept in the adapter, and the retired
`answer-quality-check`, the missing `workflow/team-orchestration.md` and the
approval-before-push rule (replaced by `workflow/spec.md` § Human
checkpoints) are dropped. Deploy backs the old file up beside the new link.

## Consequences

- Pi reads neither `~/.codex/skills` nor `~/.codex/AGENTS.md`, so Pi's
  skill universe is unchanged; the deploy smoke asserts it.
- A real folder in `~/.codex/skills` on a managed skill name moves to
  `~/.codex/skills.bak/`; other personal folders and foreign links stay.
- Codex sessions only see new links after a restart.
- Review date: 2027-02-06. Count Codex sessions after this ADR that load an
  Etabli catalog skill (`~/.codex/sessions`); with none, delete the Codex
  block, the adapter and this ADR's tests.
