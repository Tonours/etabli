# PLAN.md Template

## Meta
- Subject: Evolve Pi + Claude config with HazAT-inspired orchestration without replacing the current `cw` / tmux workflow
- Type: feature
- Status: READY
- Source: User request: compare our Pi config and current `PLAN.md` against `HazAT/pi-config`, then propose what to adopt for daily Pi + Claude use
- Last revised: 2026-03-14

## Goal
Define a small, execution-ready evolution path for our Pi and Claude setup that borrows the useful parts of HazAT’s config—specialized agents, stronger review flows, session handoff, and better terminal visibility—while preserving the current `cw` plan, tmux-first workflow, and safety model.

## Problem
- Current behavior: our Pi setup is strong on safety, planning, and shell/tmux discipline, but lighter on specialized agents, first-class review UX, cross-session handoff, and Claude-side workflow coverage outside planning.
- Expected behavior: Pi and Claude should share a clearer day-to-day workflow surface: learn → plan → implement → review → handoff, with lightweight delegation and terminal-aware status, without introducing a second workspace orchestrator.
- User impact: without this, useful HazAT ideas stay scattered, Claude remains underpowered versus Pi for non-plan workflows, and `cw` risks being bypassed by side workflows instead of strengthened.

## Scope
### In scope
- Add a Pi/Claude evolution plan that explicitly respects the existing `cw` roadmap
- Define a prioritized sequence for adopting HazAT-inspired capabilities
- Cover both Pi runtime changes and Claude root-folder workflow artifacts
- Prefer thin extensions/commands over heavyweight new infrastructure

### Out of scope
- Replacing `cw`, tmux, or git worktrees with `cmux`, `dmux`, or another primary orchestrator
- Rewriting the current safety stack (`tilldone`, `damage-control`, `filter-output`, `rtk`)
- Building a large custom TUI
- Broad refactors outside Pi/Claude workflow surfaces

## Relevant Context
- Product areas touched: Pi agent behavior, Claude command workflow, review flow, session handoff, terminal status visibility, optional delegation
- Likely components / files: `pi/AGENTS.md`, `pi/extensions/subagent.ts`, `pi/extensions/tool-counter.ts`, optional new lightweight Pi workflow extension(s), `pi/skills/review/SKILL.md`, `claude/README.md`, `claude/commands/`, optional shared review/handoff docs under `claude/`
- Existing constraints: current `PLAN.md` is `READY` for evolving `cw`; it explicitly rejects adopting `cmux` as the main workflow. Repo conventions require concise plans, implementation only from a `READY` plan, and no unnecessary abstraction.

## Working Hypotheses
- Hypothesis: the best HazAT ideas for us are workflow-layer features, not workspace orchestration.
  - Why it seems plausible: our current setup already has a clear tmux/worktree center (`cw`, `cw-clean`, `tmux.conf`) and the active `PLAN.md` doubles down on that direction.
  - How it will be validated or invalidated: proposed additions should fit around `cw` instead of requiring changes to its role or creating a competing entrypoint.
- Hypothesis: Pi and Claude should share workflow conventions, but not identical implementation details.
  - Why it seems plausible: both are used daily, but Pi can own runtime extensions while Claude should own reusable command/docs surfaces.
  - How it will be validated or invalidated: the plan should produce a small shared contract (review, handoff, conventions) without forcing Pi-specific runtime concepts into Claude.
- Hypothesis: specialized agents and review flows will deliver more daily value than adding more packages first.
  - Why it seems plausible: the current gaps are operational (delegation, review, handoff), not basic capability gaps.
  - How it will be validated or invalidated: the first implementation slices should improve daily loop speed without expanding the package footprint much.
- Hypothesis: named agent roles should be implemented on top of the current subagent setup first, not by immediately adopting a new agent package.
  - Why it seems plausible: we already have `pi/extensions/subagent.ts`; extending it with role presets is cheaper than changing the runtime model first.
  - How it will be validated or invalidated: the first agent slice should work with the existing subagent tool surface; only then should package adoption be reconsidered.

## Chosen Approach
Implement this in layers. First align conventions between Pi and Claude and add first-class review workflow surfaces with one shared rubric/source of truth. Then add named agent roles by evolving the existing `subagent` path, not by introducing a new orchestration package first. Then add session handoff/compress support. Add terminal/status integration only after the workflow layer is stable. Explicitly defer persistent todos, smart sessions, watchdog, and Pi→Claude bridging until the core loop proves insufficient. Rejected for now: `cmux` as primary workflow, replacing `tilldone`, importing HazAT’s stack wholesale, or adding a second workflow entrypoint beside `cw`.

## Execution Plan
1. Align conventions and ownership.
   Verification: `pi/AGENTS.md` explicitly checks Claude convention files; `claude/README.md` documents the shared workflow stages and points to the command surfaces.
2. Build review as the first shared workflow feature.
   Verification: Pi gets one review entrypoint backed by a shared rubric; Claude gets `claude/commands/review.md` plus only the smallest supporting commands actually needed.
3. Add named agent roles on top of the current subagent implementation.
   Verification: first slice supports at least `scout` and `reviewer` via role presets/instructions without adopting a new workspace or agent package.
4. Add handoff/compress for long-running sessions.
   Verification: Pi can summarize current work into a continuation artifact; Claude gets a matching `handoff` command that consumes the same contract.
5. Add terminal-aware visibility as a thin integration layer.
   Verification: status output is additive to tmux/iTerm2/sketchybar and does not change `cw`, `cw-clean`, or tmux entrypoints.
6. Re-evaluate deferred features from real usage.
   Verification: persistent todos, smart sessions, watchdog, and Pi→Claude bridge stay out unless concrete daily pain remains after steps 1-5.

## Risks And Edge Cases
- Risk / edge case: the plan becomes a grab-bag of “cool HazAT features”.
  - Impact: diluted scope, slow delivery, and drift away from the `cw` roadmap.
  - Mitigation: keep the sequence centered on the daily loop and reject any feature that creates a second workflow center.
- Risk / edge case: review logic gets duplicated across Pi and Claude.
  - Impact: two diverging workflows and extra maintenance.
  - Mitigation: share rubric/docs where possible; keep runtime behavior in Pi and prompt artifacts in Claude.
- Risk / edge case: “specialized agents” implicitly require package adoption or a new runtime model.
  - Impact: hidden scope jump and possible conflict with the current `subagent.ts` path.
  - Mitigation: first implementation must reuse `pi/extensions/subagent.ts`; package adoption is a later explicit decision, not an accidental side effect.
- Risk / edge case: specialized agents add complexity without enough payoff.
  - Impact: more files/instructions with little day-to-day usage.
  - Mitigation: start with only 2-3 roles tied to concrete recurring tasks.
- Risk / edge case: status integration becomes environment-specific and fragile.
  - Impact: brittle setup across tmux, iTerm2, sketchybar, or work machines.
  - Mitigation: make status reporting additive and optional; core workflow must remain CLI-first.
- Risk / edge case: optional features like persistent todos or Pi→Claude bridging tempt scope creep.
  - Impact: slows the core review/handoff work.
  - Mitigation: defer them unless a later review shows the core loop still has a real gap.

## Validation
- Manual checks: review the final implementation plan against the active `cw` `PLAN.md` and confirm nothing introduces a competing workspace/orchestration layer.
- Automated checks: minimal syntax/structure checks for new extensions/commands only after implementation starts; focused checks only for touched Pi/Claude files.
- Regressions to watch: `cw` remaining the single workflow entrypoint, current safety extensions staying intact, Claude plan commands continuing to work unchanged.
- Visible success criteria: Pi gains clearer delegation/review/handoff workflows, Claude gains equivalent non-plan workflow commands, and both feel more aligned in daily use without adopting `cmux`.

## Review Changes
- Key weaknesses found during review: the draft assumed specialized agents without stating how they fit the current `subagent.ts` implementation; the review flow lacked a concrete first slice; open questions were still blocking the first implementation pass.
- Changes made after review: locked the first slices to convention alignment, shared review flow, named roles over the current subagent path, then handoff, then status integration; deferred package-heavy ideas explicitly.
- Risks explicitly accepted: this plan accepts that persistent todos, smart sessions, watchdog, and Pi→Claude bridging may never be needed if the core loop improvements are sufficient.

## Open Questions
- None.

## Ready Gate
- [x] Scope is clear and bounded
- [x] Risky assumptions are explicit
- [x] Steps are executable in order
- [x] Each step has a verification
- [x] Main risks are documented
- [x] Blocking questions are resolved or consciously accepted
- [x] Plan is ready for implementation
