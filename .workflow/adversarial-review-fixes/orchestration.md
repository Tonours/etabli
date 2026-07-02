# Orchestration: Adversarial review fixes

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful read-only review packets.
- Integrate packet results before final verification.
- Fix only confirmed actionable findings.
- Preserve unrelated user changes and avoid broad cleanup that is not required for a finding.
- Treat `workflow/spec.md` as canonical when docs, hooks, and runtime behavior disagree.
- Do not claim live Pi/Claude subagent guarantees without executable evidence.

## Branching Rules

- If a review finding has a reproducible behavior risk, accept it and add or update a regression test.
- If a finding is a false positive, duplicate, style-only nit, or outside scope, reject it with evidence.
- If evidence is missing and cannot be gathered locally, mark it blocked with the exact external/runtime check needed.
- If validation fails, inspect the first failing evidence and fix the narrowest cause before broadening.

## Packet Prompts

### P1-local-review

Review critical code paths locally: `pi/extensions/lib/tasks-till-done-runtime.ts`, `pi/extensions/tasks-till-done.ts`, `pi/extensions/lib/workflow-router-runtime.ts`, `pi/extensions/workflow-router.ts`, `claude/hooks/workflow-router-lib.mjs`, and tests.

### P2-complete-review

Independent read-only review of the full current diff, including untracked files. Findings only.

### P3-adversary-review

Independent read-only adversarial review focused on missed bugs, brittle assertions, workflow drift, overclaiming, and edge cases that existing tests may not cover.

### P4-fix-integration

For each finding: accept/fix, reject with evidence, or block with exact reason. Add regression tests for behavior bugs.

### P5-final-validation

Run targeted checks first, then broad checks. Verify both workflow artifacts if touched.

## Completion Audit

- No confirmed actionable findings remain unfixed.
- Rejected findings have evidence.
- All subagents are closed.
- Final validations pass.
- `.workflow/adversarial-review-fixes` verifies successfully.
