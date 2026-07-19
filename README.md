# Etabli

Personal dev environment for AI-assisted workflows across Codex, Neovim,
Claude Code, Pi Coding Agent, Ghostty, and tmux. The repo is the source of
truth for tracked config; `scripts/install.sh` links or bootstraps local
files into the expected tool locations.

The installer uses an existing Node.js runtime (prefers `asdf`; it does not install `nvm`). Pi comes from `@earendil-works/pi-coding-agent`, Hunk from
`hunkdiff` (https://www.hunk.dev/).

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

## Repo map

- `nvim/` - Neovim config (`nvim/README.md`)
- `ghostty/`, `tmux.conf` - terminal config
- `codex/` - Codex organization surface (`docs/codex-organization.md`)
- `pi/` - Pi config, extensions, skills, themes (`docs/pi-cheatsheet.md`)
- `claude/` - Claude Code commands, hooks, skills (`claude/README.md`)
- `workflow/` - canonical workflow contract (`workflow/spec.md`)
- `docs/adr/` - Architecture Decision Records (`node scripts/validate-adrs .`)
- `docs/plan/` - implemented plan archives (`docs/plan/README.md`)
- `scripts/` - installer, deploy, and maintenance scripts
- `tests/` - smoke tests

## Workflow

Canonical contract: `workflow/spec.md` — routing table, statuses, autonomous
loop rules, and the full command list live there, not here. `PLAN.md` is the
only execution artifact; implement only from `Status: READY`.

Self-improvement runs use `workflow/skills/self-improvement-loop.md`: local
evidence such as ledgers, plan archives, validation failures, router misses,
and review/adversary findings becomes a no-op, recommendation, router fixture,
contract patch, or mechanical check. Ambitious project runs use
`workflow/skills/ambitious-project-loop.md` to move from rough intent through
spec, decisions, slices, implementation, review, validation, handoff, and
retrospective learning without implying push, PR, deploy, or external
write-back consent.

Self-improvement candidates use harness-style evidence: weakness patterns,
bounded proposals, held-in and held-out validation, and rejected-candidate logs
stay in the local ledger before any workflow contract change is accepted.

Adapters expose the same routes: Pi as `/skill:*`
(`/skill:plan-loop`, `/skill:plan-implement`, `/skill:adversary`,
`/skill:implement`, `/skill:review`, `/skill:verify`, `/skill:bug-check`,
`/skill:linear-ticket-create`, `/skill:linear-work`, `/skill:pr-review`,
`/skill:pr-qa`, `/skill:sec-pr`, `/skill:ci-fix`), Claude as slash commands
(`/plan-loop`, `/plan-implement`, `/ship`, `/adversary`, `/implement`,
`/review`, `/verify-workflow`, `/bug-check`, `/linear-ticket-create`,
`/linear-work`, `/pr-review`, `/pr-qa`, `/sec-pr`, `/ci-fix`).

Single-PR maintenance loops are a supervised pilot contract in
`workflow/skills/pr-maintenance-loop.md`: one PR, one worktree, one loop,
fresh-context review, explicit cleanup, and latest-head review/check truth via
`scripts/pr-latest-head-status`. The helper returns `clean_latest_head`,
`stale_review`, or `needs_rerun`; it is local/read-only and does not push,
merge, deploy, post comments, or request bot reviews.

Neovim review runs through Hunk (`:ReviewInbox`, `:ReviewClaudeReview`,
`:ReviewPiReview`), opening
`hunk diff --watch --mode auto --theme custom --no-wrap --line-numbers --agent-notes --no-transparent-bg`.

## Deployment

```bash
scripts/deploy-codex --dry-run          # tracked Codex files into ~/.codex
scripts/deploy-agent-workflow --apply   # Three-harness workflow deployment
scaffold-project ~/code/my-project --new
deploy-workflow . --check               # OK / DRIFT / MISSING report
```

`deploy-codex` deploys `config.managed.toml` (never the live `config.toml`,
which can hold secrets). `deploy-agent-workflow` links Claude/Pi/Codex
workflow surfaces, Pi multi-model agents/policy, and conservatively syncs
managed Pi package and model entries in `~/.pi/agent/settings.json`.
`scaffold-project` wraps `deploy-workflow` to
install the workflow scaffold (`workflow-scaffold/templates/` plus live
`workflow/` files) into a project; existing files are never overwritten by
default.

## Validation

```bash
node scripts/validate-adrs .
tests/codex-organization-smoke.sh
tests/workflow-scaffold-smoke.sh
tests/workflow-contract-coverage-smoke.sh
tests/pr-latest-head-status-smoke.sh
tests/workflow-efficiency-report-smoke.sh
tests/workflow-monitor-smoke.sh
tests/workflow-metrics-smoke.sh
tests/workflow-dossier-smoke.sh
tests/workflow-retrospect-smoke.sh
tests/router-eval-smoke.sh
tests/research-proof-check-smoke.sh
tests/answer-quality-check-smoke.sh
tests/answer-quality-eval-smoke.sh
tests/answer-quality-audit-smoke.sh
tests/answer-quality-trace-coverage-smoke.sh
tests/answer-quality-trace-eval-smoke.sh
tests/lean-ctx-check-smoke.sh
tests/workflow-docs-smoke.sh
tests/claude-hooks-smoke.sh
tests/agent-scenarios-smoke.sh
tests/fix-links-smoke.sh
tests/install-smoke.sh
tests/deploy-agent-workflow-smoke.sh
tests/workflow-event-smoke.sh
tests/runtime-capabilities-smoke.sh
tests/nvim-smoke.sh
RUN_AGENT_CLI_SMOKE_SELF_TEST=1 tests/workflow-cli-smoke.sh
RUN_AGENT_CLI_SMOKE=1 tests/workflow-cli-smoke.sh
RUN_AGENT_CLI_SMOKE=1 RUN_CLAUDE_PRINT_SMOKE=1 tests/workflow-cli-smoke.sh
RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh
```

The CLI smoke runs real Pi prompts in a temporary project and verifies the
Claude binary with `claude --version`; `--print` stays behind
`RUN_CLAUDE_PRINT_SMOKE=1`. Codex App subagent orchestration rules:
`docs/codex-app-subagents.md`.

Workflow feedback-loop helpers are read-only: `workflow-monitor` reports stale,
blocked, failing, and active ledgers; `workflow-metrics` aggregates optional
`outcome_metric` events into tokens per successful outcome; `workflow-dossier`
emits sanitized replay/debug context for one run; `workflow-retrospect` mines
ledgers and plan archives for recurring issues and reports candidate
recommendations, router fixtures, contract patches, or mechanical checks;
`router-eval` scores Pi/Claude router decisions from `tests/router-evals/`;
`research-proof-check` rejects unsourced research artifacts;
`answer-quality-check` validates objective evidence markers for durable
answer, research, handoff, repo, and obvault-backed artifacts;
`answer-quality-eval` runs versioned typical, edge, and adversarial fixtures
from `tests/fixtures/answer-quality/`;
`answer-quality-audit` runs the full local answer-quality suite and can include
obvault with `--obvault <path>`;
`answer-quality-trace-coverage` validates the saved trace coverage matrix and
keeps uncovered response categories visible as `needs-work`;
`answer-quality-trace-eval` validates saved answer/handoff reviews under
`docs/answer-quality-traces/`;
`docs/cross-project-research-grounding.md` maps Etabli and obvault to the
external sources that justify the current workflow, memory, retrieval, and eval
shape;
`pr-latest-head-status` classifies PR review/check evidence against the latest
pushed head SHA; `lean-ctx-check` verifies the optional lean-ctx fallback
contract without installing anything.

## Config notes

- `pi/agent/settings.json` is a tracked bootstrap; the live copy stays local.
  `@tintinweb/pi-tasks` is paired with `@tintinweb/pi-subagents`
  (`TaskExecute` needs the `subagents:rpc:*` protocol).
- The bootstrap curates the exact pin `@agwab/pi-workflow@0.8.1` as an
  explicit-use Pi-only named-workflow adapter. It is initially limited by
  policy to bundled read-only pilots, and does not replace `PLAN.md`, the
  `.workflow` ledger, Task*, or OS sandboxing; see
  `workflow/pi-workflow-adapter.md`.
- Secrets and auth files stay local and untracked.

Projects scaffolded with `workflow/spec.md` activate the Etabli workflow
ambiently. Users can write ordinary prompts such as "corrige le bug et valide";
explicit workflow wording is only for heavier orchestration.
