# Final Report: Implement Pi agentic workflow loop

## Outcome
Implemented the mandatory Pi-native agentic workflow loop phases from
`docs/pi-agentic-workflow-loop-plan.md`.

Pi remains the primary tool. The implementation adds visible workflow contracts,
a read-only verifier skill, hardened planning/implementation/review skills, a
native workflow-router extension, validation-aware task continuation, and golden
fixtures for routing behavior.

## Accepted Results
- `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`, and `workflow/spec.md` now expose
  route, role, stop-condition, and required-evidence contracts.
- `workflow/router-template.md` and `workflow/verification-report-template.md`
  define reusable router and verification artifacts.
- `pi/skills/verify/SKILL.md` adds a read-only verification role with
  `VERIFIED`, `NOT VERIFIED`, and `INCONCLUSIVE` verdicts.
- `pi/skills/plan-loop/SKILL.md`, `pi/skills/plan-implement/SKILL.md`, and
  `pi/skills/implement/SKILL.md` now enforce plan evidence, drift stops, final
  validation, and `PLAN.md` deletion/archive behavior.
- `pi/skills/review/SKILL.md`, `workflow/review-rubric.md`, and
  `claude/commands/review.md` now share the same review output contract:
  `No findings.` for a clean review and final `Verdict: ...` line only.
- `pi/extensions/workflow-router.ts` and
  `pi/extensions/lib/workflow-router-runtime.ts` add Pi-native route guidance
  without wrapping Pi.
- `pi/extensions/tasks-till-done.ts` and
  `pi/extensions/lib/tasks-till-done-runtime.ts` now require validation evidence
  for implementation routes and report blocked/stalled/limit stops visibly.
- `pi/agent/settings.json`, `scripts/install.sh`, and
  `scripts/check-fix-symlinks.sh` wire the new extension and skill into the
  maintained Pi/Codex-visible surfaces.
- Golden fixtures and focused extension tests cover route classification,
  stop-condition behavior, and anti-drift route guards.

## Rejected Results
- No external wrapper was added around Pi.
- No separate `plan-challenge`, `research-plan`, prompt-template deployment, or
  `workflow-trace.ts` extension was added in this pass.

## Conflicts Resolved
- The review contract initially drifted: Pi real-condition review could answer
  with `OK`. The shared rubric, Claude command, Pi skill, and docs smoke test now
  require `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
- Symlink checks initially failed because `verify` was not linked. Running
  `bash scripts/check-fix-symlinks.sh --fix --verbose` created the expected
  local links, and the final symlink check now passes.

## Verification Evidence
- `cd pi && bun test ./extensions/__tests__/*.test.ts`: passed, 108 tests.
- `bash tests/codex-organization-smoke.sh`: passed.
- `bash tests/fix-links-smoke.sh`: passed.
- `bash tests/install-smoke.sh`: passed.
- `bash tests/workflow-docs-smoke.sh`: passed.
- `bash tests/workflow-scaffold-smoke.sh`: passed.
- `RUN_AGENT_CLI_SMOKE_SELF_TEST=1 bash tests/workflow-cli-smoke.sh`: passed.
- `RUN_AGENT_CLI_SMOKE=1 bash tests/workflow-cli-smoke.sh`: passed for Pi CLI
  and Claude binary; Claude print smoke remained opt-in as designed.
- `bash scripts/check-fix-symlinks.sh --verbose`: passed with 0 issues.
- `git diff --check`: passed.
- Terminology search found only the Anthropic source URL and legacy deploy-script
  cleanup lines.
- Real Pi checks were exercised for TaskCreate/TaskList/TaskUpdate,
  READY `PLAN.md` implementation with archive/deletion, and read-only review
  output.

## Remaining Risks
- The workflow router is heuristic. Golden fixtures cover expected local prompts,
  but new prompt classes may need new fixtures before broadening behavior.
- Prompt templates remain deferred because `~/.pi/prompts` is not currently
  deployed by installer or symlink checks.
- `workflow-trace.ts` remains deferred until route evidence is insufficient in
  actual use.

## Reusable Follow-up
- Add prompt-template deployment only after choosing where Pi prompts should live
  as a managed surface.
- Split `plan-challenge` or `research-plan` into dedicated skills only after
  repeated usage shows that the current route guidance is not enough.
- Add more golden fixtures whenever a real prompt routes incorrectly.
