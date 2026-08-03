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

printf 'workflow autonomous plan-loop smoke test: ok\n'
