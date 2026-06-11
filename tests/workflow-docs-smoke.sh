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
assert_contains "$ROOT_DIR/README.md" 'hunk diff --watch --mode auto --theme custom --no-wrap --line-numbers --agent-notes --no-transparent-bg'
assert_contains "$ROOT_DIR/README.md" 'does not install `nvm`'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" 'Observed Facts'
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" 'Handoff State'
assert_contains "$ROOT_DIR/workflow/spec.md" 'facts separate from assumptions'
assert_contains "$ROOT_DIR/workflow/spec.md" 'workflow/memory.md'
assert_contains "$ROOT_DIR/workflow/spec.md" 'Agent memory: `docs/agent-memory/`'
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
assert_not_contains "$ROOT_DIR/claude/commands/plan-create.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/commands/plan-loop.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/commands/plan-implement.md" './claude/PLAN_TEMPLATE.md'
assert_not_contains "$ROOT_DIR/claude/README.md" '~/.claude/skills'

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
