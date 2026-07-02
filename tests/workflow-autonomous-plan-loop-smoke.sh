#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

assert_contains() {
    local text="$1"
    local needle="$2"

    case "$text" in
        *"$needle"*) ;;
        *)
            printf 'expected output to contain: %s\noutput was:\n%s\n' "$needle" "$text" >&2
            exit 1
            ;;
    esac
}

router_output="$(
    cd "$ROOT_DIR"
    bun --silent -e '
      import { classifyWorkflowRoute } from "./pi/extensions/lib/workflow-router-runtime.ts";
      console.log(JSON.stringify(classifyWorkflowRoute("Lance le plan-loop en autonomie jusqu au bout")));
    '
)"
assert_contains "$router_output" '"route":"plan-implement"'
assert_contains "$router_output" '"reason":"autonomous plan-loop request"'
assert_contains "$router_output" '"nextRoute":"plan-loop"'

ready_output="$(
    cd "$ROOT_DIR"
    bun --silent -e '
      import { classifyWorkflowRoute } from "./pi/extensions/lib/workflow-router-runtime.ts";
      console.log(JSON.stringify(classifyWorkflowRoute("Implémente le PLAN.md ready", { planStatus: "ready" })));
    '
)"
assert_contains "$ready_output" '"route":"implement"'
assert_contains "$ready_output" '"nextRoute":"implement"'

completion_output="$(
    cd "$ROOT_DIR"
    bun --silent -e '
      import { decideAutoContinue, parseTaskListOutput } from "./pi/extensions/lib/tasks-till-done-runtime.ts";
      const incomplete = parseTaskListOutput("#1 [completed] Implement READY plan steps\n#2 [completed] Run validation tests");
      const complete = parseTaskListOutput([
        "#1 [completed] Implement READY plan steps",
        "#2 [completed] Run adversary plan review",
        "#3 [completed] Run validation tests",
        "#4 [completed] Review diff against PLAN.md",
        "#5 [completed] Archive implemented plan in docs/plan",
        "#6 [completed] Delete root PLAN.md after archive",
      ].join("\n"));
      console.log(JSON.stringify({
        incomplete: decideAutoContinue({
          active: true,
          taskToolUsed: true,
          summary: incomplete,
          autoContinueCount: 0,
          maxAutoContinues: 12,
          stalledCount: 0,
          maxStalledRepeats: 2,
          implementationCompletionRequired: true,
        }),
        complete: decideAutoContinue({
          active: true,
          taskToolUsed: true,
          summary: complete,
          autoContinueCount: 0,
          maxAutoContinues: 12,
          stalledCount: 0,
          maxStalledRepeats: 2,
          implementationCompletionRequired: true,
          implementationRuntimeEvidence: {
            hasImplementedPlanArchive: true,
            rootPlanDeleted: true,
          },
        }),
      }));
    '
)"
assert_contains "$completion_output" '"reason":"completion_evidence_required"'
assert_contains "$completion_output" '"reason":"complete"'

printf 'workflow autonomous plan-loop smoke test: ok\n'
