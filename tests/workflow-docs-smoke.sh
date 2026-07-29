#!/usr/bin/env bash
# Map-not-manual docs smoke (G6 hygiene).
# Prefer assert_file / max-lines / anti-drift equality / thin adapter→contract
# pointers over re-pinning phrases already proven by behavioral smokes
# (plan-check-freeze, no-progress, workflow-event, dual-runtime, router-eval).

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
assert_file "$ROOT_DIR/docs/answer-quality-traces/README.md"
assert_file "$ROOT_DIR/docs/answer-quality-traces/coverage.tsv"
assert_file "$ROOT_DIR/scripts/answer-quality-check"
assert_file "$ROOT_DIR/scripts/answer-quality-eval"
assert_file "$ROOT_DIR/tests/answer-quality-check-smoke.sh"
assert_file "$ROOT_DIR/tests/answer-quality-eval-smoke.sh"

for harness_instructions in \
    "$ROOT_DIR/AGENTS.md" \
    "$ROOT_DIR/CLAUDE.md" \
    "$ROOT_DIR/claude/CLAUDE.md" \
    "$ROOT_DIR/pi/AGENTS.md" \
    "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" \
    "$ROOT_DIR/workflow-scaffold/templates/CLAUDE.md"; do
    assert_not_contains "$harness_instructions" "lean-ctx"
done
assert_file "$ROOT_DIR/tests/fixtures/answer-quality/manifest.tsv"
assert_file "$ROOT_DIR/docs/plan/README.md"
assert_file "$ROOT_DIR/workflow/events.md"
assert_file "$ROOT_DIR/workflow/runtime-capabilities.json"
assert_file "$ROOT_DIR/workflow/pi-workflow-adapter.md"
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
assert_file "$ROOT_DIR/tests/workflow-telemetry-recover-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-dossier-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-retrospect-smoke.sh"
assert_file "$ROOT_DIR/tests/router-eval-smoke.sh"
assert_file "$ROOT_DIR/tests/research-proof-check-smoke.sh"
assert_file "$ROOT_DIR/scripts/workflow-monitor"
assert_file "$ROOT_DIR/scripts/workflow-metrics"
assert_file "$ROOT_DIR/scripts/workflow-telemetry-recover"
assert_file "$ROOT_DIR/scripts/workflow-measurement-integrity"
assert_file "$ROOT_DIR/scripts/workflow-dossier"
assert_file "$ROOT_DIR/scripts/workflow-retrospect"
assert_file "$ROOT_DIR/scripts/router-eval"
assert_file "$ROOT_DIR/scripts/research-proof-check"
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
assert_contains "$INSTALL_MAIN" 'Agents workflow sources linked'
assert_contains "$INSTALL_MAIN" 'Agents $template_file linked'
assert_contains "$INSTALL_MAIN" 'Claude CLAUDE.md linked'
assert_contains "$INSTALL_MAIN" 'Claude workflow sources linked'
assert_contains "$INSTALL_MAIN" 'Claude $template_file linked'
assert_contains "$INSTALL_MAIN" 'Claude skill'
assert_contains "$INSTALL_MAIN" 'Claude workflow hook'
assert_contains "$INSTALL_MAIN" 'settings.workflow-hooks.json'
assert_contains "$INSTALL_MAIN" 'deploy-workflow'
assert_contains "$ROOT_DIR/scripts/deploy-agent-workflow" 'Deploy only the Etabli agent workflow surfaces'
assert_contains "$ROOT_DIR/scripts/deploy-agent-workflow" 'npm:@tintinweb/pi-subagents'
assert_contains "$ROOT_DIR/scripts/deploy-agent-workflow" 'npm:@agwab/pi-workflow@0.8.1'
assert_contains "$INSTALL_MAIN" '@earendil-works/pi-coding-agent'
assert_contains "$INSTALL_MAIN" 'hunkdiff'
assert_contains "$INSTALL_MAIN" 'install_npm_global_binary_link "hunk"'
assert_contains "$INSTALL_MAIN" 'vscode-languageserver-protocol@3.17.5'
assert_contains "$INSTALL_MAIN" 'install_pi_agent_npm_pins'
assert_contains "$ROOT_DIR/scripts/lib/pi-paths.sh" 'pi_agent_node_modules_dir()'
assert_contains "$INSTALL_MAIN" 'pi_agent_node_modules_dir "$HOME"'
assert_contains "$INSTALL_MAIN" 'via asdf'
assert_contains "$INSTALL_MAIN" 'asdf reshim nodejs'
assert_not_contains "$INSTALL_MAIN" 'nvm-sh/nvm'
assert_not_contains "$INSTALL_MAIN" '@mariozechner/pi-coding-agent'
assert_contains "$ROOT_DIR/README.md" 'deploy-workflow'
assert_contains "$ROOT_DIR/README.md" 'deploy-agent-workflow'
assert_contains "$ROOT_DIR/README.md" 'docs/adr/'
assert_contains "$ROOT_DIR/README.md" 'node scripts/validate-adrs .'
assert_contains "$ROOT_DIR/README.md" 'scripts/verify-agentic-infra core'
assert_contains "$ROOT_DIR/README.md" 'scripts/verify-agentic-infra full'
assert_contains "$ROOT_DIR/README.md" 'scripts/verify-agentic-infra live'
assert_contains "$ROOT_DIR/README.md" 'workflow/agent-quick-card.md'
assert_contains "$ROOT_DIR/README.md" 'workflow/contract-details.md'
assert_contains "$ROOT_DIR/README.md" 'protocol, not an OS lock'
assert_contains "$ROOT_DIR/README.md" 'workflow-monitor'
assert_contains "$ROOT_DIR/README.md" 'workflow-retrospect'
assert_contains "$ROOT_DIR/README.md" 'at least 10 representative'
assert_contains "$ROOT_DIR/README.md" 'workflow/skills/self-improvement-loop.md'
assert_contains "$ROOT_DIR/README.md" 'workflow/skills/ambitious-project-loop.md'
assert_contains "$ROOT_DIR/README.md" 'research-proof-check'
assert_contains "$ROOT_DIR/README.md" 'answer-quality-check'
assert_contains "$ROOT_DIR/README.md" 'answer-quality-eval'
assert_contains "$ROOT_DIR/README.md" 'docs/cross-project-research-grounding.md'
assert_contains "$ROOT_DIR/README.md" 'pr-latest-head-status'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/answer-quality-check'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/answer-quality-eval'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'scripts/answer-quality-check'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'scripts/answer-quality-eval'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'Live Final Answer Gate'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'avoid promising a perfect numeric score'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'quality floor'
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
assert_contains "$ROOT_DIR/README.md" 'managed Pi package/model entries'
assert_contains "$ROOT_DIR/README.md" 'scaffold-project'
assert_contains "$ROOT_DIR/README.md" 'RUN_AGENT_CLI_SMOKE=1'
assert_contains "$ROOT_DIR/README.md" 'RUN_REAL_AGENT_SCENARIOS=1'
assert_contains "$ROOT_DIR/README.md" 'workflow/skills/pr-maintenance-loop.md'
assert_contains "$ROOT_DIR/README.md" 'scripts/pr-latest-head-status'
assert_contains "$ROOT_DIR/README.md" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/README.md" 'hunkdiff'
assert_contains "$ROOT_DIR/README.md" 'preferring `asdf`'
assert_contains "$ROOT_DIR/README.md" 'activate the workflow ambiently'
assert_contains "$ROOT_DIR/AGENTS.md" 'Ambient activation'
assert_contains "$ROOT_DIR/AGENTS.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/AGENTS.md" 'Final answers: apply the live gate'
assert_contains "$ROOT_DIR/AGENTS.md" 'canonical `obvault` knowledge base'
assert_contains "$ROOT_DIR/CLAUDE.md" 'consult `~/work/obvault`'
assert_contains "$ROOT_DIR/CLAUDE.md" 'Architecture Decision Records'
assert_contains "$ROOT_DIR/CLAUDE.md" 'docs/adr/'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'activate the Etabli workflow automatically'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'live final gate'
assert_contains "$ROOT_DIR/pi/AGENTS.md" '~/work/obvault'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" '~/work/obvault'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'proactively consult `~/work/obvault`'
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
assert_contains "$ROOT_DIR/docs/answer-quality-traces/README.md" 'Historical fields'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow-monitor'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow-retrospect'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Golden principles'
assert_contains "$ROOT_DIR/workflow/spec.md" 'maps, not manuals'
assert_contains "$ROOT_DIR/workflow/skills/ship.md" 'checkpoint commit'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Understand before planning'
assert_contains "$ROOT_DIR/workflow/skills/adversary.md" 'Code diff mode'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/skills/self-improvement-loop.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/skills/product-dogfood.md'
assert_file "$ROOT_DIR/workflow/skill-design.md"
assert_contains "$ROOT_DIR/workflow/skill-design.md" 'Delete-test'

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
assert_file "$ROOT_DIR/workflow/agent-quick-card.md"
assert_file "$ROOT_DIR/workflow/contract-details.md"
assert_max_lines "$ROOT_DIR/workflow/agent-quick-card.md" 120
assert_contains "$ROOT_DIR/AGENTS.md" 'workflow/agent-quick-card.md'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'workflow/agent-quick-card.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/contract-details.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'planMutationGuardDecision'
assert_contains "$ROOT_DIR/docs/mcp-strategy.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/docs/mcp-strategy.md" 'https://mcp.linear.app/mcp'
# Behavioral coverage lives in dedicated smokes (plan-check-freeze, no-progress,
# workflow-event, dual-runtime). Docs smoke keeps map structure + anti-drift only.
assert_contains "$ROOT_DIR/workflow/spec.md" 'No-progress stop'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Check-freeze'
test -x "$ROOT_DIR/scripts/plan-check-freeze" || { printf 'missing plan-check-freeze helper\n' >&2; exit 1; }
assert_file "$ROOT_DIR/workflow/events.md"
assert_file "$ROOT_DIR/scripts/workflow-event"
assert_contains "$ROOT_DIR/scripts/workflow-event" 'harness_validation_completed'
assert_contains "$ROOT_DIR/scripts/workflow-retrospect" 'harness_failure_pattern'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" '## Product Dogfood'
assert_contains "$ROOT_DIR/workflow/skills/product-dogfood.md" 'Do not convert a blocked scenario into `pass`.'
assert_contains "$ROOT_DIR/workflow/skills/self-improvement-loop.md" 'never applies patches'
assert_contains "$ROOT_DIR/workflow/skills/self-improvement-loop.md" 'strict held-in gain'
assert_contains "$ROOT_DIR/workflow/skills/ambitious-project-loop.md" 'Push, PR, merge, deploy'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'fresh context (subagent reviewer or cross-model)'
assert_contains "$ROOT_DIR/workflow/spec.md" 'The workflow is ambient'
assert_contains "$ROOT_DIR/workflow/spec.md" 'claude/settings.workflow-hooks.json'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Prompt wording such as "PLAN.md ready" is routing context, not proof'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/events.md'
assert_contains "$ROOT_DIR/workflow/events.md" 'schema_version:2'
assert_contains "$ROOT_DIR/workflow/events.md" 'never counts as a successful outcome'
assert_contains "$ROOT_DIR/scripts/workflow-event" 'outcome_metric'
assert_file "$ROOT_DIR/scripts/workflow-telemetry-recover"
assert_file "$ROOT_DIR/scripts/workflow-efficiency-report"
assert_contains "$ROOT_DIR/workflow/spec.md" '## Human checkpoints'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/plan-archive.md'
assert_contains "$ROOT_DIR/docs/plan/README.md" 'It is a memory shelf, not an active planning workspace.'
assert_contains "$ROOT_DIR/workflow/plan-archive.md" 'Archive a plan if and only if it was implemented and validation ran.'
assert_contains "$ROOT_DIR/workflow/skills/adversary.md" 'Do not implement.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'wording such as "PLAN.md ready" is not proof.'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'Task* tools are Pi-only'
assert_not_contains "$ROOT_DIR/workflow/skills/orchestration.md" '## Codex Ambient Team Profile'
assert_not_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'spawn_agent'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'workflow/runtime-capabilities.json'
assert_contains "$ROOT_DIR/pi/extensions/lib/workflow-router-runtime.ts" 'workflow-router-core.mjs'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'SELF_IMPROVEMENT_PATTERN'
assert_contains "$ROOT_DIR/workflow/skills/ci-fix.md" 'Never make a test pass by disarming it'
assert_contains "$ROOT_DIR/workflow/skills/linear-work.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'One PR, one worktree, one loop.'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Never trust a clean review or green check'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Do not push.'
assert_contains "$ROOT_DIR/workflow/skills/pr-maintenance-loop.md" 'Do not merge.'
assert_file "$ROOT_DIR/scripts/pr-latest-head-status"
assert_file "$ROOT_DIR/tests/pr-latest-head-status-smoke.sh"
assert_contains "$ROOT_DIR/workflow/skills/sec-pr.md" 'Never merge automatically'
assert_contains "$ROOT_DIR/workflow/skills/multi-model-orchestration.md" 'System complexity alone also stays parent-only'
assert_not_contains "$ROOT_DIR/workflow/skills/multi-model-orchestration.md" 'Codex'
assert_not_contains "$ROOT_DIR/workflow/skills/multi-model-orchestration.md" 'spawn_agent'
assert_not_contains "$ROOT_DIR/workflow/skills/multi-model-orchestration.md" 'fork_turns'
assert_file "$ROOT_DIR/tests/multi-model-real-smoke.mjs"
assert_contains "$ROOT_DIR/workflow/events.md" 'Protocol v2 adds'
assert_contains "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" 'protocol_version'
assert_contains "$ROOT_DIR/pi/extensions/workflow-router.ts" 'Etabli adaptive council budget'
assert_contains "$ROOT_DIR/docs/agentic-workflow-hardening.md" 'ReAct paper'
assert_contains "$ROOT_DIR/docs/agentic-workflow-hardening.md" 'Retry with evidence'
assert_contains "$ROOT_DIR/docs/agentic-workflow-hardening.md" 'final status the active surface exposes'
assert_not_contains "$ROOT_DIR/docs/agentic-workflow-hardening.md" 'close status'
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
# Thin adapters must point at shared contracts (full matrix later). One path pin
# each is enough; full source-resolution path lists are adapter tests' job.
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Source resolution'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Do not create or update `docs/plan/` archives during planning.'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/pi/skills/adversary/SKILL.md" 'workflow/skills/adversary.md'
assert_contains "$ROOT_DIR/pi/skills/linear-work/SKILL.md" 'LINEAR_MCP_UNAVAILABLE'
assert_file "$ROOT_DIR/docs/pi-cheatsheet.md"
assert_file "$ROOT_DIR/docs/workflow-guide.md"
assert_contains "$ROOT_DIR/docs/workflow-guide.md" 'the spec wins'
assert_contains "$ROOT_DIR/docs/workflow-guide.md" 'Check-freeze'
assert_not_contains "$ROOT_DIR/docs/cross-project-research-grounding.md" 'control plane for Codex, Pi, Claude'
assert_contains "$ROOT_DIR/README.md" 'docs/workflow-guide.md'
assert_contains "$ROOT_DIR/claude/commands/plan-loop.md" 'Source resolution'
assert_contains "$ROOT_DIR/claude/commands/plan-implement.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/claude/commands/implement.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/claude/commands/adversary.md" 'workflow/skills/adversary.md'
assert_contains "$ROOT_DIR/claude/commands/linear-work.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/claude/commands/sec-pr.md" 'Never merge automatically'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'plan drift detected'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'Verdict: GO'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'Never use `OK`, `APPROVED`, `PASS`'
assert_not_contains "$ROOT_DIR/workflow/review-rubric.md" 'write exactly'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'Verdict: GO'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'Verdict: GO'
assert_not_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'claude/review-rubric.md'
assert_contains "$ROOT_DIR/pi/package.json" '@earendil-works/pi-coding-agent'
assert_not_contains "$ROOT_DIR/pi/package.json" '@mariozechner/pi-coding-agent'
assert_file "$ROOT_DIR/tests/workflow-cli-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh"
assert_contains "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh" 'RUN_REAL_AGENT_SCENARIOS'
assert_not_contains "$ROOT_DIR/scripts/profile-nvim.sh" '+lua dofile'
assert_not_contains "$ROOT_DIR/scripts/profile-nvim-runtime.sh" '+lua dofile'
assert_not_contains "$ROOT_DIR/claude/commands/plan-create.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/commands/plan-loop.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/commands/plan-implement.md" './claude/PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/claude/README.md" '~/.claude/workflow'
assert_contains "$ROOT_DIR/claude/README.md" '/verify-workflow'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'actual PLAN.md status is not proven READY'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'permissionDecision: "deny"'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'UserPromptSubmit'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'PreToolUse'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'PostToolUse'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'MultiEdit'
assert_contains "$ROOT_DIR/pi/agent/settings.json" 'npm:@tintinweb/pi-subagents'
assert_contains "$ROOT_DIR/pi/agent/settings.json" 'npm:@agwab/pi-workflow@0.8.1'
assert_contains "$INSTALL_MAIN" 'npm:@tintinweb/pi-subagents'
assert_contains "$ROOT_DIR/README.md" 'workflow/pi-workflow-adapter.md'
assert_contains "$ROOT_DIR/workflow/pi-workflow-adapter.md" 'This is an execution adapter, not a replacement workflow contract.'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'Run pi-workflow only when explicitly requested'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" 'maps, not manuals'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'workflow/plan-archive.md'

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
    "pi/skills/linear-project-setup/SKILL.md:workflow/skills/linear-project-setup.md" \
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

assert_file "$ROOT_DIR/workflow/project-autonomy-envelope.md"
assert_file "$ROOT_DIR/workflow/project-autonomy-envelope.schema.json"
assert_file "$ROOT_DIR/workflow/templates/project-autonomy-envelope.json"
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/project-autonomy-envelope.md'
assert_contains "$ROOT_DIR/workflow/project-autonomy-envelope.md" 'never launches agents'
assert_contains "$ROOT_DIR/workflow/project-autonomy-envelope.md" 'can auto-apply a patch'

printf 'workflow docs smoke test: ok\n'
