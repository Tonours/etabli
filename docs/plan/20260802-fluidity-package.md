# PLAN.md

## Meta
- Subject: Fluidity package — tasks-till-done flags, autonomous evidence, multi-exec auth, thinking-by-route, telemetry, scout turns, skill trim
- Status: IMPLEMENTED
- Last revised: 2026-08-02
- Archive: 20260802-fluidity-package.md

## Outcome
- tasksTillDone settings (enabled/autoContinue)
- completion evidence only with active-run.json ledger
- multi-exec: bare auth no longer critical-risk alone
- route-adaptive thinking via setThinkingLevel
- auto_continue_count → outcome_metric
- scout max_turns 8; caveman/grill-me not piCore
- tests 232 pass

## Goal
Ship the high-impact fluidity levers from the post-analysis list so interactive Pi sessions stay light while autonomous implement runs keep completion evidence.

## Workflow Contract
- Route: plan-implement
- Pattern: localize-repair-validate
- Role: implementer
- Goal verifier: unit + focused smokes green; PLAN READY gates preserved
- Budget: 1 implementation pass
- Context reset: none
- Escalation: none
- Stop condition: checks green + archive
- Required evidence: bun tests tasks-till-done + router; workflow-event/router-eval smokes if signals change

## Acceptance Criteria
- `tasksTillDone.enabled` / `autoContinue` readable from `~/.pi/agent/settings.json` (defaults true)
- Completion-evidence auto-continues only when an active workflow ledger pointer is present
- Bare `auth` alone does not select multi-exec council; security/authz/authentication still can
- Parent thinking level is suggested by route via `setThinkingLevel` when API available
- `auto_continue_count` passed into outcome_metric emit when available
- Scout `max_turns` = 8
- caveman + grill-me no longer piCore always-on skills

## Scope
### In
- tasks-till-done settings + autonomous evidence gate
- multi-exec critical-risk pattern (auth)
- optional adaptive thinking on before_agent_start
- outcome_metric auto_continue_count wiring
- scout max_turns; skill-surface + settings skills list trim
- tests + docs pi-cheatsheet

### Out
- Remove @agwab/pi-workflow package entirely
- Parent tool set / hide Task* by route
- Obvault deep cache rewrite
- Mac mini PATH ops
- Proactive /compact automation

## Facts And Assumptions
### Observed Facts
- `setThinkingLevel` exists on Pi ExtensionAPI
- `getActiveRunPointer` marks autonomous ledger runs
- Bare `auth` currently scores critical-risk → council
- caveman/grill-me are piCore=1 in skill-surface.tsv

### Assumptions
- Defaults remain enabled/autoContinue true (opt-out, not opt-in hard break)
- Interactive implement still benefits from optional validation continue caps already shipped

## Steps
1. Extend pi-runtime settings reader for tasksTillDone + helper isAutonomousRun
2. Wire tasks-till-done: enabled/autoContinue + completion evidence only if autonomous
3. Refine MULTI_EXECUTION critical-risk pattern (Claude + any dual fixtures)
4. Adaptive thinking by route in workflow-router before_agent_start
5. auto_continue_count bridge into outcome_metric emit
6. Scout max_turns 8; drop caveman/grill-me from piCore package list
7. Tests + cheatsheet; archive PLAN

## Checks
- command: `bun test pi/extensions/__tests__/tasks-till-done*.ts pi/extensions/__tests__/workflow-router*.ts pi/extensions/__tests__/settings-consistency.test.ts pi/extensions/__tests__/model-portfolio-config.test.ts`
  - expected: pass
  - last run:
- command: `bash tests/router-eval-smoke.sh` (if signal tests exist)
  - expected: pass
  - last run:

## Risks
- Thinking auto-set may surprise users mid-session (mitigate: only set when route-derived level differs and only on non-continuation user turns)
- Auth pattern change may alter a few router-eval cases

## Decision Log
- 2026-08-02: Implement high-impact + cheap medium; de-scope pi-workflow unload, tool stripping, mac mini, compaction automation
- 2026-08-02: tasksTillDone defaults stay true (soft opt-out via settings)

## Open Questions
- None

## Notes / Handoff
- User may set `"tasksTillDone": { "enabled": false }` or `"autoContinue": false` locally
