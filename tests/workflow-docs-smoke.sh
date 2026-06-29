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
assert_file "$ROOT_DIR/workflow/memory.md"
assert_file "$ROOT_DIR/workflow/plan-archive.md"
assert_file "$ROOT_DIR/workflow/linear-ticket-template.md"
assert_file "$ROOT_DIR/PLAN_TEMPLATE.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/CLAUDE.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md"
assert_file "$ROOT_DIR/workflow-scaffold/templates/docs/project-context.md"
assert_file "$ROOT_DIR/scripts/deploy-workflow"
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
assert_file "$ROOT_DIR/tests/workflow-cli-smoke.sh"
assert_file "$ROOT_DIR/tests/fix-links-smoke.sh"
assert_file "$ROOT_DIR/tests/install-smoke.sh"
assert_file "$ROOT_DIR/tests/nvim-smoke.sh"
assert_file "$ROOT_DIR/scripts/profile-nvim.sh"
assert_file "$ROOT_DIR/scripts/profile-nvim-runtime.sh"

assert_contains "$ROOT_DIR/scripts/install.sh" 'workflow/$shared_doc'
assert_contains "$ROOT_DIR/scripts/install.sh" 'PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Pi workflow sources linked'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Pi $template_file linked'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Claude CLAUDE.md linked'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Claude workflow sources linked'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Claude $template_file linked'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Claude skill'
assert_contains "$ROOT_DIR/scripts/install.sh" 'Claude workflow hook'
assert_contains "$ROOT_DIR/scripts/install.sh" 'settings.workflow-hooks.json'
assert_contains "$ROOT_DIR/scripts/install.sh" 'deploy-workflow'
assert_contains "$ROOT_DIR/scripts/install.sh" '@earendil-works/pi-coding-agent'
assert_contains "$ROOT_DIR/scripts/install.sh" 'hunkdiff'
assert_contains "$ROOT_DIR/scripts/install.sh" 'install_npm_global_binary_link "hunk"'
assert_contains "$ROOT_DIR/scripts/install.sh" 'via asdf'
assert_contains "$ROOT_DIR/scripts/install.sh" 'asdf reshim nodejs'
assert_not_contains "$ROOT_DIR/scripts/install.sh" 'nvm-sh/nvm'
assert_not_contains "$ROOT_DIR/scripts/install.sh" '@mariozechner/pi-coding-agent'
assert_contains "$ROOT_DIR/README.md" 'deploy-workflow'
assert_contains "$ROOT_DIR/README.md" 'scaffold-project'
assert_contains "$ROOT_DIR/README.md" 'tests/fix-links-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/install-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/nvim-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'tests/claude-hooks-smoke.sh'
assert_contains "$ROOT_DIR/README.md" 'RUN_AGENT_CLI_SMOKE=1'
assert_contains "$ROOT_DIR/README.md" 'RUN_AGENT_CLI_SMOKE_SELF_TEST=1'
assert_contains "$ROOT_DIR/README.md" 'RUN_CLAUDE_PRINT_SMOKE=1'
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
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'Observed Facts'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'Decision Log'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" 'Handoff State'
assert_contains "$ROOT_DIR/workflow/ticket-template.md" '## Start here'
assert_contains "$ROOT_DIR/workflow/ticket-template.md" '## Stop conditions'
assert_contains "$ROOT_DIR/workflow/ticket-template.md" 'Keep project-specific scope'
assert_contains "$ROOT_DIR/codex/workflow/ticket-template.md" '## Start here'
assert_contains "$ROOT_DIR/codex/workflow/ticket-template.md" '## Stop conditions'
assert_contains "$ROOT_DIR/codex/workflow/ticket-template.md" 'Keep project-specific scope'
assert_contains "$ROOT_DIR/workflow/spec.md" 'facts separate from assumptions'
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
assert_contains "$ROOT_DIR/workflow/spec.md" 'Agent memory: `docs/agent-memory/`'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/plan-archive.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Implemented plan archives: `docs/plan/`'
assert_contains "$ROOT_DIR/workflow/plan-archive.md" 'Archive a plan if and only if it was implemented and validation ran.'
assert_contains "$ROOT_DIR/workflow/linear-ticket-template.md" 'Resolve team/project/labels through Linear MCP'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/plan.md" 'Each archive is a distilled memory record, not a raw copy of `PLAN.md`.'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/AGENTS.md" 'workflow/linear-ticket-template.md'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Do not create or update `docs/plan/` archives during planning.'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Source resolution'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" '../../PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" '../../../PLAN_TEMPLATE.md'
assert_contains "$ROOT_DIR/pi/skills/plan-loop/SKILL.md" 'Do not tell the user the template/spec is missing.'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" '../../workflow/plan-archive.md'
assert_contains "$ROOT_DIR/pi/skills/plan-implement/SKILL.md" '../../../workflow/plan-archive.md'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" '../../workflow/spec.md'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" '../../../workflow/spec.md'
assert_contains "$ROOT_DIR/pi/skills/bug-check/SKILL.md" 'Adversarial Analysis'
assert_contains "$ROOT_DIR/pi/skills/linear-ticket-create/SKILL.md" 'Use Linear MCP as the Linear integration'
assert_contains "$ROOT_DIR/pi/skills/linear-work/SKILL.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/pi/skills/pr-review/SKILL.md" 'Use `gh`'
assert_contains "$ROOT_DIR/pi/skills/pr-qa/SKILL.md" 'Generate a test plan'
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
assert_contains "$ROOT_DIR/claude/commands/implement.md" '../workflow/spec.md'
assert_contains "$ROOT_DIR/claude/commands/implement.md" '../../workflow/spec.md'
assert_contains "$ROOT_DIR/claude/commands/verify-workflow.md" 'workflow/verification-report-template.md'
assert_contains "$ROOT_DIR/claude/commands/verify-workflow.md" 'Claude Code ships a native `/verify`'
assert_contains "$ROOT_DIR/claude/commands/bug-check.md" 'Linear MCP'
assert_contains "$ROOT_DIR/claude/commands/linear-ticket-create.md" 'Use Linear MCP as the Linear integration'
assert_contains "$ROOT_DIR/claude/commands/linear-work.md" 'LINEAR_MCP_UNAVAILABLE'
assert_contains "$ROOT_DIR/claude/commands/pr-review.md" 'Use `gh`'
assert_contains "$ROOT_DIR/claude/commands/pr-qa.md" 'QA Plan'
assert_contains "$ROOT_DIR/claude/commands/sec-pr.md" 'Never merge automatically'
assert_contains "$ROOT_DIR/claude/commands/ci-fix.md" 'Never disarm tests'
assert_contains "$ROOT_DIR/claude/commands/github-pr-review.md" 'compatibility alias'
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" 'archive the final plan in `docs/plan/YYYYMMDD-short-slug.md`'
assert_contains "$ROOT_DIR/claude/commands/implement.md" 'archive the final plan in `docs/plan/YYYYMMDD-short-slug.md`'
assert_contains "$ROOT_DIR/claude/commands/implement.md" 'delete only the current workspace root `PLAN.md`'
assert_contains "$ROOT_DIR/claude/commands/plan-implement.md" 'plan drift detected'
assert_contains "$ROOT_DIR/claude/commands/plan-loop.md" 'Workflow Contract'
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
assert_contains "$ROOT_DIR/claude/commands/review.md" 'do not wrap it in severity/file fields'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'End with a final line in this exact shape'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'Verdict: GO'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'Never use `OK`, `APPROVED`, `PASS`'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'bounded read-only'
assert_contains "$ROOT_DIR/claude/commands/review.md" '`severity:`, `file:`, `line:`'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'line_range:'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'multiple changed lines'
assert_contains "$ROOT_DIR/claude/commands/review.md" '`suggested_fix:`'
assert_contains "$ROOT_DIR/claude/commands/review.md" 'without code fences or tables'
assert_not_contains "$ROOT_DIR/claude/commands/review.md" 'write exactly'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'workflow/review-rubric.md'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'do not wrap it in severity/file fields'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'End with a final line in this exact shape'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'Verdict: GO'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'Never use `OK`, `APPROVED`, `PASS`'
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
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'RUN_CLAUDE_PRINT_SMOKE'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'RUN_AGENT_CLI_SMOKE_SELF_TEST'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'exec @ARGV or die'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'commands exceed their timeout'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'Claude Code binary smoke'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" '--version'
assert_contains "$ROOT_DIR/tests/workflow-cli-smoke.sh" 'ASDF_DATA_DIR'
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
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'bug-check'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'linear-ticket-create'
assert_contains "$ROOT_DIR/pi/extensions/lib/workflow-router-runtime.ts" 'pr-review'
assert_contains "$ROOT_DIR/pi/extensions/lib/workflow-router-runtime.ts" 'ci-fix'
assert_contains "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" 'permissionDecision: "deny"'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'UserPromptSubmit'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'PreToolUse'
assert_contains "$ROOT_DIR/claude/settings.workflow-hooks.json" 'MultiEdit'
assert_contains "$ROOT_DIR/pi/agent/settings.json" 'npm:@tintinweb/pi-tasks'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'workflow/plan-archive.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/agent-workflow.md" 'docs/agent-memory/README.md'
assert_contains "$ROOT_DIR/workflow-scaffold/templates/docs/claude-code-workflow.md" 'Use Claude Code `/goal`'

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

readme_claude_commands="$(
    awk '
        /^Claude:$/ { in_claude = 1; next }
        in_claude && /^```text$/ { in_block = 1; next }
        in_block && /^```$/ { exit }
        in_block && /^\// { print }
    ' "$ROOT_DIR/README.md"
)"

if [ "$workflow_claude_commands" != "$readme_claude_commands" ]; then
    printf 'Claude command lists differ between workflow/spec.md and README.md\n' >&2
    printf 'workflow/spec.md:\n%s\n' "$workflow_claude_commands" >&2
    printf 'README.md:\n%s\n' "$readme_claude_commands" >&2
    exit 1
fi

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

printf 'workflow docs smoke test: ok\n'
