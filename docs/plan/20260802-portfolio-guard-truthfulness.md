# Implemented: Portfolio guard truthfulness — remediation, visible block, per-turn state, wrap-up budget

## Metadata

- Archived: 2026-08-02
- Source plan: `PLAN.md`
- Subject: Make the Etabli portfolio guard honest — actionable block reason, visible block, state that survives auto-retry, correct wrap-up budget
- Source plan SHA-256: `b50a2956812adefa9a02422f6046f3a39ee9d13e900a4316e6902e2c3f769d90`
- Status: IMPLEMENTED
- Commit / branch: working tree on `main` (not committed; user-controlled push)

## Outcome

- Every portfolio block reason now names its remediation (`Remediation:`), satisfying `workflow/spec.md:90`. The single-strategy reason names the three sanctioned exits (parent-only; ask the user for `multi-model`/`panel`; `adversary` route) and forbids passing a same-family substitute off as a cross-model pass.
- A blocked portfolio call appends a `kind: "portfolio-block"` entry (`etabli.workflow-router`) and a TUI entry renderer makes it visible, so the vendor's misleading "Aborted (max turns exceeded)" label is no longer the only signal. One entry per blocked tool call id (dedupe set); TaskExecute model pins are labeled `model:<pin>`.
- Guard state survives `agent_end` (auto-retry / auto-compaction) and is cleared on `agent_settled` and on each injected `before_agent_start` — role/agentId bindings and `failedFirstPassRoles` no longer die mid-turn.
- `graceTurns` raised 1 → 2 so the steered wrap-up turn lands as `steered` instead of `aborted` (turn 17 of 16 is `< 18`; a second non-final turn aborts).
- `workflow/skills/multi-model-orchestration.md` now states the guard's real coverage (5 pinned roles + pinned model overrides only) and the same-family labeling rule; escalation is user-owned or route-owned, never agent-declared.

## Context

- path/source: pi-mobile session incident — an `etabli-challenger` call was guard-blocked but displayed as "Aborted (max turns exceeded)"; the model then re-ran the mandate through `general-purpose`, bypassing the guard's intent.
- `pi/extensions/workflow-router.ts`: `blockPortfolioCall` had no remediation; `portfolioCallState` reset on every `agent_end` (`:547`); `agent_settled` handler already had a `finally` (`:573-575`).
- `pi/agent/subagents.json`: `graceTurns: 1` made the wrap-up turn trip `turnCount >= maxTurns + graceTurns`; `aborted` outranks `steered` (`agent-manager.ts:293`), so the router marked the role as a failed first pass.
- `docs/extensions.md:1567`: `appendEntry` is TUI-inert without `registerEntryRenderer`; `docs/extensions.md:1390`: `sendMessage` pollutes LLM context.
- pi dist `core/agent-session.js:755`: `_emitAgentSettled()` runs in the `finally` of `_runAgentPrompt` — settled fires on every terminal path.

## Decisions

### Keep the routing decision untouched

- Context: the incident route really was `answer` + parent-only.
- Choice: fix only the signals around the decision (reason, rendering, state lifetime, turn accounting).
- Rejected options: widening the guard to all `Agent` calls (breaks ordinary delegation); route stickiness from disk state; PLAN.md-declared escalation.
- Rationale: the guard's decision logic was correct; a PLAN.md escalation flag would let the agent self-authorize a council (parent is the sole writer of PLAN.md), against ADR-0007's intent.
- Consequences: provenance is enforced by a labeling rule, not by blocking.

### Slice 2 uses registerEntryRenderer, not sendMessage

- Context: F1 from the adversary pass — `appendEntry` alone renders nothing in the TUI.
- Choice: `pi.registerEntryRenderer?.("etabli.workflow-router", renderer)`.
- Rejected options: `sendMessage({display:true})` — enters LLM context per docs.
- Rationale: block noise must not pollute the model's context.
- Consequences: entries are durable TUI-only session history.

### State reset moves from agent_end to agent_settled

- Context: `agent_end` fires per low-level run (retries, compactions).
- Choice: single reset location in the existing `agent_settled` `finally`; `before_agent_start` injection remains the second barrier.
- Rejected options: an `agent_end` fallback reset guarded by "no pending portfolio calls".
- Rationale: F2 — the settled emission is guaranteed (`finally` of `_runAgentPrompt`).
- Consequences: mid-turn bindings survive; per-turn budget semantics preserved by caps + both reset sites.

### graceTurns: 2 (not 1, not 5)

- Context: F3 — with 1, the wrap-up turn itself aborts; with 2 the wrap-up lands `steered`.
- Choice: 2, the minimum viable value.
- Rejected options: upstream default 5 (breaks the bounded-defaults intent pinned by `model-portfolio-config.test.ts`).
- Rationale: arithmetic verified against `agent-runner.ts:619-627`.
- Consequences: worst-case +1 turn per limited sidecar, bounded by `max_turns`.

## Accepted Drift

- Original plan/spec: Validation Plan listed `bash tests/workflow-docs-smoke.sh` (full) as a green gate.
- Implemented reality: the smoke is red on a PRE-EXISTING assertion — `assert_not_contains 'Codex'` (`tests/workflow-docs-smoke.sh:359`) fails on HEAD already (3× "Codex" in `workflow/skills/multi-model-orchestration.md` from commits feb8755/090c299). This diff adds no "Codex".
- Why accepted: out of the implementer boundaries; flagged as a separate follow-up. All other validation gates are green.
- Manual TUI legs (block entry rendering in a live session; council admission regression) are not runnable from inside the implementing session — recorded for the user.

## Validation Evidence

- `cd pi && bun test ./extensions/__tests__/*.test.ts`: 238 pass / 0 fail (baseline 232; +6 tests: remediation shape, block entries + dedupe + model pin, no-throw without renderer surface, state survival agent_end → agent_settled, injected-reset refresh).
- `bash tests/pi-typecheck-smoke.sh`: ok (tsc --noEmit).
- `scripts/router-eval --min-accuracy 1 --require-alignment`: 53/53, accuracy 1, alignment_rate 1, write_route_false_positives 0.
- `scripts/verify-agentic-infra core`: 27 PASS / 0 FAIL.
- `bash tests/workflow-docs-smoke.sh`: RED pre-existing (`Codex`), see Accepted Drift.
- Fresh-context review: agent `a521f8cf` (general-purpose, read-only) — first run aborted at its turn limit (no verdict), resume delivered **GO WITH NOTES** (confidence 0.8). Folds: model-pin label, per-call dedupe, indent-noise repair, await-hardening of the settled test; rejected the theme-color note with `ThemeColor` evidence (`theme.d.ts:4` includes `"error"`).
- Adversary plan pass (same-model supervised substitution — cross-model challenger would be guard-blocked on this run, route `adversary`/`single`, verified via `classifyWorkflowRoute`): READY, F1-F5 accepted, R1-R2 rejected.

## Follow-up State

- Remaining risks: stale decision surviving into an auto-continue (mitigated by caps + dual reset); `graceTurns: 2` +1 turn worst-case; block entry noise (deduped).
- Parking lot:
  - Fix the pre-existing `Codex` assertion in `tests/workflow-docs-smoke.sh:359` (drop it or make the doc agnostic).
  - Report the status-less `details` rendering to `@tintinweb/pi-subagents` upstream.
  - Confirm what `event.prompt` holds after `/skill:` expansion (escalation signals read from skill boilerplate?).
  - Manual TUI verification of the block entry rendering.
  - Route-adaptive thinking override: `answer`-route prompts force the parent thinking level to `medium` on every turn (`workflow-router.ts` `thinkingLevelForRoute`), clobbering the user's `defaultThinkingLevel: "max"`; z.ai maps `medium` → effort `"high"` (never `max`). No opt-out exists. User choice pending (settings/env opt-out, floor at `defaultThinkingLevel`, or removal).
- Superseded docs/specs: none.
- Next links: `workflow/skills/multi-model-orchestration.md` (Guard Coverage And Provenance section), `docs/pi-cheatsheet.md`, `docs/adr/0007-gate-workflow-routing-with-deterministic-guards.md`.
