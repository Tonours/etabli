#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

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

assert_not_contains() {
  local text="$1"
  local needle="$2"

  case "$text" in
    *"$needle"*)
      printf 'did not expect output to contain: %s\noutput was:\n%s\n' "$needle" "$text" >&2
      exit 1
      ;;
  esac
}

assert_empty() {
  local text="$1"
  local label="$2"

  if [ -n "$text" ]; then
    printf '%s should be empty; got:\n%s\n' "$label" "$text" >&2
    exit 1
  fi
}

HAS_BUN=0
if command -v bun >/dev/null 2>&1; then
  HAS_BUN=1
else
  printf 'SKIP pi parity (bun missing)\n'
fi

# One node process probes every scenario (route classification, guard probes,
# expectation extraction) instead of one spawn per scenario; the bash loop
# below only asserts against the captured state with shell builtins.
node --input-type=module -e '
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const root = process.argv[1];
const tmp = process.argv[2];
const lib = await import(pathToFileURL(`${root}/claude/hooks/workflow-router-lib.mjs`));
const scenariosRoot = `${root}/tests/agent-scenarios`;

const planTemplate = (status) => `# PLAN.md

## Meta
- Subject: agent scenario smoke
- Status: ${status}
- Last revised: 2026-07-03
- Archive: pending until implemented and validated

## Goal
`;

const names = readdirSync(scenariosRoot, { withFileTypes: true })
  .filter((ent) => ent.isDirectory())
  .map((ent) => ent.name)
  .sort();

const piSpecs = [];
for (const name of names) {
  const dir = `${scenariosRoot}/${name}`;
  const input = JSON.parse(readFileSync(`${dir}/input.json`, "utf8"));
  const expected = JSON.parse(readFileSync(`${dir}/expected.json`, "utf8"));
  const cwd = `${tmp}/${name}.cwd`;
  mkdirSync(cwd, { recursive: true });
  if (input.plan_status !== "missing") {
    writeFileSync(`${cwd}/PLAN.md`, planTemplate(String(input.plan_status).toUpperCase()));
  }

  const d = lib.classifyWorkflowRoute(input.prompt, { planStatus: lib.readPlanStatus(cwd) });
  const output = [
    `Route: ${d.route}`,
    `Reason: ${d.reason}`,
    `Command: ${d.command || "none"}`,
    `Artifact: ${d.artifact}`,
    `Stop: ${d.stopCondition}`,
    `Evidence: ${d.requiredEvidence}`,
  ].join("\n");
  writeFileSync(`${tmp}/${name}.route.out`, output);

  writeFileSync(`${tmp}/${name}.claude_route`, `${expected.claude_route}\n`);
  writeFileSync(`${tmp}/${name}.contains`, `${(expected.context_contains ?? []).join("\n")}\n`);
  writeFileSync(`${tmp}/${name}.not_contains`, `${(expected.context_not_contains ?? []).join("\n")}\n`);
  writeFileSync(`${tmp}/${name}.pi_expected_route`, `${expected.pi_route}\n`);
  writeFileSync(`${tmp}/${name}.pi_expected_write`, `${expected.write_allowed}\n`);

  const guard =
    expected.guard === null || expected.guard === undefined || expected.guard === false
      ? "null"
      : String(expected.guard);
  writeFileSync(`${tmp}/${name}.guard`, `${guard}\n`);
  if (guard !== "null") {
    const probe = JSON.parse(JSON.stringify(input.guard_probe).split("__CWD__").join(cwd));
    const guardInput = {
      cwd,
      hook_event_name: "PreToolUse",
      tool_name: probe.tool_name,
      tool_input: probe.tool_input,
    };
    const res = spawnSync(process.execPath, [`${root}/claude/hooks/plan-ready-guard.mjs`], {
      input: `${JSON.stringify(guardInput)}\n`,
      encoding: "utf8",
    });
    if (res.status !== 0) {
      process.stderr.write(res.stderr ?? "");
      process.exit(res.status ?? 1);
    }
    writeFileSync(`${tmp}/${name}.guard.out`, res.stdout);
  }

  piSpecs.push({ name, prompt: input.prompt, plan_status: input.plan_status });
}
writeFileSync(`${tmp}/pi-specs.json`, `${JSON.stringify(piSpecs)}\n`);
' "$ROOT_DIR" "$TMP_ROOT"

if [ "$HAS_BUN" -eq 1 ]; then
  # One bun process checks Pi runtime parity for every scenario.
  (
    cd "$ROOT_DIR/pi"
    bun -e '
import { readFileSync, writeFileSync } from "node:fs";
import { classifyWorkflowRoute } from "./extensions/lib/workflow-router-runtime.ts";
const tmp = process.argv[1] ?? process.argv[2];
const specs = JSON.parse(readFileSync(`${tmp}/pi-specs.json`, "utf8"));
for (const spec of specs) {
  const d = classifyWorkflowRoute(spec.prompt, { planStatus: spec.plan_status });
  writeFileSync(`${tmp}/${spec.name}.pi_route`, `${d.route}\n`);
  writeFileSync(`${tmp}/${spec.name}.pi_write`, `${d.writeAllowed}\n`);
}
' -- "$TMP_ROOT"
  )
fi

for scenario_dir in "$ROOT_DIR"/tests/agent-scenarios/*/; do
  name="$(basename "$scenario_dir")"

  IFS= read -r claude_route <"$TMP_ROOT/$name.claude_route"
  router_output="$(cat "$TMP_ROOT/$name.route.out")"

  assert_contains "$router_output" "Route: $claude_route"

  while IFS= read -r needle; do
    [ -z "$needle" ] && continue
    assert_contains "$router_output" "$needle"
  done <"$TMP_ROOT/$name.contains"

  while IFS= read -r needle; do
    [ -z "$needle" ] && continue
    assert_not_contains "$router_output" "$needle"
  done <"$TMP_ROOT/$name.not_contains"

  if [ "$HAS_BUN" -eq 1 ]; then
    IFS= read -r pi_route <"$TMP_ROOT/$name.pi_expected_route"
    IFS= read -r write_allowed <"$TMP_ROOT/$name.pi_expected_write"
    IFS= read -r actual_pi_route <"$TMP_ROOT/$name.pi_route"
    IFS= read -r actual_write_allowed <"$TMP_ROOT/$name.pi_write"
    if [ "$actual_pi_route" != "$pi_route" ]; then
      printf '%s expected pi route %s, got %s\n' "$name" "$pi_route" "$actual_pi_route" >&2
      exit 1
    fi
    if [ "$actual_write_allowed" != "$write_allowed" ]; then
      printf '%s expected writeAllowed %s, got %s\n' "$name" "$write_allowed" "$actual_write_allowed" >&2
      exit 1
    fi
  fi

  IFS= read -r guard_expected <"$TMP_ROOT/$name.guard"
  if [ "$guard_expected" != "null" ]; then
    guard_output="$(cat "$TMP_ROOT/$name.guard.out")"
    case "$guard_expected" in
      deny) assert_contains "$guard_output" '"permissionDecision":"deny"' ;;
      allow) assert_empty "$guard_output" "$name guard output" ;;
      *)
        printf '%s has unsupported guard expectation: %s\n' "$name" "$guard_expected" >&2
        exit 1
        ;;
    esac
  fi

  printf 'PASS: %s\n' "$name"
done
