# Implemented: Separate Pi and Codex orchestration configurations

## Metadata
- Archived: 2026-07-24
- Source plan: Separate Pi and Codex orchestration configurations
- Status: IMPLEMENTED
- Commit / branch: local `main`, not committed

## Outcome
- Pi adaptive model admission, role IDs, providers, token budgets, rebuttal
  rounds, and event protocol remain owned by
  `workflow/skills/multi-model-orchestration.md`.
- Codex automatic activation, Terra/Sol effort mapping, context inheritance,
  sidecar behavior, peer messaging, one-writer integration, council admission,
  and runtime fallback are now owned only by
  `codex/workflow/team-orchestration.md`.
- `workflow/skills/orchestration.md` keeps harness-neutral delegation,
  capability labels, retry, evidence, and authorization invariants plus short
  adapter pointers.
- Codex entrypoints and documentation point to the Codex profile instead of the
  Pi profile.

## Context
- The first ambient implementation placed the Codex role table inside the
  shared orchestration contract and a Codex overlay inside the Pi multi-model
  contract.
- The user identified this as a configuration ownership problem.
- The live Codex home used an existing local AGENTS topology, so a normal
  deployment dry-run could not install the newly added profile without a force
  operation.

## Decisions
### Separate configuration, share only invariants
- Context: models, runners, context inheritance, and council availability differ
  between Pi and Codex.
- Choice: keep shared workflow semantics in
  `workflow/skills/orchestration.md`; give each runtime its own configuration
  owner.
- Rejected options: duplicate the complete shared contract under each harness;
  leave the Codex model overlay in the Pi contract with headings only.
- Rationale: runtime differences become explicit without duplicating safety and
  evidence policy.
- Consequences: future Pi model changes should not alter Codex behavior, and
  Codex runner changes should not touch Pi portfolio tests.

### Keep the existing Pi profile path
- Context: Pi instructions, router tests, event validation, and historical docs
  already point to `workflow/skills/multi-model-orchestration.md`.
- Choice: retain the path but rename its title to
  `Pi Adaptive Multi-Model Orchestration` and remove all Codex markers.
- Rejected options: move the file under `pi/` in the same change.
- Rationale: achieves semantic ownership separation without unrelated routing
  and deployment churn.
- Consequences: the path remains stable while its ownership is mechanically
  explicit.

### Install only the missing live Codex profile link
- Context: the deployment smoke passed in temporary homes, but fresh review
  found `~/.codex/workflow/team-orchestration.md` absent.
- Choice: create that single symlink to the tracked Codex profile.
- Rejected options: `deploy-codex --force`, replacing the existing live
  `AGENTS.md` topology, or claiming temporary-home proof as live proof.
- Rationale: smallest reversible activation with no unrelated live-state
  mutation.
- Consequences: the current and future Codex sessions can resolve the dedicated
  profile.

## Accepted Drift
- Original plan/spec: the deployment smoke and ownership assertions were
  expected to prove completion.
- Implemented reality: a separate live-link check and one targeted symlink were
  required because the real Codex home intentionally differs from a fresh test
  home.
- Why accepted: fresh review proved the live gap; the correction stayed inside
  the declared local Codex-link scope.

## Validation Evidence
- `bash tests/codex-organization-smoke.sh`
  - result: exit 0; dedicated profile deployed in a temporary Codex home
- `bash tests/workflow-docs-smoke.sh`
  - result: exit 0; positive and negative ownership assertions pass
- `scripts/workflow-efficiency-report --json`
  - result: instruction ratio `0.2025383395029085`, within the `0.25` target;
    `source_of_truth_conflicts: 0`
- ownership searches
  - result: no `Codex`, `spawn_agent`, `fork_turns`, or `collaboration` in the
    Pi profile; no Codex runner/model block in the shared contract; no Pi
    profile reference in Codex configuration
- live link and marker check
  - result: `~/.codex/workflow/team-orchestration.md` resolves to the tracked
    Codex profile and exposes ambient activation, Terra low scout, and
    parent-only writing markers
- `git diff --check`
  - result: exit 0
- Fresh-context Terra review
  - first verdict: `BLOCK` because the live Codex profile was missing
  - fix: installed only the missing symlink and verified its target/content
  - final verdict: `GO`, `No findings.`

## Follow-up State
- Remaining risks: Codex runner/model provenance remains session-scoped and is
  intentionally handled by the Codex profile.
- Parking lot: move the Pi profile path under `pi/` only if a future migration
  can update routers, deployers, event checks, and historical links coherently.
- Superseded docs/specs: the mixed Codex sections in the shared and Pi
  orchestration contracts were removed.
- Next links: `codex/workflow/team-orchestration.md`,
  `workflow/skills/multi-model-orchestration.md`,
  `workflow/skills/orchestration.md`.
