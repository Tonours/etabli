#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
INSTALL_MAIN="$ROOT_DIR/scripts/lib/install-main.sh"

assert_file() {
    [ -f "$1" ] || {
        printf 'missing file: %s\n' "$1" >&2
        exit 1
    }
}

assert_dir() {
    [ -d "$1" ] || {
        printf 'missing directory: %s\n' "$1" >&2
        exit 1
    }
}

assert_contains() {
    local path="$1"
    local needle="$2"

    grep -Fq -- "$needle" "$path" || {
        printf 'expected %s in %s\n' "$needle" "$path" >&2
        exit 1
    }
}

assert_not_contains() {
    local path="$1"
    local needle="$2"

    if grep -Fq -- "$needle" "$path"; then
        printf 'did not expect %s in %s\n' "$needle" "$path" >&2
        exit 1
    fi
}

assert_same_file() {
    local expected="$1"
    local actual="$2"

    if ! cmp -s "$expected" "$actual"; then
        printf 'expected files to stay identical: %s %s\n' "$expected" "$actual" >&2
        diff -u "$expected" "$actual" >&2 || true
        exit 1
    fi
}

assert_file "$ROOT_DIR/workflow/review-rubric.md"
assert_file "$ROOT_DIR/workflow/memory.md"
assert_file "$ROOT_DIR/workflow/plan-archive.md"
assert_file "$ROOT_DIR/workflow/answer-quality.md"
assert_file "$ROOT_DIR/docs/source-grounded-answer-quality-research.md"
assert_file "$ROOT_DIR/docs/cross-project-research-grounding.md"
assert_file "$ROOT_DIR/docs/answer-quality-eval-cases.md"
assert_file "$ROOT_DIR/docs/answer-quality-goal-completion-audit.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/README.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/coverage.tsv"
assert_file "$ROOT_DIR/docs/answer-quality-traces/20260707-answer-quality-audit-handoff.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/20260707-answer-quality-coverage-gap.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/20260707-cross-project-research-grounding-handoff.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/20260707-etabli-obvault-functioning-explanation.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/20260707-goal-completion-not-verified.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/20260707-obvault-backed-memory-answer.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/20260707-large-diff-implementation-handoff.md"
assert_file "$ROOT_DIR/scripts/answer-quality-check"
assert_file "$ROOT_DIR/scripts/answer-quality-eval"
assert_file "$ROOT_DIR/scripts/answer-quality-audit"
assert_file "$ROOT_DIR/scripts/answer-quality-trace-coverage"
assert_file "$ROOT_DIR/scripts/answer-quality-trace-eval"
assert_file "$ROOT_DIR/tests/answer-quality-check-smoke.sh"
assert_file "$ROOT_DIR/tests/answer-quality-eval-smoke.sh"
assert_file "$ROOT_DIR/tests/answer-quality-audit-smoke.sh"
assert_file "$ROOT_DIR/tests/answer-quality-trace-coverage-smoke.sh"
assert_file "$ROOT_DIR/tests/answer-quality-trace-eval-smoke.sh"
assert_file "$ROOT_DIR/tests/fixtures/answer-quality/manifest.tsv"
assert_file "$ROOT_DIR/docs/plan/README.md"
assert_file "$ROOT_DIR/workflow/events.md"
assert_file "$ROOT_DIR/workflow/runtime-capabilities.json"
assert_dir "$ROOT_DIR/docs/adr"
assert_file "$ROOT_DIR/CLAUDE.md"
assert_file "$ROOT_DIR/scripts/validate-adrs"
assert_file "$ROOT_DIR/claude/skills/adr/scripts/apply-adr.mjs"
assert_file "$ROOT_DIR/claude/skills/adr/scripts/adr-validation.mjs"
assert_file "$ROOT_DIR/workflow/skills/adversary.md"
assert_file "$ROOT_DIR/workflow/skills/implementation-loop.md"
assert_file "$ROOT_DIR/workflow/skills/orchestration.md"
assert_file "$ROOT_DIR/workflow/skills/product-dogfood.md"
assert_file "$ROOT_DIR/workflow/skills/self-improvement-loop.md"
assert_file "$ROOT_DIR/workflow/skills/ambitious-project-loop.md"
assert_file "$ROOT_DIR/scripts/pr-latest-head-status"
assert_file "$ROOT_DIR/tests/pr-latest-head-status-smoke.sh"
assert_file "$ROOT_DIR/tests/fixtures/pr-maintenance/stale-review.json"
for contract in \
    bug-check \
    ci-fix \
    linear-project-setup \
    linear-ticket-create \
    linear-work \
    pr-maintenance-loop \
    pr-qa \
    pr-review \
    review \
    sec-pr; do
    assert_file "$ROOT_DIR/workflow/skills/$contract.md"
done
assert_file "$ROOT_DIR/workflow/linear-ticket-template.md"
assert_file "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_file "$ROOT_DIR/docs/codex-app-subagents.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/CLAUDE.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/docs/project-context.md"
assert_file "$ROOT_DIR/scripts/deploy-workflow"
assert_file "$ROOT_DIR/scripts/deploy-agent-workflow"
assert_file "$ROOT_DIR/claude/commands/verify-workflow.md"
assert_file "$ROOT_DIR/claude/commands/bug-check.md"
assert_file "$ROOT_DIR/claude/commands/linear-ticket-create.md"
assert_file "$ROOT_DIR/claude/commands/linear-work.md"
assert_file "$ROOT_DIR/claude/commands/pr-review.md"
assert_file "$ROOT_DIR/claude/commands/pr-qa.md"
assert_file "$ROOT_DIR/claude/commands/sec-pr.md"
assert_file "$ROOT_DIR/claude/commands/ci-fix.md"
assert_file "$ROOT_DIR/claude/commands/github-pr-review.md"
assert_file "$ROOT_DIR/claude/hooks/workflow-router.mjs"
assert_file "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
assert_file "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs"
assert_file "$ROOT_DIR/claude/settings.workflow-hooks.json"
assert_file "$ROOT_DIR/tests/claude-hooks-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-autonomous-plan-loop-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-cli-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-monitor-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-metrics-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-dossier-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-retrospect-smoke.sh"
assert_file "$ROOT_DIR/tests/router-eval-smoke.sh"
assert_file "$ROOT_DIR/tests/research-proof-check-smoke.sh"
assert_file "$ROOT_DIR/tests/lean-ctx-check-smoke.sh"
assert_file "$ROOT_DIR/scripts/workflow-monitor"
assert_file "$ROOT_DIR/scripts/workflow-metrics"
assert_file "$ROOT_DIR/scripts/workflow-dossier"
assert_file "$ROOT_DIR/scripts/workflow-retrospect"
assert_file "$ROOT_DIR/scripts/router-eval"
assert_file "$ROOT_DIR/scripts/research-proof-check"
assert_file "$ROOT_DIR/scripts/lean-ctx-check"
assert_file "$ROOT_DIR/tests/fix-links-smoke.sh"
assert_file "$ROOT_DIR/tests/install-smoke.sh"
assert_file "$ROOT_DIR/tests/deploy-agent-workflow-smoke.sh"
assert_file "$ROOT_DIR/tests/nvim-smoke.sh"
assert_file "$ROOT_DIR/scripts/profile-nvim.sh"
assert_file "$ROOT_DIR/scripts/profile-nvim-runtime.sh"

assert_contains "$INSTALL_MAIN" 'workflow/$shared_doc'
assert_contains "$INSTALL_MAIN" 'PLAN_TEMPLATE.md'
assert_contains "$INSTALL_MAIN" 'Pi workflow sources linked'
assert_contains "$INSTALL_MAIN" 'Pi $template_file linked'
assert_contains "$INSTALL_MAIN" 'Claude CLAUDE.md linked'
assert_contains "$INSTALL_MAIN" 'Claude workflow sources linked'
assert_contains "$INSTALL_MAIN" 'Claude $template_file linked'
assert_contains "$INSTALL_MAIN" 'Claude skill'
assert_contains "$INSTALL_MAIN" 'Claude workflow hook'
assert_contains "$INSTALL_MAIN" 'settings.workflow-hooks.json'
assert_contains "$INSTALL_MAIN" 'deploy-workflow'
assert_contains "$ROOT_DIR/scripts/deploy-agent-workflow" 'Deploy only the Etabli agent workflow surfaces'
assert_contains "$ROOT_DIR/scripts/deploy-agent-workflow" '--prefer-links'
assert_contains "$ROOT_DIR/scripts/deploy-agent-workflow" 'npm:@tintinweb/pi-subagents'
assert_contains "$INSTALL_MAIN" '@earendil-works/pi-coding-agent'
assert_contains "$INSTALL_MAIN" 'hunkdiff'
assert_contains "$INSTALL_MAIN" 'install_npm_global_binary_link "hunk"'
assert_contains "$INSTALL_MAIN" 'vscode-languageserver-protocol@3.17.5'
assert_contains "$INSTALL_MAIN" 'install_pi_agent_npm_pins'
assert_contains "$INSTALL_MAIN" '$HOME/.pi/agent/npm/node_modules'
assert_contains "$INSTALL_MAIN" 'via asdf'
assert_contains "$INSTALL_MAIN" 'asdf reshim nodejs'
assert_not_contains "$INSTALL_MAIN" 'nvm-sh/nvm'
assert_not_contains "$INSTALL_MAIN" '@mariozechner/pi-coding-agent'
assert_contains "$ROOT_DIR/README.md" 'deploy-workflow'
assert_contains "$ROOT_DIR/README.md" 'deploy-agent-workflow'
assert_contains "$ROOT_DIR/README.md" 'docs/adr/'
assert_contains "$ROOT_DIR/README.md" 'node scripts/validate-adrs .'
assert_contains "$ROOT_DIR/README.md" 'workflow-monitor'
assert_contains "$ROOT_DIR/README.md" 'workflow-retrospect'
assert_contains "$ROOT_DIR/README.md" 'tokens per successful outcome'
assert_contains "$ROOT_DIR/README.md" 'workflow/skills/self-improvement-loop.md'
assert_contains "$ROOT_DIR/README.md" 'workflow/skills/ambitious-project-loop.md'
assert_contains "$ROOT_DIR/README.md" 'research-proof-check'
assert_contains "$ROOT_DIR/README.md" 'answer-quality-check'
assert_contains "$ROOT_DIR/README.md" 'answer-quality-eval'
assert_contains "$ROOT_DIR/README.md" 'answer-quality-audit'
assert_contains "$ROOT_DIR/README.md" 'answer-quality-trace-coverage'
assert_contains "$ROOT_DIR/README.md" 'answer-quality-trace-eval'
assert_contains "$ROOT_DIR/README.md" 'docs/cross-project-research-grounding.md'
assert_contains "$ROOT_DIR/README.md" 'pr-latest-head-status'
assert_contains "$ROOT_DIR/README.md" 'lean-ctx-check'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/answer-quality-check'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/answer-quality-eval'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/answer-quality-audit'
assert_contains "$ROOT_DIR/README.md" 'tests/answer-quality-trace-coverage-smoke.sh'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/answer-quality-trace-eval'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'scripts/answer-quality-check'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'scripts/answer-quality-eval'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'scripts/answer-quality-audit'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'scripts/answer-quality-trace-coverage'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'scripts/answer-quality-trace-eval'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'Live Final Answer Gate'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'avoid promising a perfect numeric score'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'quality floor'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/coverage.tsv" 'obvault-backed-memory-answer'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/coverage.tsv" 'obvault-backed-memory-answer	covered'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/coverage.tsv" 'large-diff-implementation-handoff	covered'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/coverage.tsv" 'direct-repo-explanation	covered'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/coverage.tsv" 'blocked-or-inconclusive-answer	covered'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-answer-quality-coverage-gap.md" 'Verdict: needs-work'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-answer-quality-coverage-gap.md" 'Category: coverage-gap'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-cross-project-research-grounding-handoff.md" 'Verdict: pass'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-cross-project-research-grounding-handoff.md" 'Category: source-backed-cross-project-handoff'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-etabli-obvault-functioning-explanation.md" 'Verdict: pass'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-etabli-obvault-functioning-explanation.md" 'Category: direct-repo-explanation'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-goal-completion-not-verified.md" 'Verdict: pass'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-goal-completion-not-verified.md" 'Category: blocked-or-inconclusive-answer'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-obvault-backed-memory-answer.md" 'Verdict: pass'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-obvault-backed-memory-answer.md" 'Category: obvault-backed-memory-answer'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-large-diff-implementation-handoff.md" 'Verdict: pass'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-large-diff-implementation-handoff.md" 'Category: large-diff-implementation-handoff'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/README.md" 'Category: <category>'
assert_contains "$ROOT_DIR/tests/answer-quality-check-smoke.sh" 'bad-overclaim'
assert_contains "$ROOT_DIR/tests/fixtures/answer-quality/manifest.tsv" 'adversarial'
assert_contains "$ROOT_DIR/tests/fixtures/answer-quality/manifest.tsv" 'general-simple'
assert_contains "$ROOT_DIR/README.md" 'Three-harness workflow deployment'
assert_contains "$ROOT_DIR/README.md" 'syncs only managed Pi package'
assert_contains "$ROOT_DIR/README.md" 'scaffold-project'
assert_contains "$ROOT_DIR/README.md" 'tests/pr-latest-head-status-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/fix-links-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/install-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/deploy-agent-workflow-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/nvim-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/claude-hooks-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'RUN_AGENT_CLI_SMOKE=1'
assert_contains "$ROOT_DIR/README.md" 'RUN_AGENT_CLI_SMOKE_SELF_TEST=1'
assert_contains "$ROOT_DIR/README.md" 'RUN_CLAUDE_PRINT_SMOKE=1'
assert_contains "$ROOT_DIR/README.md" 'RUN_REAL_AGENT_SCENARIOS=1'
assert_contains "$ROOT_DIR/README.md" 'tests/workflow-real-agent-scenarios.sh'
assert_contains "$ROOT_DIR/README.md" 'docs/codex-app-subagents.md'
assert_contains "$ROOT_DIR/README.md" 'workflow/skills/pr-maintenance-loop.md'
assert_contains "$ROOT_DIR/README.md" 'scripts/pr-latest-head-status'
assert_contains "$ROOT_DIR/README.md" 'clean_latest_head'
assert_contains "$ROOT_DIR/README.md" 'stale_review'
assert_contains "$ROOT_DIR/README.md" 'needs_rerun'
assert_contains "$ROOT_DIR/README.md" 'claude --version'
assert_contains "$ROOT_DIR/README.md" '/skill:bug-check'
assert_contains "$ROOT_DIR/README.md" '/skill:linear-ticket-create'
assert_contains "$ROOT_DIR/README.md" '/skill:pr-review'
assert_contains "$ROOT_DIR/README.md" '/skill:ci-fix'
assert_contains "$ROOT_DIR/README.md" '/bug-check'
assert_contains "$ROOT_DIR/README.md" '/linear-ticket-create'
assert_contains "$ROOT_DIR/README.md" '/pr-review'
assert_contains "$ROOT_DIR/README.md" '/sec-pr'
assert_contains "$ROOT_DIR/README.md" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/README.md" 'hunkdiff'
assert_contains "$ROOT_DIR/README.md" 'hunk diff --watch --mode auto --theme custom --no-wrap --line-numbers --agent-notes --no-transparent-bg'
assert_contains "$ROOT_DIR/README.md" 'does not install `nvm`'
assert_contains "$ROOT_DIR/README.md" 'ambiently. Users can write ordinary prompts'
assert_contains "$ROOT_DIR/README.md" 'corrige le bug et valide'
assert_contains "$ROOT_DIR/AGENTS.md" 'Ambient activation'
assert_contains "$ROOT_DIR/AGENTS.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/AGENTS.md" 'Final answers: apply the live gate'
assert_contains "$ROOT_DIR/AGENTS.md" 'canonical `obvault` knowledge base'
assert_contains "$ROOT_DIR/CLAUDE.md" 'consult `~/work/obvault`'
assert_contains "$ROOT_DIR/CLAUDE.md" 'Architecture Decision Records'
assert_contains "$ROOT_DIR/CLAUDE.md" 'docs/adr/'
assert_contains "$ROOT_DIR/codex/AGENTS.md" 'This activation is ambient'
assert_contains "$ROOT_DIR/codex/AGENTS.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/codex/AGENTS.md" 'live final gate'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'activate the Etabli workflow automatically'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'live final gate'
assert_contains "$ROOT_DIR/codex/AGENTS.md" '~/work/obvault'
assert_contains "$ROOT_DIR/pi/AGENTS.md" '~/work/obvault'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" '~/work/obvault'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'proactively consult `~/work/obvault`'
assert_contains "$ROOT_DIR/codex/AGENTS.md" 'proactively consult `~/work/obvault`'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'proactively consult `~/work/obvault`'
assert_contains "$ROOT_DIR/workflow/skills/obvault-memory.md" 'Mandatory first check'
assert_contains "$ROOT_DIR/claude/commands/cross-repo-audit.md" '~/work/obvault/kb/'
assert_contains "$ROOT_DIR/claude/commands/spec-verify.md" '~/work/obvault/kb/'
assert_not_contains "$ROOT_DIR/claude/commands/cross-repo-audit.md" '~/work/brain'
assert_not_contains "$ROOT_DIR/claude/commands/spec-verify.md" '~/work/brain'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'Shared identity, style, cognition, code,'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'Follow `workflow/spec.md`; Claude hooks inject the selected route.'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'live final gate'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'Observed Facts'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'Decision Log'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" 'Handoff State'
assert_contains "$ROOT_DIR/workflow/ticket-template.md" '## Start here'
assert_contains "$ROOT_DIR/workflow/ticket-template.md" '## Stop conditions'
assert_contains "$ROOT_DIR/workflow/ticket-template.md" 'Keep project-specific scope'
assert_contains "$ROOT_DIR/workflow/spec.md" 'facts separate from assumptions'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/research-proof-check'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'A "10/10" answer is not a promise of omniscience.'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'OpenAI evaluation best practices'
assert_contains "$ROOT_DIR/docs/source-grounded-answer-quality-research.md" 'Status: verified for the design principles'
assert_contains "$ROOT_DIR/docs/source-grounded-answer-quality-research.md" 'https://arxiv.org/abs/2005.11401'
assert_contains "$ROOT_DIR/docs/cross-project-research-grounding.md" 'https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f'
assert_contains "$ROOT_DIR/docs/cross-project-research-grounding.md" 'not verified for global future'
assert_contains "$ROOT_DIR/docs/answer-quality-eval-cases.md" 'Status: verified for the fixture strategy'
assert_contains "$ROOT_DIR/docs/answer-quality-eval-cases.md" 'https://developers.openai.com/api/docs/guides/evaluation-best-practices'
assert_contains "$ROOT_DIR/docs/answer-quality-goal-completion-audit.md" 'Requirement Audit'
assert_contains "$ROOT_DIR/docs/answer-quality-goal-completion-audit.md" 'not mechanically provable for all future live answer outcomes'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/README.md" 'Required fields'
assert_contains "$ROOT_DIR/docs/answer-quality-traces/20260707-answer-quality-audit-handoff.md" 'Verdict: pass'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow-monitor'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow-retrospect'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Golden principles'
assert_contains "$ROOT_DIR/workflow/spec.md" 'maps, not manuals'
assert_contains "$ROOT_DIR/workflow/skills/ship.md" 'checkpoint commit'
assert_contains "$ROOT_DIR/workflow/skills/ship.md" 'understand, plan-loop, plan'
assert_contains "$ROOT_DIR/workflow/skills/ship.md" 'adversary, implement with tests, plan checks, simplification pass,'
assert_contains "$ROOT_DIR/workflow/skills/ship.md" 'fresh-context review, code-diff adversary'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Understand before planning'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Simplification pass'
assert_contains "$ROOT_DIR/workflow/skills/adversary.md" 'Code diff mode'
assert_contains "$ROOT_DIR/workflow/spec.md" 'failing test that reproduces'
assert_contains "$ROOT_DIR/workflow/spec.md" 'correctness or stated requirements'
assert_contains "$ROOT_DIR/workflow/spec.md" 'finished or explicitly handed off'
assert_contains "$ROOT_DIR/workflow/spec.md" 'third occurrence of the same review finding'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Confirmed recurring findings from `workflow-retrospect`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/skills/self-improvement-loop.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/skills/ambitious-project-loop.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'names its remediation'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/skills/product-dogfood.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/skill-design.md'
assert_file "$ROOT_DIR/workflow/skill-design.md"
assert_contains "$ROOT_DIR/workflow/skill-design.md" 'Delete-test'
assert_contains "$ROOT_DIR/workflow/skill-design.md" 'Separate steps from reference'

assert_max_lines() {
  local file="$1"
  local cap="$2"
  local lines
  lines="$(wc -l < "$file" | tr -d ' ')"
  if [ "$lines" -gt "$cap" ]; then
    printf 'map-not-manual: %s has %s lines, cap is %s; trim it or move detail to pointed docs\n' "$file" "$lines" "$cap" >&2
    exit 1
  fi
}

assert_max_lines "$ROOT_DIR/AGENTS.md" 120
assert_max_lines "$ROOT_DIR/claude/CLAUDE.md" 90
assert_max_lines "$ROOT_DIR/pi/AGENTS.md" 120
assert_contains "$ROOT_DIR/workflow/spec.md" 'must record
  the event ledger'
assert_contains "$ROOT_DIR/workflow/spec.md" 'ordinary work may record it'
assert_contains "$ROOT_DIR/workflow/spec.md" 'No-progress stop'
assert_contains "$ROOT_DIR/workflow/spec.md" 'stays red three times with no new diff'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Check-freeze'
assert_contains "$ROOT_DIR/workflow/spec.md" 'demoting the plan to `CHALLENGED` with a Decision Log'
assert_contains "$ROOT_DIR/workflow/spec.md" 'explicit cap
  (iterations or wall-clock)'
assert_contains "$ROOT_DIR/workflow/spec.md" 'fresh
  context (subagent reviewer or cross-model)'
assert_contains "$ROOT_DIR/workflow/spec.md" 'read-only fresh-context review only'
assert_contains "$ROOT_DIR/workflow/spec.md" 'does not authorize destructive, secret, production'
assert_contains "$ROOT_DIR/workflow/spec.md" 'recorded as a `handoff` event'
assert_contains "$ROOT_DIR/workflow/events.md" '`no_progress`'
assert_contains "$ROOT_DIR/workflow/events.md" '`handoff`'
assert_contains "$ROOT_DIR/workflow/events.md" '`dogfood_matrix_created`'
assert_contains "$ROOT_DIR/workflow/events.md" '`dogfood_scenario_run`'
assert_contains "$ROOT_DIR/workflow/events.md" '`self_improvement_candidate`'
assert_contains "$ROOT_DIR/workflow/events.md" '`harness_failure_pattern`'
assert_contains "$ROOT_DIR/workflow/events.md" '`harness_proposal`'
assert_contains "$ROOT_DIR/workflow/events.md" '`harness_candidate_rejected`'
assert_contains "$ROOT_DIR/workflow/events.md" '`project_slice_planned`'
assert_contains "$ROOT_DIR/workflow/events.md" '`project_slice_completed`'
assert_contains "$ROOT_DIR/scripts/workflow-event" 'dogfood_fix_applied'
assert_contains "$ROOT_DIR/scripts/workflow-event" 'self_improvement_candidate'
assert_contains "$ROOT_DIR/scripts/workflow-event" 'harness_candidate_rejected'
assert_contains "$ROOT_DIR/scripts/workflow-retrospect" 'harness_failure_pattern'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" '## Product Dogfood'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" '### Scenario Matrix'
assert_contains "$ROOT_DIR/workflow/skills/product-dogfood.md" 'Map user flows before writing a checklist'
assert_contains "$ROOT_DIR/workflow/skills/product-dogfood.md" 'Do not convert a blocked scenario into `pass`.'
assert_contains "$ROOT_DIR/workflow/skills/product-dogfood.md" 'cannot rely on validation that predates the latest product-flow edit.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'product dogfood contract'
assert_contains "$ROOT_DIR/workflow/skills/self-improvement-loop.md" 'workflow-retrospect'
assert_contains "$ROOT_DIR/workflow/skills/self-improvement-loop.md" 'never applies patches'
assert_contains "$ROOT_DIR/workflow/skills/self-improvement-loop.md" 'Weakness mining'
assert_contains "$ROOT_DIR/workflow/skills/self-improvement-loop.md" 'held-in failure'
assert_contains "$ROOT_DIR/workflow/skills/self-improvement-loop.md" 'Rejection logging'
assert_contains "$ROOT_DIR/workflow/skills/ambitious-project-loop.md" 'de a a z'
assert_contains "$ROOT_DIR/workflow/skills/ambitious-project-loop.md" 'Push, PR, merge, deploy'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'material user-facing product-flow changes'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'stop
    as plan drift and strengthen the checks before continuing'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'explicit cap'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'fresh context (subagent reviewer or cross-model)'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'spawn exactly one read-only reviewer'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'record the agent'
assert_contains "$ROOT_DIR/workflow/spec.md" 'The workflow is ambient'
assert_contains "$ROOT_DIR/workflow/spec.md" 'should not need to write "use the Etabli workflow"'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/memory.md'
assert_contains "$ROOT_DIR/workflow/spec.md" '/verify-workflow'
assert_contains "$ROOT_DIR/workflow/spec.md" 'bug-check'
assert_contains "$ROOT_DIR/workflow/spec.md" 'linear-ticket-create'
assert_contains "$ROOT_DIR/workflow/spec.md" 'pr-review'
assert_contains "$ROOT_DIR/workflow/spec.md" 'pr-qa'
assert_contains "$ROOT_DIR/workflow/spec.md" 'sec-pr'
assert_contains "$ROOT_DIR/workflow/spec.md" 'ci-fix'
assert_contains "$ROOT_DIR/workflow/spec.md" 'claude/settings.workflow-hooks.json'
assert_contains "$ROOT_DIR/workflow/spec.md" '/goal <measurable condition>'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/skills/pr-maintenance-loop.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/pr-latest-head-status'
assert_contains "$ROOT_DIR/workflow/spec.md" 'one PR, one worktree, one loop'
assert_contains "$ROOT_DIR/workflow/spec.md" 'no external'
assert_contains "$ROOT_DIR/workflow/spec.md" 'write-back/deploy/push/merge'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Autonomous plan-loop requests use `plan-implement`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Prompt wording such as "PLAN.md ready" is routing context, not proof'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Implementation-bound autonomous loops are not complete until validation,'
assert_contains "$ROOT_DIR/workflow/spec.md" 'adversary evidence, review, implemented-plan archive under `docs/plan/`, and'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/events.md'
assert_contains "$ROOT_DIR/workflow/events.md" 'outcome_metric'
assert_contains "$ROOT_DIR/workflow/events.md" 'workflow-dossier'
assert_contains "$ROOT_DIR/workflow/events.md" 'scripts/workflow-retrospect'
assert_contains "$ROOT_DIR/scripts/workflow-event" 'outcome_metric'
assert_contains "$ROOT_DIR/scripts/workflow-efficiency-report" 'documented_source_surfaces'
assert_contains "$ROOT_DIR/tests/workflow-efficiency-report-smoke.sh" 'source_of_truth_conflicts == 0'
assert_contains "$ROOT_DIR/codex/skills/goal-prompt-rewriter/SKILL.md" 'correct loop primitive for the job'
assert_contains "$ROOT_DIR/codex/skills/goal-prompt-rewriter/SKILL.md" 'outcome_metric'
assert_contains "$ROOT_DIR/codex/skills/goal-prompt-rewriter/agents/openai.yaml" 'right Codex loop prompt'
assert_contains "$ROOT_DIR/codex/AGENTS.md" 'lean-ctx is optional'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Read-only adversarial PLAN.md review'
assert_contains "$ROOT_DIR/workflow/spec.md" '`spec-guide`'
assert_contains "$ROOT_DIR/workflow/spec.md" '## Human checkpoints'
assert_contains "$ROOT_DIR/workflow/spec.md" '`EXTERNAL_WRITE_BACK_PATTERN`'
assert_contains "$ROOT_DIR/workflow/spec.md" '`human_checkpoint`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Agent memory: `docs/agent-memory/`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Shared skill contracts: `workflow/skills/`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Orchestration contract: `workflow/skills/orchestration.md`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Answer quality contract: `workflow/answer-quality.md`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Answer quality audit: `scripts/answer-quality-audit`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Answer quality trace eval: `scripts/answer-quality-trace-eval`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Single-PR maintenance contract: `workflow/skills/pr-maintenance-loop.md`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Latest-head PR evidence helper: `scripts/pr-latest-head-status`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/runtime-capabilities.json'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/plan-archive.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Implemented plan archives: `docs/plan/`'
assert_contains "$ROOT_DIR/docs/plan/README.md" 'Canonical contract: [`workflow/plan-archive.md`](../../workflow/plan-archive.md).'
assert_contains "$ROOT_DIR/docs/plan/README.md" 'It is a memory shelf, not an active planning workspace.'
assert_contains "$ROOT_DIR/workflow/plan-archive.md" 'Archive a plan if and only if it was implemented and validation ran.'
assert_contains "$ROOT_DIR/workflow/skills/adversary.md" 'Do not implement.'
assert_contains "$ROOT_DIR/workflow/skills/adversary.md" 'Keep `Status: READY` only if no blocker or high-severity issue remains.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'wording such as "PLAN.md ready" is not proof.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Review the diff against `PLAN.md`.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'implemented-plan archive under `docs/plan/`'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'Task* tools are Pi-only'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'subagents:rpc:spawn'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'multi_agent_v1'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'Codex subagents are internal sidecar workers'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'sandbox, approval, tool, and cost/token'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'observation, failure'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'workflow/events.md'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'workflow/runtime-capabilities.json'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" '`confirmed`'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" '`proxy_supported`'
assert_contains "$ROOT_DIR/pi/extensions/lib/workflow-router-runtime.ts" 'workflow-router-core.mjs'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'SELF_IMPROVEMENT_PATTERN'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'AMBITIOUS_PROJECT_PATTERN'
assert_contains "$ROOT_DIR/workflow/skills/bug-check.md" 'Adversarial Analysis'
assert_contains "$ROOT_DIR/workflow/skills/ci-fix.md" 'Never make a test pass by disarming it'
assert_contains "$ROOT_DIR/workflow/skills/linear-project-setup.md" 'Confirm with the user before creating the Project or any Epic'
assert_contains "$ROOT_DIR/workflow/skills/linear-ticket-create.md" 'Use Linear MCP as the Linear integration'
assert_contains "$ROOT_DIR/workflow/skills/linear-work.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/workflow/skills/pr-review.md" 'Use `gh`'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'One PR, one worktree, one loop.'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Never trust a clean review or green check'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'head SHA.'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" '`clean_latest_head`'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" '`stale_review`'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" '`needs_rerun`'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Do not post PR comments.'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Clean up the PR worktree explicitly'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'git status --short'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'one isolated worktree, branch, and thread'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Do not edit sibling worktrees.'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Do not push.'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Do not merge.'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Do not deploy.'
assert_contains "$ROOT_DIR/scripts/pr-latest-head-status" 'clean_review_does_not_apply_to_latest_head'
assert_contains "$ROOT_DIR/scripts/pr-latest-head-status" 'latest_head_missing_checks'
assert_contains "$ROOT_DIR/tests/pr-latest-head-status-smoke.sh" 'stale_review'
assert_contains "$ROOT_DIR/tests/pr-latest-head-status-smoke.sh" 'missing-latest-checks'
assert_contains "$ROOT_DIR/tests/fixtures/pr-maintenance/stale-review.json" '"head_sha": "old123"'
assert_contains "$ROOT_DIR/tests/fixtures/pr-maintenance/stale-review.json" '"latest_head_sha": "new456"'
assert_contains "$ROOT_DIR/tests/fixtures/pr-maintenance/missing-latest-checks.json" '"latest_head_sha": "zzz999"'
assert_contains "$ROOT_DIR/workflow/skills/pr-qa.md" 'QA Plan'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'do not wrap it in severity/file fields'
assert_contains "$ROOT_DIR/workflow/skills/sec-pr.md" 'Never merge automatically'
assert_contains "$ROOT_DIR/codex/AGENTS.md" 'multi_agent_v1.spawn_agent'
assert_contains "$ROOT_DIR/codex/AGENTS.md" 'user-owned Codex threads'
assert_contains "$ROOT_DIR/codex/skills/codex-dynamic-workflows/SKILL.md" 'multi_agent_v1.spawn_agent'
assert_contains "$ROOT_DIR/codex/skills/codex-dynamic-workflows/SKILL.md" 'Do not create user-owned Codex threads'
assert_contains "$ROOT_DIR/codex/workflow/dynamic-workflow-triggers.md" 'multi_agent_v1.spawn_agent'
assert_contains "$ROOT_DIR/docs/codex-app-subagents.md" 'multi_agent_v1.spawn_agent'
assert_contains "$ROOT_DIR/docs/codex-app-subagents.md" 'sandbox/approval posture'
assert_contains "$ROOT_DIR/docs/codex-app-subagents.md" 'simulated `.workflow/<slug>/` packets'
assert_contains "$ROOT_DIR/docs/agentic-workflow-hardening.md" 'ReAct paper'
assert_contains "$ROOT_DIR/docs/agentic-workflow-hardening.md" 'Retry with evidence'
assert_contains "$ROOT_DIR/workflow/linear-ticket-template.md" 'Resolve team/project/labels through Linear MCP'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md" 'Each archive is a distilled memory record, not a raw copy of `PLAN.md`.'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'workflow/skills/'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'workflow/skills/orchestration.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'workflow/skills/self-improvement-loop.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'workflow/skills/ambitious-project-loop.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" '## Activation'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md" 'workflow/skills/orchestration.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" 'workflow/linear-ticket-template.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" 'Ambient activation'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/CLAUDE.md" 'Ambient activation'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Do not create or update `docs/plan/` archives during planning.'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Source resolution'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" '../../PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" '../../../PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Do not tell the user the template/spec is missing.'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'autonomous plan-loop completion'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" '../../workflow/plan-archive.md'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" '../../../workflow/plan-archive.md'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" '../../workflow/skills/adversary.md'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" '../../workflow/spec.md'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" '../../../workflow/spec.md'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/pi/skills/adversary/SKILL.md" 'workflow/skills/adversary.md'
assert_contains "$ROOT_DIR/pi/skills/bug-check/SKILL.md" 'workflow/skills/bug-check.md'
assert_contains "$ROOT_DIR/pi/skills/linear-ticket-create/SKILL.md" 'workflow/skills/linear-ticket-create.md'
assert_contains "$ROOT_DIR/pi/skills/linear-work/SKILL.md" 'LINEAR_MCP_UNAVAILABLE'
assert_file "$ROOT_DIR/codex/skills/linear-work/SKILL.md"
assert_contains "$ROOT_DIR/codex/skills/linear-work/SKILL.md" '$CODEX_HOME/workflow/skills/linear-work.md'
assert_contains "$ROOT_DIR/pi/skills/pr-review/SKILL.md" 'Use `gh`'
assert_contains "$ROOT_DIR/docs/pi-cheatsheet.md" '/skill:adversary'
assert_contains "$ROOT_DIR/docs/pi-cheatsheet.md" 'workflow/skills/orchestration.md'
assert_contains "$ROOT_DIR/docs/pi-cheatsheet.md" '/skill:verify'
assert_contains "$ROOT_DIR/pi/skills/pr-qa/SKILL.md" 'workflow/skills/pr-qa.md'
assert_contains "$ROOT_DIR/pi/skills/sec-pr/SKILL.md" 'Never merge automatically'
assert_contains "$ROOT_DIR/pi/skills/ci-fix/SKILL.md" 'Never plain `--force`'
assert_contains "$ROOT_DIR/pi/skills/github-pr-review/SKILL.md" 'compatibility alias'
assert_contains "$ROOT_DIR/claude/commands/plan-loop.md" 'Do not create or update `docs/plan/` archives during planning.'
assert_contains "$ROOT_DIR/claude/commands/plan-create.md" 'Source resolution'
assert_contains "$ROOT_DIR/claude/commands/plan-create.md" '../PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/claude/commands/plan-create.md" '../../PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/claude/commands/plan-create.md" 'Do not tell the user the template/spec is missing.'
assert_contains "$ROOT_DIR/claude/commands/plan-loop.md" 'Source resolution'
assert_contains "$ROOT_DIR/claude/commands/plan-loop.md" '../PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/claude/commands/plan-loop.md" '../../PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/claude/commands/plan-implement.md" '../workflow/plan-archive.md'
assert_contains "$ROOT_DIR/claude/commands/plan-implement.md" '../../workflow/plan-archive.md'
assert_contains "$ROOT_DIR/claude/commands/plan-implement.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/claude/commands/implement.md" '../workflow/spec.md'
assert_contains "$ROOT_DIR/claude/commands/implement.md" '../../workflow/spec.md'
assert_contains "$ROOT_DIR/claude/commands/implement.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/claude/commands/adversary.md" 'workflow/skills/adversary.md'
assert_contains "$ROOT_DIR/claude/commands/verify-workflow.md" 'workflow/verification-report-template.md'
assert_contains "$ROOT_DIR/claude/commands/verify-workflow.md" 'Claude Code ships a native `/verify`'
assert_contains "$ROOT_DIR/claude/commands/bug-check.md" 'workflow/skills/bug-check.md'
assert_contains "$ROOT_DIR/claude/commands/linear-ticket-create.md" 'workflow/skills/linear-ticket-create.md'
assert_contains "$ROOT_DIR/claude/commands/linear-work.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/claude/commands/pr-review.md" 'Use `gh`'
assert_contains "$ROOT_DIR/claude/commands/pr-qa.md" 'workflow/skills/pr-qa.md'
assert_contains "$ROOT_DIR/claude/commands/sec-pr.md" 'Never merge automatically'
assert_contains "$ROOT_DIR/claude/commands/ci-fix.md" 'workflow/skills/ci-fix.md'
assert_contains "$ROOT_DIR/claude/commands/github-pr-review.md" 'compatibility alias'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Archive the final implemented plan in `docs/plan/YYYYMMDD-short-slug.md`'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'delete only the current workspace root'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'plan drift detected'
assert_contains "$ROOT_DIR/claude/commands/plan-loop.md" 'Workflow Contract'
assert_contains "$ROOT_DIR/claude/commands/plan-loop.md" 'autonomous plan-loop completion'
assert_contains "$ROOT_DIR/claude/commands/plan-implement.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/claude/commands/implement.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'do not wrap it in severity/file fields'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'End with a final line in this exact shape'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'Verdict: GO'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'Never use `OK`, `APPROVED`, `PASS`'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'bounded read-only'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" '`severity:`'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'line_range:'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'multiple changed lines'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" '`suggested_fix:`'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'without code fences or tables'
assert_not_contains "$ROOT_DIR/workflow/review-rubric.md" 'write exactly'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'workflow/skills/review.md'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'workflow/review-rubric.md'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'Verdict: GO'
assert_not_contains "$ROOT_DIR/claude/commands/review.md" 'write exactly'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'workflow/review-rubric.md'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'workflow/skills/review.md'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'Verdict: GO'
assert_not_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'write exactly'
assert_not_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'claude/review-rubric.md'
assert_contains "$ROOT_DIR/pi/package.json" '@earendil-works/pi-coding-agent'
assert_not_contains "$ROOT_DIR/pi/package.json" '@mariozechner/pi-coding-agent'
assert_contains "$ROOT_DIR/pi/extensions/filter-output.ts" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/pi/extensions/rtk.ts" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'RUN_CLAUDE_PRINT_SMOKE'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'RUN_AGENT_CLI_SMOKE_SELF_TEST'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'exec @ARGV or die'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'commands exceed their timeout'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'Claude Code binary smoke'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" '--version'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'ASDF_DATA_DIR'
assert_contains "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh" 'RUN_REAL_AGENT_SCENARIOS'
assert_contains "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh" 'ready-read-only'
assert_contains "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh" 'read-only-adversarial-plan'
assert_contains "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh" 'prompt-only-ready'
assert_contains "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh" '--include-hook-events'
assert_contains "$ROOT_DIR/scripts/profile-nvim.sh" 'pcall(dofile'
assert_contains "$ROOT_DIR/scripts/profile-nvim-runtime.sh" 'pcall(dofile'
assert_not_contains "$ROOT_DIR/scripts/profile-nvim.sh" '+lua dofile'
assert_not_contains "$ROOT_DIR/scripts/profile-nvim-runtime.sh" '+lua dofile'
assert_not_contains "$ROOT_DIR/claude/commands/plan-create.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/commands/plan-loop.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/commands/plan-implement.md" './claude/PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/claude/README.md" '~/.claude/workflow'
assert_contains "$ROOT_DIR/claude/README.md" '~/.claude/PLAN_TEMPLATE_FULL.md'
assert_contains "$ROOT_DIR/claude/README.md" '~/.claude/hooks'
assert_contains "$ROOT_DIR/claude/README.md" '/verify-workflow'
assert_contains "$ROOT_DIR/claude/README.md" '/bug-check'
assert_contains "$ROOT_DIR/claude/README.md" '/pr-review'
assert_contains "$ROOT_DIR/claude/README.md" '/github-pr-review'
assert_contains "$ROOT_DIR/claude/README.md" '/goal'
assert_contains "$ROOT_DIR/claude/README.md" '~/.claude/skills'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'UserPromptSubmit'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'actual PLAN.md status is not proven READY'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'bug-check'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'linear-ticket-create'
assert_contains "$ROOT_DIR/pi/extensions/lib/workflow-router-runtime.ts" 'pr-review'
assert_contains "$ROOT_DIR/pi/extensions/lib/workflow-router-runtime.ts" 'ci-fix'
assert_contains "$ROOT_DIR/pi/extensions/lib/workflow-router-runtime.ts" 'autonomous-plan-loop'
assert_contains "$ROOT_DIR/pi/extensions/lib/tasks-till-done-runtime.ts" 'completion_evidence_required'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'permissionDecision: "deny"'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'UserPromptSubmit'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'PreToolUse'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'MultiEdit'
assert_contains "$ROOT_DIR/pi/agent/settings.json" 'npm:@tintinweb/pi-subagents'
assert_contains "$ROOT_DIR/pi/agent/settings.json" 'npm:@tintinweb/pi-tasks'
assert_contains "$INSTALL_MAIN" 'npm:@tintinweb/pi-subagents'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'workflow/plan-archive.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'docs/agent-memory/README.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md" 'Use `/goal`'

command_file_for() {
    case "$1" in
        /plan) printf '%s\n' 'plan-create.md' ;;
        /*) printf '%s.md\n' "${1#/}" ;;
        *)
            printf 'unexpected command format: %s\n' "$1" >&2
            exit 1
            ;;
    esac
}

workflow_claude_commands="$(
    awk '
        /^Claude:$/ { in_claude = 1; next }
        in_claude && /^## / { exit }
        in_claude && /^- `\// {
            line = $0
            sub(/^- `/, "", line)
            sub(/`.*/, "", line)
            print line
        }
    ' "$ROOT_DIR/workflow/spec.md"
)"

while IFS= read -r command; do
    [ -n "$command" ] || continue
    command_file="$(command_file_for "$command")"
    assert_file "$ROOT_DIR/claude/commands/$command_file"
done <<< "$workflow_claude_commands"

while IFS= read -r command_path; do
    command_file="$(basename "$command_path")"
    case "$command_file" in
        plan-create.md) command='/plan' ;;
        *.md) command="/${command_file%.md}" ;;
        *)
            printf 'unexpected command file: %s\n' "$command_file" >&2
            exit 1
            ;;
    esac

    assert_contains "$ROOT_DIR/claude/README.md" "- \`$command\`"
done < <(find "$ROOT_DIR/claude/commands" -maxdepth 1 -type f -name '*.md' | sort)

if [ -f "$ROOT_DIR/claude/PLAN_TEMPLATE.md" ] || [ -f "$ROOT_DIR/pi/PLAN_TEMPLATE.md" ]; then
    printf 'PLAN_TEMPLATE.md must stay canonical at repo root only\n' >&2
    exit 1
fi

if [ -f "$ROOT_DIR/claude/review-rubric.md" ]; then
    printf 'Claude workflow doc pointers must not be reintroduced\n' >&2
    exit 1
fi

# Anti-drift: the embedded PLAN.md fallback shape lives verbatim in both the Pi
# plan-loop skill and the Claude plan-loop command. If they diverge, one adapter
# silently creates plans with a different shape. Extract the fenced block and
# require byte-equality.
extract_plan_fallback() {
    awk '/^```md$/{f=1;next} /^```$/{if(f){f=0}} f{print}' "$1"
}

pi_plan_fallback="$(extract_plan_fallback "$ROOT_DIR/pi/skills/plan-loop/SKILL.md")"
claude_plan_fallback="$(extract_plan_fallback "$ROOT_DIR/claude/commands/plan-loop.md")"
if [ -z "$pi_plan_fallback" ] || [ -z "$claude_plan_fallback" ]; then
    printf 'embedded PLAN.md fallback shape missing from a plan-loop adapter\n' >&2
    exit 1
fi
if [ "$pi_plan_fallback" != "$claude_plan_fallback" ]; then
    printf 'embedded PLAN.md fallback shape diverged between Pi and Claude plan-loop adapters\n' >&2
    diff <(printf '%s\n' "$pi_plan_fallback") <(printf '%s\n' "$claude_plan_fallback") >&2
    exit 1
fi

# Anti-drift: thin adapters must delegate shared behavior to workflow/skills/
# contracts instead of duplicating phase order. Each implementation-bound adapter
# references the shared contract; a missing reference means it drifted back to a
# self-contained copy of the loop.
for adapter in \
    "pi/skills/implement/SKILL.md:workflow/skills/implementation-loop.md" \
    "pi/skills/plan-implement/SKILL.md:workflow/skills/implementation-loop.md" \
    "pi/skills/adversary/SKILL.md:workflow/skills/adversary.md" \
    "pi/skills/bug-check/SKILL.md:workflow/skills/bug-check.md" \
    "pi/skills/ci-fix/SKILL.md:workflow/skills/ci-fix.md" \
    "pi/skills/linear-project-setup/SKILL.md:workflow/skills/linear-project-setup.md" \
    "pi/skills/linear-ticket-create/SKILL.md:workflow/skills/linear-ticket-create.md" \
    "pi/skills/linear-work/SKILL.md:workflow/skills/linear-work.md" \
    "pi/skills/pr-qa/SKILL.md:workflow/skills/pr-qa.md" \
    "pi/skills/pr-review/SKILL.md:workflow/skills/pr-review.md" \
    "pi/skills/review/SKILL.md:workflow/skills/review.md" \
    "pi/skills/sec-pr/SKILL.md:workflow/skills/sec-pr.md" \
    "codex/skills/linear-project-setup/SKILL.md:workflow/skills/linear-project-setup.md" \
    "codex/skills/linear-ticket-create/SKILL.md:workflow/skills/linear-ticket-create.md" \
    "codex/skills/linear-work/SKILL.md:workflow/skills/linear-work.md" \
    "claude/commands/implement.md:workflow/skills/implementation-loop.md" \
    "claude/commands/plan-implement.md:workflow/skills/implementation-loop.md" \
    "claude/commands/adversary.md:workflow/skills/adversary.md" \
    "claude/commands/bug-check.md:workflow/skills/bug-check.md" \
    "claude/commands/ci-fix.md:workflow/skills/ci-fix.md" \
    "claude/commands/linear-project-setup.md:workflow/skills/linear-project-setup.md" \
    "claude/commands/linear-ticket-create.md:workflow/skills/linear-ticket-create.md" \
    "claude/commands/linear-work.md:workflow/skills/linear-work.md" \
    "claude/commands/pr-qa.md:workflow/skills/pr-qa.md" \
    "claude/commands/pr-review.md:workflow/skills/pr-review.md" \
    "claude/commands/review.md:workflow/skills/review.md" \
    "claude/commands/sec-pr.md:workflow/skills/sec-pr.md"; do
    adapter_path="${adapter%%:*}"
    contract_ref="${adapter##*:}"
    assert_contains "$ROOT_DIR/$adapter_path" "$contract_ref"
done

duplicate_adapters="$(
    {
        find "$ROOT_DIR/pi/skills" -maxdepth 2 -type f -name 'SKILL.md'
        find "$ROOT_DIR/claude/commands" -maxdepth 1 -type f -name '*.md'
        find "$ROOT_DIR/codex/skills" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md'
    } | sort | xargs shasum | sort -k1,1 | awk '
        previous_hash == $1 {
            if (!printed) {
                print previous_line
                printed = 1
            }
            print $0
            next
        }
        {
            previous_hash = $1
            previous_line = $0
            printed = 0
        }
    '
)"
if [ -n "$duplicate_adapters" ]; then
    printf 'exact duplicate harness adapter bodies are not allowed:\n%s\n' "$duplicate_adapters" >&2
    exit 1
fi

printf 'workflow docs smoke test: ok\n'
