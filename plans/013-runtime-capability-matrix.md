# Plan 013: Runtime capability matrix as structured data (workflow/runtime-capabilities.json) replacing drifting prose claims

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- workflow/ claude/hooks/workflow-router-lib.mjs .github/workflows/agentic-infra.yml tests/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. If plan 003 is DONE, the router
> boilerplate lines referenced in step 3 may already be gone — skip that step
> and note it.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none (interacts with 003/005 — see steps)
- **Category**: docs
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

What each runtime (Pi, Claude, Codex) can actually do — hooks, subagents, goal state, structured task state — is currently asserted as prose in at least four places: `workflow/skills/orchestration.md` (Runtime Adapters + Runtime Notes sections), `workflow/spec.md:184-192` (Claude-native loop), the router's injected boilerplate (`claude/hooks/workflow-router-lib.mjs:362-365`, ~4 lines repeated into context on every routed prompt), and `pi/extensions/lib/tasks-till-done-runtime.ts` capability labels. Prose claims drift silently; there is no proof command attached to any of them. This plan moves the facts into one structured file with a `proof_command` and honesty `label` per capability, validated in CI, and turns the prose locations into pointers. It directly implements the repo's own "capability labels" doctrine (`orchestration.md:21-33`) — labels should be checkable, not asserted.

## Current state

- `workflow/skills/orchestration.md:9-19` — Runtime Adapters bullets (Task* Pi-only, Claude `/goal`, Codex multi-agent runner); `:92-128` — Runtime Notes per runtime with concrete capability claims (e.g. Pi `TaskExecute` blocked until `subagents:rpc:ping|spawn|stop` confirmed; Codex `multi_agent_v1` runner with `spawn_agent`/`wait_agent`/`close_agent`).
- `workflow/spec.md:184-192` — "Claude orchestration parity is `proxy_supported` through `/goal`, commands, hooks, and smoke tests…".
- `claude/hooks/workflow-router-lib.mjs:362-365` — boilerplate injected per routed prompt:

```js
    "Runtime adapter: Claude command/hooks adapter.",
    "Runtime loop: use Claude Code `/goal` for long-running completion loops; hooks only route and guard.",
    "Task state: Task* tools are Pi-only. Claude parity is proxy_supported through `/goal`, slash commands, hook context, and focused smoke tests.",
    "Capability labels: confirmed for local hook/script behavior; proxy_supported for Claude runtime loops unless a live Claude `/goal` run is executed; blocked or unknown must be reported explicitly.",
```

- Label vocabulary already defined: `confirmed | proxy_supported | blocked | unknown` (`orchestration.md:21-33`; also typed in `pi/extensions/lib/tasks-till-done-runtime.ts:58`).
- CI validates JSON config with `jq empty` (`.github/workflows/agentic-infra.yml:27-31`) — the pattern to extend.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| JSON valid | `jq empty workflow/runtime-capabilities.json` | exit 0 |
| New smoke | `bash tests/runtime-capabilities-smoke.sh` | exit 0 |
| Docs smoke | `bash tests/workflow-docs-smoke.sh` | exit 0 |
| Hooks smoke | `bash tests/claude-hooks-smoke.sh` | exit 0 |

## Scope

**In scope**:
- `workflow/runtime-capabilities.json` (new)
- `tests/runtime-capabilities-smoke.sh` (new)
- `workflow/skills/orchestration.md` (Runtime Notes → pointer + keep doctrine)
- `workflow/spec.md` (parity paragraph → pointer)
- `claude/hooks/workflow-router-lib.mjs` (2 boilerplate lines → 1 pointer line; skip if plan 003 already removed them)
- `.github/workflows/agentic-infra.yml` (add jq validation + smoke)

**Out of scope**:
- `pi/extensions/lib/tasks-till-done-runtime.ts` — its labels are runtime-computed, not static claims; leave as is.
- Automating the proof commands' EXECUTION in CI (some need live runtimes/credentials; the matrix records them, humans/agents run them when re-labeling).
- Adding runtimes beyond pi/claude/codex.

## Git workflow

- Branch: `advisor/013-capability-matrix`
- Commit: `feat(workflow): add structured runtime capability matrix`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Write `workflow/runtime-capabilities.json`

Shape (top-level object keyed by runtime; every capability entry carries label + proof + source):

```json
{
  "$comment": "Single source of truth for runtime capability claims. Labels per workflow/skills/orchestration.md: confirmed | proxy_supported | blocked | unknown. Re-label only with the proof_command output.",
  "updated_at": "2026-07-03",
  "runtimes": {
    "pi": {
      "supports_hooks": {"label": "confirmed", "proof_command": "cd pi && bun test ./extensions/__tests__/*.test.ts", "notes": "extensions are the hook surface"},
      "supports_subagents": {"label": "blocked", "proof_command": "check subagents:rpc:ping/spawn/stop in the active Pi runtime", "notes": "TaskExecute blocked until rpc protocol confirmed (orchestration.md Runtime Notes)"},
      "supports_goal_state": {"label": "proxy_supported", "proof_command": "tasks-till-done loop with structured TaskList details", "notes": ""},
      "supports_structured_task_state": {"label": "confirmed", "proof_command": "cd pi && bun test ./extensions/__tests__/tasks-till-done*.test.ts", "notes": ""}
    },
    "claude": {
      "supports_hooks": {"label": "confirmed", "proof_command": "bash tests/claude-hooks-smoke.sh", "notes": ""},
      "supports_subagents": {"label": "proxy_supported", "proof_command": "live Agent-tool dispatch in a Claude Code session", "notes": ""},
      "supports_goal_state": {"label": "proxy_supported", "proof_command": "live /goal run in the current session", "notes": "do not claim Pi Task* semantics"},
      "supports_structured_task_state": {"label": "blocked", "proof_command": "none — no Pi Task* equivalent exposed", "notes": ""}
    },
    "codex": {
      "supports_hooks": {"label": "proxy_supported", "proof_command": "bash tests/codex-organization-smoke.sh", "notes": ""},
      "supports_subagents": {"label": "unknown", "proof_command": "check multi_agent_v1 runner (spawn_agent/wait_agent/close_agent) in the active Codex App", "notes": "confirmed evidence is runtime-session-scoped only"},
      "supports_goal_state": {"label": "proxy_supported", "proof_command": "live /goal run in Codex", "notes": ""},
      "supports_structured_task_state": {"label": "blocked", "proof_command": "none — simulate packets under .workflow/<slug>/", "notes": ""}
    }
  }
}
```

IMPORTANT: the labels above are this plan's best reading of `orchestration.md`'s current claims — transcribe, don't invent. Where orchestration.md is explicit (Pi TaskExecute blocked-until-rpc; Claude no Task* equivalent; Codex runner session-scoped), mirror it exactly; where it is silent, use `unknown`, never `confirmed`.

**Verify**: `jq empty workflow/runtime-capabilities.json` → exit 0.

### Step 2: Write `tests/runtime-capabilities-smoke.sh`

House harness style. Assert with `jq`:
1. Top-level `runtimes` has exactly `pi`, `claude`, `codex`.
2. Every runtime has exactly the four capability keys.
3. Every entry has `label` in the allowed set and a non-empty `proof_command`.
4. Every `label` value used is one of the four defined in `workflow/skills/orchestration.md` (grep the doc for the four backticked labels; diff sets).

**Verify**: `bash tests/runtime-capabilities-smoke.sh` → exit 0.

### Step 3: Point the prose at the matrix

- `workflow/skills/orchestration.md`: keep the label doctrine (`:21-33`) and delegation/retry rules untouched; in "Runtime Adapters" and "Runtime Notes", add one line at the top of each: "Current capability labels and proof commands: `workflow/runtime-capabilities.json` (structured source of truth)." Trim ONLY sentences that state a bare capability label now carried by the JSON (e.g. "Task* tools are Pi-only unless…" stays — it is a rule, not a label; "`TaskExecute` requires explicit subagent tracking capability" stays as doctrine, but its blocked-status claim gets "see runtime-capabilities.json" instead of hard-coding the label). Be conservative: when unsure whether a sentence is rule or label, keep it.
- `workflow/spec.md:184-192`: keep the `/goal` usage lines; replace the parity-label sentence with "Claude orchestration parity labels: see `workflow/runtime-capabilities.json`."
- `claude/hooks/workflow-router-lib.mjs:364-365` (skip if plan 003 removed them): replace the two Task-state/capability lines with one: `"Capability labels: see workflow/runtime-capabilities.json; report blocked or unknown explicitly."` — saves ~40 tokens per routed prompt and ends the triple-maintenance.

**Verify**: `bash tests/workflow-docs-smoke.sh && bash tests/claude-hooks-smoke.sh` → exit 0 (hooks smoke asserts router output text — if it asserted the removed lines, update those assertions to the new pointer line; any other failure → STOP).

### Step 4: CI wiring

In `.github/workflows/agentic-infra.yml`: add `jq empty workflow/runtime-capabilities.json` to the "Validate JSON config files" step, and `bash tests/runtime-capabilities-smoke.sh` to the smoke list.

**Verify**: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/agentic-infra.yml'))"` → exit 0.

## Test plan

Step 2's four assertions (schema + label-vocabulary sync with orchestration.md). Docs + hooks smokes stay green.

## Done criteria

- [ ] `workflow/runtime-capabilities.json` exists, jq-valid, 3 runtimes × 4 capabilities × {label, proof_command}
- [ ] `bash tests/runtime-capabilities-smoke.sh` exits 0
- [ ] Prose pointers in orchestration.md + spec.md; no bare capability label remains that contradicts the JSON (`grep -n "proxy_supported\|blocked" workflow/spec.md workflow/skills/orchestration.md` output reviewed and each hit is doctrine, not a claim)
- [ ] Router boilerplate reduced to one pointer line (or step skipped per plan-003 note)
- [ ] `bash tests/workflow-docs-smoke.sh`, `bash tests/claude-hooks-smoke.sh` exit 0
- [ ] CI validates the JSON and runs the smoke; YAML parses
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- orchestration.md contains a capability claim you cannot map to one of the four keys × three runtimes — report it; extending the schema is a maintainer decision.
- `tests/claude-hooks-smoke.sh` or the fixtures assert the exact boilerplate lines in ways that make step 3's router edit ripple beyond text assertions.
- You catch yourself upgrading a label (e.g. `unknown` → `confirmed`) because it "seems right" — labels only move with proof-command output; transcribe or downgrade, never upgrade.

## Maintenance notes

- Re-labeling protocol: run the `proof_command`, paste its evidence in the commit message, update `label` + `updated_at`. Never edit a label without it.
- Plans 003/005 touch neighboring text (router boilerplate, spec.md structure) — whoever lands second reconciles; both plans note it.
- Future candidate (not now): a `--check-live` script that executes the locally-runnable proof commands and reports label drift.
