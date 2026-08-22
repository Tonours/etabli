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

assert_contains_wrapped() {
    local path="$1"
    local needle="$2"

    tr '\n' ' ' <"$path" | tr -s ' ' | grep -Fq -- "$needle" || {
        printf 'expected %s (allowing line wraps) in %s\n' "$needle" "$path" >&2
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

assert_not_word() {
    local path="$1"
    local word="$2"

    if grep -Eq -- "(^|[^[:alnum:]_-])${word}([^[:alnum:]_-]|$)" "$path"; then
        printf 'did not expect word %s in %s\n' "$word" "$path" >&2
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
assert_dir "$ROOT_DIR/docs/adr"
assert_file "$ROOT_DIR/CLAUDE.md"
assert_file "$ROOT_DIR/scripts/validate-adrs"
assert_file "$ROOT_DIR/claude/scopes/shared/skills/adr/scripts/apply-adr.mjs"
assert_file "$ROOT_DIR/claude/scopes/shared/skills/adr/scripts/adr-validation.mjs"
assert_file "$ROOT_DIR/workflow/skills/adversary.md"
assert_file "$ROOT_DIR/workflow/skills/implementation-loop.md"
assert_file "$ROOT_DIR/workflow/skills/orchestration.md"
assert_file "$ROOT_DIR/workflow/skills/product-dogfood.md"
assert_file "$ROOT_DIR/workflow/skills/investigation.md"
assert_file "$ROOT_DIR/workflow/evidence-pack.schema.json"
assert_file "$ROOT_DIR/workflow/templates/evidence-pack.json"
assert_file "$ROOT_DIR/workflow/templates/benchmark-declaration.json"
assert_file "$ROOT_DIR/workflow/program.schema.json"
assert_file "$ROOT_DIR/workflow/templates/program.json"
assert_file "$ROOT_DIR/workflow/skills/program-orchestration.md"
assert_file "$ROOT_DIR/scripts/evidence-proof"
assert_file "$ROOT_DIR/scripts/program-state"
assert_file "$ROOT_DIR/tests/evidence-proof-smoke.sh"
assert_file "$ROOT_DIR/tests/program-state-smoke.sh"
assert_file "$ROOT_DIR/workflow/skills/self-improvement-loop.md"
assert_file "$ROOT_DIR/workflow/skills/ambitious-project-loop.md"
assert_file "$ROOT_DIR/workflow/skills/recurring-run.md"
assert_file "$ROOT_DIR/workflow/skills/skill-evaluation.md"
assert_file "$ROOT_DIR/scripts/conversation-retrospect"
assert_file "$ROOT_DIR/scripts/skill-eval"
assert_file "$ROOT_DIR/scripts/runtime-skill-canary"
assert_file "$ROOT_DIR/scripts/session-handoff"
assert_file "$ROOT_DIR/tests/conversation-retrospect-smoke.sh"
assert_file "$ROOT_DIR/tests/skill-eval-smoke.sh"
assert_file "$ROOT_DIR/tests/runtime-skill-canary-smoke.sh"
assert_file "$ROOT_DIR/tests/session-handoff-smoke.sh"
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
assert_file "$ROOT_DIR/claude/scopes/shared/commands/verify-workflow.md"
assert_file "$ROOT_DIR/claude/scopes/shared/commands/bug-check.md"
assert_file "$ROOT_DIR/claude/scopes/shared/commands/linear-ticket-create.md"
assert_file "$ROOT_DIR/claude/scopes/shared/commands/linear-work.md"
assert_file "$ROOT_DIR/claude/scopes/shared/commands/pr-review.md"
assert_file "$ROOT_DIR/claude/scopes/shared/commands/pr-qa.md"
assert_file "$ROOT_DIR/claude/scopes/shared/commands/sec-pr.md"
assert_file "$ROOT_DIR/claude/scopes/shared/commands/ci-fix.md"
assert_file "$ROOT_DIR/claude/scopes/shared/commands/github-pr-review.md"
assert_file "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
assert_file "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs"
assert_file "$ROOT_DIR/claude/settings.workflow-hooks.json"
assert_file "$ROOT_DIR/tests/claude-hooks-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-autonomous-plan-loop-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-cli-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-retrospect-smoke.sh"
assert_file "$ROOT_DIR/tests/router-eval-smoke.sh"
assert_file "$ROOT_DIR/tests/research-proof-check-smoke.sh"
assert_file "$ROOT_DIR/scripts/workflow-retrospect"
assert_file "$ROOT_DIR/scripts/workflow-measurement-integrity"
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
assert_contains "$ROOT_DIR/scripts/deploy-agent-workflow" 'Pi, Codex, and Grok (through the shared ~/.agents surface)'
assert_contains "$ROOT_DIR/scripts/deploy-agent-workflow" 'npm:@tintinweb/pi-subagents'
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
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/evidence-proof'
assert_contains "$ROOT_DIR/workflow/spec.md" 'scripts/program-state'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'workflow/skills/program-orchestration.md'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'scripts/evidence-proof'
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
assert_contains "$ROOT_DIR/README.md" 'RUN_SKILL_RUNTIME_CANARY=1'
assert_contains "$ROOT_DIR/README.md" 'scripts/conversation-retrospect'
assert_contains "$ROOT_DIR/README.md" 'scripts/skill-eval'
assert_contains "$ROOT_DIR/README.md" 'scripts/runtime-skill-canary'
assert_contains "$ROOT_DIR/README.md" 'scripts/session-handoff'
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
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'Shared identity, style, cognition, code,'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'route classification is library-only (ADR-0014)'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'workflow/answer-quality.md'
assert_contains "$ROOT_DIR/claude/CLAUDE.md" 'live final gate'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'Observed Facts'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'Decision Log'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" 'Handoff State'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'model-token totals are telemetry, never a stop condition'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" 'model-token totals are telemetry, never a stop condition'
assert_not_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'tokens or tools'
assert_not_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" 'token-tool budget'
assert_contains_wrapped "$ROOT_DIR/workflow/spec.md" 'Global model-token totals are telemetry, never plan/goal stop conditions'
assert_contains_wrapped "$ROOT_DIR/workflow/spec.md" 'Bounded payload contracts and explicit billing authorization remain separate.'
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
assert_contains_wrapped "$ROOT_DIR/workflow/agent-quick-card.md" 'do not write `PLAN.md`, run adversary, or archive'
assert_contains "$ROOT_DIR/workflow/agent-quick-card.md" 'Freeze one documented metric command'
assert_contains_wrapped "$ROOT_DIR/workflow/agent-quick-card.md" 'user-named paths even when blinding authors'
assert_contains_wrapped "$ROOT_DIR/workflow/agent-quick-card.md" 'After two red serve/coverage attempts'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'Diagnosis: question, artifact filename'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'Compare: both artifact names'
assert_contains_wrapped "$ROOT_DIR/workflow/answer-quality.md" 'even when blinding authors'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'Hillclimb: frozen command'
assert_contains_wrapped "$ROOT_DIR/workflow/answer-quality.md" 'being killed is not a progression'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'Implementation: files, checks'
assert_contains "$ROOT_DIR/workflow/answer-quality.md" 'never a single-run p95'
assert_contains "$ROOT_DIR/workflow/skills/investigation.md" 'cite `file:line`'
assert_contains "$ROOT_DIR/workflow/skills/investigation.md" 'Ceiling is `CAUSE_SUPPORTED`'
assert_contains "$ROOT_DIR/workflow/skills/investigation.md" 'Do not apply the capture-only'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Freeze one metric command'
assert_contains_wrapped "$ROOT_DIR/workflow/skills/implementation-loop.md" 'at least three measured values in the final answer'
assert_contains_wrapped "$ROOT_DIR/workflow/skills/implementation-loop.md" 'stop before an external cap'
assert_contains_wrapped "$ROOT_DIR/workflow/skills/implementation-loop.md" 'not an experimental coverage runner over a live HTTP'
assert_contains_wrapped "$ROOT_DIR/workflow/skills/implementation-loop.md" 'After two red serve-or-coverage attempts'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'isStandaloneVerifyRequest'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'IMPLEMENT_NEGATION_PATTERN'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'PREPARE_FOR_REVIEW_PATTERN'
assert_contains "$ROOT_DIR/tests/router-evals/core.json" 'organic-'
assert_contains "$ROOT_DIR/AGENTS.md" 'workflow/agent-quick-card.md'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'workflow/agent-quick-card.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/contract-details.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'planMutationGuardDecision'
assert_contains_wrapped "$ROOT_DIR/workflow/git-contract.md" 'Both conditions are required in the same current user request:'
assert_contains "$ROOT_DIR/workflow/git-contract.md" 'The branch is the write target'
assert_contains "$ROOT_DIR/workflow/git-contract.md" 'The user writes the exact requested operation: `commit`, `merge`, or `push`.'
assert_contains_wrapped "$ROOT_DIR/workflow/git-contract.md" 'Synonyms such as “land”, “integrate”, or “ship it”, agent paraphrases, and consent carried from an earlier request do not count.'
assert_contains_wrapped "$ROOT_DIR/workflow/git-contract.md" 'A branch-less grant such as “commit and push”, without naming the default branch as the write target, does not authorize it.'
assert_contains_wrapped "$ROOT_DIR/workflow/git-contract.md" 'When the same request names the default write target and multiple exact operations, each operation is authorized separately.'
assert_contains "$ROOT_DIR/workflow/git-contract.md" 'Each operation requires its own authorization.'
assert_contains "$ROOT_DIR/workflow/git-contract.md" 'Final relevant checks must pass before the write.'
assert_contains_wrapped "$ROOT_DIR/workflow/git-contract.md" 'never overrides a stricter skill contract'
assert_contains "$ROOT_DIR/workflow/git-contract.md" 'History-rewriting operations keep their separate rules.'
assert_contains_wrapped "$ROOT_DIR/workflow/git-contract.md" "when the user's current request explicitly names a branch"
assert_contains "$ROOT_DIR/AGENTS.md" '<type>/<ticket-id>-<short-slug>'
assert_contains "$ROOT_DIR/pi/AGENTS.md" '<type>/<ticket-id>-<short-slug>'
assert_contains "$ROOT_DIR/workflow/skills/worktree-isolation.md" '<type>/<ticket-id>-<short-slug>'
assert_contains "$ROOT_DIR/workflow/skills/ship.md" '<type>/<ticket-id>-<short-slug>'
assert_contains_wrapped "$ROOT_DIR/workflow/skills/ship.md" 'Direct default-branch integration is outside `/ship`'
assert_contains "$ROOT_DIR/docs/mcp-strategy.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/docs/mcp-strategy.md" 'https://mcp.linear.app/mcp'
jq -e '
  .mcpServers == {
    "brain": {
      "command": "node",
      "args": ["${HOME}/work/brain/_meta/mcp/server.mjs"],
      "env": {"OBVAULT_ROOT": "${HOME}/work/brain"}
    }
  }
' "$ROOT_DIR/.mcp.json" >/dev/null
jq -e '
  .scope == "work" and
  .runtimeAssignments.claude == ["chrome-devtools", "lean-ctx", "brain"] and
  .runtimeAssignments.pi == ["lean-ctx", "brain"] and
  .runtimeAssignments.codex == ["chrome-devtools", "lean-ctx", "datadog", "linear", "brain"] and
  .runtimeAssignments.grok == [] and
  (.mcpServers | keys | sort) == ["brain", "chrome-devtools", "datadog", "lean-ctx", "linear"]
' "$ROOT_DIR/mcp/servers.template.json" >/dev/null
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
assert_contains_wrapped "$ROOT_DIR/workflow/skills/implementation-loop.md" 'fresh context (subagent reviewer or cross-model)'
assert_contains "$ROOT_DIR/workflow/spec.md" 'The workflow is ambient'
assert_contains "$ROOT_DIR/workflow/spec.md" 'claude/settings.workflow-hooks.json'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Prompt wording such as "PLAN.md ready" is routing context, not proof'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/events.md'
assert_contains "$ROOT_DIR/workflow/events.md" 'schema_version:2'
assert_contains "$ROOT_DIR/workflow/events.md" 'never counts as a successful outcome'
assert_contains "$ROOT_DIR/scripts/workflow-event" 'outcome_metric'
assert_contains "$ROOT_DIR/workflow/spec.md" '## Human checkpoints'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/plan-archive.md'
assert_contains "$ROOT_DIR/docs/plan/README.md" 'It is a memory shelf, not an active planning workspace.'
assert_contains "$ROOT_DIR/workflow/plan-archive.md" 'Archive a plan if and only if it was implemented and validation ran.'
assert_contains "$ROOT_DIR/workflow/skills/adversary.md" 'Do not implement.'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'wording such as "PLAN.md ready" is not proof.'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'Task* tools are Pi-only'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'One writer at any instant'
assert_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'foreground or wait for it'
assert_not_contains "$ROOT_DIR/workflow/skills/orchestration.md" 'Work is parent-only.'
assert_contains "$ROOT_DIR/pi/AGENTS.md" 'Current Pi profile: parent-only execution and mutation.'
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
assert_contains "$ROOT_DIR/workflow/events.md" 'Protocol v2 adds'
assert_contains "$ROOT_DIR/scripts/lib/workflow-event-detail.jq" 'protocol_version'
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
# Thin adapters must point at shared contracts (full matrix later). Do not pin
# duplicated Source resolution path lists here; those freeze adapter boilerplate.
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Do not create or update `docs/plan/` archives during planning.'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" 'simplify: clean'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" 'simplify: clean'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/implement.md" 'simplify: clean'
assert_contains "$ROOT_DIR/pi/skills/adversary/SKILL.md" 'workflow/skills/adversary.md'
assert_contains "$ROOT_DIR/pi/skills/linear-work/SKILL.md" 'LINEAR_MCP_UNAVAILABLE'
assert_file "$ROOT_DIR/docs/pi-cheatsheet.md"
assert_file "$ROOT_DIR/docs/workflow-guide.md"
assert_contains "$ROOT_DIR/docs/workflow-guide.md" 'the spec wins'
assert_contains "$ROOT_DIR/docs/workflow-guide.md" 'Check-freeze'
assert_not_contains "$ROOT_DIR/docs/cross-project-research-grounding.md" 'control plane for Codex, Pi, Claude'
assert_contains "$ROOT_DIR/README.md" 'docs/workflow-guide.md'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/plan-implement.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/plan-implement.md" 'implementation-loop 12c'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/implement.md" 'workflow/skills/implementation-loop.md'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" '12c'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" '12c'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Diagnosis, compare, or pre-existing-capture forensics'
assert_not_contains "$ROOT_DIR/workflow/contract-details.md" '/skill:github-pr-review'
assert_contains "$ROOT_DIR/herdr/skills/herdr/SKILL.md" 'only when the user names Herdr'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/adversary.md" 'workflow/skills/adversary.md'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/linear-work.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/sec-pr.md" 'Never merge automatically'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'plan drift detected'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'Does this addition need to exist'
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'simplify: clean'
assert_not_contains "$ROOT_DIR/claude/README.md" 'before the repos are opened'
assert_not_contains "$ROOT_DIR/claude/scopes/work/skills/sec-pr/references/forest-dependabot.md" 'Read-only sortant'
assert_contains_wrapped "$INSTALL_MAIN" 'for skill_name in "${CROSS_HARNESS_PI_SKILLS[@]}"; do [ -n "$skill_name" ] || continue'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'Verdict: GO'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'Never use `OK`, `APPROVED`, `PASS`'
assert_not_contains "$ROOT_DIR/workflow/review-rubric.md" 'write exactly'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'Dismissed: none'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" '## Intent'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'Logic hunter'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'Spec hunter'
assert_contains "$ROOT_DIR/workflow/skills/review.md" '--no-session'
assert_contains "$ROOT_DIR/workflow/skills/review.md" '--no-skills'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'HUNTER_TIMEOUT'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'claude-opus-5-thinking-high'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'spec: parent'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'isolation: none'
assert_contains "$ROOT_DIR/workflow/skills/review.md" '@<patchfile>'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'same runner and model'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'hunter_model:'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'HUNTER_TIMEOUT'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'spec: parent'
assert_file "$ROOT_DIR/workflow/templates/review-logic-hunter.md"
assert_file "$ROOT_DIR/workflow/templates/review-spec-hunter.md"
assert_file "$ROOT_DIR/workflow/templates/review-lead.md"
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/review.md" 'Agent'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/pr-review.md" 'Agent'
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/github-pr-review.md" 'Agent'
assert_not_contains "$ROOT_DIR/workflow/skills/review.md" 'No free second bug-hunt'
assert_not_contains "$ROOT_DIR/workflow/skills/pr-review.md" 'No free second bug-hunt'
assert_not_contains "$ROOT_DIR/workflow/agent-quick-card.md" 'Break-first then plan-fit'
if [ -f "$ROOT_DIR/claude/scopes/shared/agents/spec-reviewer.md" ]; then
    printf 'unexpected %s\nRemediation: keep reviewer scout worker only; dispatch two briefs on reviewer.\n' \
        "$ROOT_DIR/claude/scopes/shared/agents/spec-reviewer.md" >&2
    exit 1
fi
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/review.md" 'Verdict: GO'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'Verdict: GO'
assert_not_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'claude/review-rubric.md'

# Core quality/review paths must not require optional Pi suites that are absent
# from managed runtime surfaces. Every route keeps a local-source degraded mode,
# and Pi code-quality names only direct shared vendor leaves we can resolve.
for quality_path in \
    workflow/spec.md \
    workflow/review-rubric.md \
    workflow/skills/implementation-loop.md \
    workflow/skills/review.md \
    workflow/skills/pr-review.md \
    pi/skills/code-quality/SKILL.md \
    pi/skills/review/SKILL.md \
    claude/scopes/shared/commands/plan-implement.md \
    claude/scopes/shared/commands/ship.md \
    claude/scopes/shared/agents/scout.md \
    claude/scopes/shared/agents/reviewer.md \
    claude/scopes/shared/agents/worker.md \
    claude/README.md; do
    for inactive_skill in suite-router stack-suite design-suite; do
        assert_not_word "$ROOT_DIR/$quality_path" "$inactive_skill"
    done
done

# These CSS skills are distributed cross-harness but are not part of Pi's core
# package surface. Pi quality adapters must not route to them until the catalog
# marks them pi_core; Claude adapters may still name cross-harness skills.
inactive_pi_css_skills="$(
    awk -F '\t' '
        $0 !~ /^#/ && $2 == "pi" && $3 == "0" &&
        ($1 == "frontend-css-ui-ux" || $1 ~ /^css-/) { print $1 }
    ' "$ROOT_DIR/workflow/runtime/skill-surface.tsv"
)"
[ -n "$inactive_pi_css_skills" ] || {
    printf 'expected at least one non-core Pi CSS skill in the managed catalog\n' >&2
    exit 1
}
for pi_quality_path in \
    pi/skills/code-quality/SKILL.md \
    pi/skills/implement/SKILL.md \
    pi/skills/plan-implement/SKILL.md \
    pi/skills/pr-review/SKILL.md \
    pi/skills/review/SKILL.md; do
    while IFS= read -r inactive_pi_css_skill; do
        [ -n "$inactive_pi_css_skill" ] || continue
        assert_not_word "$ROOT_DIR/$pi_quality_path" "$inactive_pi_css_skill"
    done <<<"$inactive_pi_css_skills"
done
assert_contains "$ROOT_DIR/workflow/skills/implementation-loop.md" 'quality: unavailable'
assert_contains "$ROOT_DIR/workflow/skills/review.md" 'report the convention lens as `not run`'
assert_contains "$ROOT_DIR/pi/skills/code-quality/SKILL.md" 'quality: unavailable'
assert_contains "$ROOT_DIR/pi/skills/code-quality/SKILL.md" 'status: clean|findings|unavailable'
assert_not_contains "$ROOT_DIR/pi/skills/code-quality/SKILL.md" '| findings: N | clean'

# shellcheck source=../scripts/lib/skill-catalog.sh
source "$ROOT_DIR/scripts/lib/skill-catalog.sh"

catalog_schema_issues="$(
    awk -F '\t' '
        $0 !~ /^#/ && NF != 6 { print NR ": expected 6 fields, got " NF }
        $0 !~ /^#/ && NF == 6 && ($3 !~ /^[01]$/ || $4 !~ /^[01]$/ || $5 !~ /^[01]$/ || $6 !~ /^[01]$/) {
            print NR ": visibility and lock flags must be explicit 0 or 1"
        }
    ' "$ROOT_DIR/workflow/runtime/skill-surface.tsv"
)"
[ -z "$catalog_schema_issues" ] || {
    printf 'skill catalog schema drift:\n%s\nremediation: keep six explicit fields per record\n' "$catalog_schema_issues" >&2
    exit 1
}

catalog_counts="$(
    awk -F '\t' '
        $0 !~ /^#/ { total++; pi_core += ($3 == 1); agents_visible += ($4 == 1) }
        END { printf "%d %d %d", total, pi_core, agents_visible }
    ' "$ROOT_DIR/workflow/runtime/skill-surface.tsv"
)"
read -r catalog_total pi_core_total agents_visible_total <<<"$catalog_counts"
[ "$catalog_total" -le 95 ] || { printf 'skill catalog grew beyond baseline: %s > 95\n' "$catalog_total" >&2; exit 1; }
[ "$pi_core_total" -le 14 ] || { printf 'pi_core grew beyond baseline: %s > 14\n' "$pi_core_total" >&2; exit 1; }
[ "$agents_visible_total" -le 14 ] || { printf 'agents_visible grew beyond baseline: %s > 14\n' "$agents_visible_total" >&2; exit 1; }

duplicate_catalog_names="$(skill_catalog_names "$ROOT_DIR/workflow/runtime/skill-surface.tsv" | sort | uniq -d)"
[ -z "$duplicate_catalog_names" ] || {
    printf 'duplicate skill catalog names:\n%s\nremediation: keep one canonical catalog owner\n' "$duplicate_catalog_names" >&2
    exit 1
}

single_line_skill_description() {
    local skill_file="$1" label="$2" count description
    count="$(grep -Ec '^description:' "$skill_file")"
    [ "$count" -eq 1 ] || {
        printf 'prompt-visible skill must declare exactly one description: %s\n' "$label" >&2
        return 1
    }
    description="$(awk '/^description:[[:space:]]/{sub(/^description:[[:space:]]*/, ""); print; exit}' "$skill_file")"
    case "$description" in
        ""|\'*|\"*|\|*|\>*)
            printf 'prompt-visible skill uses an unmeasurable description scalar: %s\n' "$label" >&2
            return 1
            ;;
    esac
    if printf '%s\n' "$description" | grep -Eq '(^|[[:space:]])#|:[[:space:]]'; then
        printf 'prompt-visible skill description needs YAML decoding: %s\n' "$label" >&2
        return 1
    fi
    if awk '
        /^description:/ { after_description = 1; next }
        after_description && /^---[[:space:]]*$/ { exit }
        after_description && /^[^[:space:]]/ { exit }
        after_description && /^[[:space:]]/ { multiline = 1; exit }
        END { exit(multiline ? 0 : 1) }
    ' "$skill_file"; then
        printf 'prompt-visible skill uses a multiline description continuation: %s\n' "$label" >&2
        return 1
    fi
    printf '%s\n' "$description"
}

if single_line_skill_description "$ROOT_DIR/tests/fixtures/codex-skill-multiline-description.fixture.md" "multiline-fixture" >/dev/null 2>&1; then
    printf 'multiline quoted YAML descriptions must be rejected\n' >&2
    exit 1
fi

surface_descriptions() {
    local flag="$1" name skill_dir description
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        skill_dir="$(skill_catalog_dir "$ROOT_DIR/workflow/runtime/skill-surface.tsv" "$ROOT_DIR" "$name")"
        description="$(single_line_skill_description "$skill_dir/SKILL.md" "$name")" || return 1
        printf '%s\t%s\n' "$name" "$description"
    done < <(skill_catalog_names "$ROOT_DIR/workflow/runtime/skill-surface.tsv" pi "$flag")
}

for prompt_surface in pi_core agents_visible; do
    surface_rows="$(surface_descriptions "$prompt_surface")"
    duplicate_descriptions="$(printf '%s\n' "$surface_rows" | awk -F '\t' '{d=tolower($2); gsub(/[[:space:]]+/, " ", d); print d}' | sort | uniq -d)"
    [ -z "$duplicate_descriptions" ] || {
        printf 'duplicate normalized %s descriptions:\n%s\nremediation: consolidate overlapping entrypoints\n' "$prompt_surface" "$duplicate_descriptions" >&2
        exit 1
    }
    surface_bytes="$(printf '%s\n' "$surface_rows" | LC_ALL=C awk -F '\t' '{bytes += length($2)} END {print bytes + 0}')"
    case "$prompt_surface" in
        pi_core) max_bytes=767 ;;
        agents_visible) max_bytes=1020 ;;
    esac
    [ "$surface_bytes" -le "$max_bytes" ] || {
        printf '%s description bytes grew beyond baseline: %s > %s\n' "$prompt_surface" "$surface_bytes" "$max_bytes" >&2
        exit 1
    }
done

shared_vendor_skill_names="$(
    skill_catalog_vendor_records "$ROOT_DIR/workflow/runtime/skill-surface.tsv" "$ROOT_DIR" |
        awk -F '\t' '$1 == "shared" { print $2 }'
)"
direct_quality_skills="$(
    awk '
        /\| Domain \| Skills to apply \|/ { in_skill_table = 1; next }
        in_skill_table && /^[[:space:]]*\|/ {
            if ($0 ~ /\|[[:space:]-]+\|/) next
            line = $0
            while (match(line, /`[^`]+`/)) {
                print substr(line, RSTART + 1, RLENGTH - 2)
                line = substr(line, RSTART + RLENGTH)
            }
            next
        }
        in_skill_table { exit }
    ' "$ROOT_DIR/pi/skills/code-quality/SKILL.md"
)"
[ -n "$direct_quality_skills" ] || {
    printf 'code-quality Skills to apply table has no direct skill leaves\n' >&2
    exit 1
}
while IFS= read -r direct_quality_skill; do
    [ -n "$direct_quality_skill" ] || continue
    grep -Fxq "$direct_quality_skill" <<<"$shared_vendor_skill_names" || {
        printf 'unresolved direct code-quality skill: %s\n' "$direct_quality_skill" >&2
        exit 1
    }
done <<<"$direct_quality_skills"
assert_contains "$ROOT_DIR/pi/package.json" '@earendil-works/pi-coding-agent'
assert_not_contains "$ROOT_DIR/pi/package.json" '@mariozechner/pi-coding-agent'
assert_file "$ROOT_DIR/tests/workflow-cli-smoke.sh"
assert_file "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh"
assert_contains "$ROOT_DIR/tests/workflow-real-agent-scenarios.sh" 'RUN_REAL_AGENT_SCENARIOS'
assert_not_contains "$ROOT_DIR/scripts/profile-nvim.sh" '+lua dofile'
assert_not_contains "$ROOT_DIR/scripts/profile-nvim-runtime.sh" '+lua dofile'
assert_not_contains "$ROOT_DIR/claude/scopes/shared/commands/plan-loop.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/scopes/shared/commands/plan-implement.md" './claude/PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/claude/README.md" '~/.claude/workflow'
assert_contains "$ROOT_DIR/claude/README.md" '/verify-workflow'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'actual PLAN.md status is not proven READY'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'permissionDecision: "deny"'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'PreToolUse'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'PostToolUse'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'MultiEdit'
assert_not_contains "$ROOT_DIR/pi/agent/settings.json" 'npm:@tintinweb/pi-subagents'
assert_contains "$INSTALL_MAIN" 'npm:@tintinweb/pi-subagents'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" 'maps, not manuals'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'workflow/plan-archive.md'

command_file_for() {
    case "$1" in
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
    assert_file "$ROOT_DIR/claude/scopes/shared/commands/$command_file"
done <<< "$workflow_claude_commands"

while IFS= read -r command_path; do
    command_file="$(basename "$command_path")"
    case "$command_file" in
        *.md) command="/${command_file%.md}" ;;
        *)
            printf 'unexpected command file: %s\n' "$command_file" >&2
            exit 1
            ;;
    esac

    assert_contains "$ROOT_DIR/claude/README.md" "- \`$command\`"
done < <(find "$ROOT_DIR/claude/scopes/shared/commands" -maxdepth 1 -type f -name '*.md' | sort)

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
claude_plan_fallback="$(extract_plan_fallback "$ROOT_DIR/claude/scopes/shared/commands/plan-loop.md")"
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
    "claude/scopes/shared/commands/implement.md:workflow/skills/implementation-loop.md" \
    "claude/scopes/shared/commands/plan-implement.md:workflow/skills/implementation-loop.md" \
    "claude/scopes/shared/commands/adversary.md:workflow/skills/adversary.md" \
    "claude/scopes/shared/commands/bug-check.md:workflow/skills/bug-check.md" \
    "claude/scopes/shared/commands/ci-fix.md:workflow/skills/ci-fix.md" \
    "claude/scopes/shared/commands/linear-project-setup.md:workflow/skills/linear-project-setup.md" \
    "claude/scopes/shared/commands/linear-ticket-create.md:workflow/skills/linear-ticket-create.md" \
    "claude/scopes/shared/commands/linear-work.md:workflow/skills/linear-work.md" \
    "claude/scopes/shared/commands/pr-qa.md:workflow/skills/pr-qa.md" \
    "claude/scopes/shared/commands/pr-review.md:workflow/skills/pr-review.md" \
    "claude/scopes/shared/commands/review.md:workflow/skills/review.md" \
    "claude/scopes/shared/commands/sec-pr.md:workflow/skills/sec-pr.md"; do
    adapter_path="${adapter%%:*}"
    contract_ref="${adapter##*:}"
    assert_contains "$ROOT_DIR/$adapter_path" "$contract_ref"
done

duplicate_adapters="$(
    {
        find "$ROOT_DIR/pi/skills" -maxdepth 2 -type f -name 'SKILL.md'
        find "$ROOT_DIR/claude/scopes/shared/commands" -maxdepth 1 -type f -name '*.md'
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
