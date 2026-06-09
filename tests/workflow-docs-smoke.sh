#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

assert_file() {
    [ -f "$1" ] || {
        printf 'missing file: %s\n' "$1" >&2
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

assert_file "$ROOT_DIR/workflow/review-rubric.md"
assert_file "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_file "$ROOT_DIR/harness/templates/AGENTS.md"
assert_file "$ROOT_DIR/harness/templates/CLAUDE.md"
assert_file "$ROOT_DIR/harness/templates/docs/claude-code-harness.md"
assert_file "$ROOT_DIR/harness/templates/docs/project-context.md"
assert_file "$ROOT_DIR/scripts/deploy-harness"
assert_file "$ROOT_DIR/tests/harness-cli-smoke.sh"
assert_file "$ROOT_DIR/tests/fix-links-smoke.sh"
assert_file "$ROOT_DIR/tests/install-smoke.sh"
assert_file "$ROOT_DIR/tests/nvim-smoke.sh"
assert_file "$ROOT_DIR/scripts/profile-nvim.sh"
assert_file "$ROOT_DIR/scripts/profile-nvim-runtime.sh"
assert_file "$ROOT_DIR/docs/hunk-review-migration-feasibility.md"

assert_contains "$ROOT_DIR/scripts/install.sh" 'workflow/$shared_doc'
assert_contains "$ROOT_DIR/scripts/install.sh" 'PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Claude CLAUDE.md linked'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Claude skill'
assert_contains "$ROOT_DIR/scripts/install.sh" 'deploy-harness'
assert_contains "$ROOT_DIR/scripts/install.sh" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/scripts/install.sh" 'hunkdiff'
assert_contains "$ROOT_DIR/scripts/install.sh" 'install_npm_global_binary_link "hunk"'
assert_contains "$ROOT_DIR/scripts/install.sh" 'via asdf'
assert_contains "$ROOT_DIR/scripts/install.sh" 'asdf reshim nodejs'
assert_not_contains "$ROOT_DIR/scripts/install.sh" 'nvm-sh/nvm'
assert_not_contains "$ROOT_DIR/scripts/install.sh" '@mariozechner/pi-coding-agent'
assert_contains "$ROOT_DIR/README.md" 'deploy-harness'
assert_contains "$ROOT_DIR/README.md" 'tests/fix-links-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/install-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/nvim-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'RUN_AGENT_CLI_SMOKE=1'
assert_contains "$ROOT_DIR/README.md" 'RUN_AGENT_CLI_SMOKE_SELF_TEST=1'
assert_contains "$ROOT_DIR/README.md" 'RUN_CLAUDE_PRINT_SMOKE=1'
assert_contains "$ROOT_DIR/README.md" 'claude --version'
assert_contains "$ROOT_DIR/README.md" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/README.md" 'hunkdiff'
assert_contains "$ROOT_DIR/README.md" 'hunk diff --watch'
assert_contains "$ROOT_DIR/README.md" 'docs/hunk-review-migration-feasibility.md'
assert_contains "$ROOT_DIR/README.md" 'does not install `nvm`'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'Observed Facts'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" 'Handoff State'
assert_contains "$ROOT_DIR/workflow/spec.md" 'facts separate from assumptions'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'then still include the final verdict'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'bounded read-only'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" '`severity:`'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'line_range:'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'multiple changed lines'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" '`suggested_fix:`'
assert_contains "$ROOT_DIR/workflow/review-rubric.md" 'without code fences or tables'
assert_not_contains "$ROOT_DIR/workflow/review-rubric.md" 'write exactly'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'then still include the final verdict'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'bounded read-only'
assert_contains "$ROOT_DIR/claude/commands/review.md" '`severity:`, `file:`, `line:`'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'line_range:'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'multiple changed lines'
assert_contains "$ROOT_DIR/claude/commands/review.md" '`suggested_fix:`'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'without code fences or tables'
assert_not_contains "$ROOT_DIR/claude/commands/review.md" 'write exactly'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'workflow/review-rubric.md'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'then still include the final verdict'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'bounded read-only'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" '`severity:`, `file:`, `line:`'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'line_range:'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'multiple changed lines'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" '`suggested_fix:`'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'without code fences or tables'
assert_not_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'write exactly'
assert_not_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'claude/review-rubric.md'
assert_contains "$ROOT_DIR/pi/package.json" '@earendil-works/pi-coding-agent'
assert_not_contains "$ROOT_DIR/pi/package.json" '@mariozechner/pi-coding-agent'
assert_contains "$ROOT_DIR/pi/extensions/filter-output.ts" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/pi/extensions/rtk.ts" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/tests/harness-cli-smoke.sh" 'RUN_CLAUDE_PRINT_SMOKE'
assert_contains "$ROOT_DIR/tests/harness-cli-smoke.sh" 'RUN_AGENT_CLI_SMOKE_SELF_TEST'
assert_contains "$ROOT_DIR/tests/harness-cli-smoke.sh" 'exec @ARGV or die'
assert_contains "$ROOT_DIR/tests/harness-cli-smoke.sh" 'commands exceed their timeout'
assert_contains "$ROOT_DIR/tests/harness-cli-smoke.sh" 'Claude Code binary smoke'
assert_contains "$ROOT_DIR/tests/harness-cli-smoke.sh" '--version'
assert_contains "$ROOT_DIR/tests/harness-cli-smoke.sh" 'ASDF_DATA_DIR'
assert_contains "$ROOT_DIR/scripts/profile-nvim.sh" 'pcall(dofile'
assert_contains "$ROOT_DIR/scripts/profile-nvim-runtime.sh" 'pcall(dofile'
assert_not_contains "$ROOT_DIR/scripts/profile-nvim.sh" '+lua dofile'
assert_not_contains "$ROOT_DIR/scripts/profile-nvim-runtime.sh" '+lua dofile'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'sanitized bracketed terminal paste input'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'instead of using Claude `-p` / `--print`'
assert_not_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'Single-line prompts can be passed'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'tests/nvim-smoke.sh'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'XDG_STATE_HOME'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" ':ReviewHunk'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" ':ReviewClaudeReview [all|changed-only]'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" ':ReviewLegacyAnnotate'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'opens Hunk and asks you to rerun the annotation'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'Provider prompts are dispatched only after an active Hunk session exists'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'reloads it before dispatching the interactive provider prompt'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'The default Hunk flow does not parse agent stdout'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'Legacy agent ingest is available only when'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'Legacy suggested changes from imported'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'loaded on demand by explicit persistence or legacy fallback paths'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'https://www.hunk.dev/'
assert_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'docs/hunk-review-migration-feasibility.md'
assert_not_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" ':ReviewClaudeReview [status|all|changed-only]'
assert_not_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" ':ReviewPiReview [status|all|changed-only]'
assert_not_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'Import agent review output back into local review state with'
assert_contains "$ROOT_DIR/docs/hunk-review-migration-feasibility.md" 'Current decision: **do not delete the existing local review state yet**.'
assert_contains "$ROOT_DIR/docs/hunk-review-migration-feasibility.md" 'Notes did **not** survive closing Hunk and opening a new Hunk session'
assert_contains "$ROOT_DIR/docs/hunk-review-migration-feasibility.md" 'Hunk UI plus thin Etabli persistence adapter'
assert_not_contains "$ROOT_DIR/docs/nvim-diff-review-workflow.md" 'dofile('\''$PWD/scripts/review_smoke.lua'\'')'
assert_not_contains "$ROOT_DIR/claude/commands/plan-create.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/commands/plan-loop.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/commands/plan-implement.md" './claude/PLAN_TEMPLATE.md'

if [ -f "$ROOT_DIR/claude/PLAN_TEMPLATE.md" ] || [ -f "$ROOT_DIR/pi/PLAN_TEMPLATE.md" ]; then
    printf 'PLAN_TEMPLATE.md must stay canonical at repo root only\n' >&2
    exit 1
fi

if [ -f "$ROOT_DIR/claude/review-rubric.md" ]; then
    printf 'Claude workflow doc pointers must not be reintroduced\n' >&2
    exit 1
fi

printf 'workflow docs smoke test: ok\n'
