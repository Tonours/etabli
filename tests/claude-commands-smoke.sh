#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

ruby - "$ROOT_DIR" <<'RUBY'
require "yaml"

root = ARGV.fetch(0)
paths = Dir.glob(File.join(root, "claude/commands/*.md")).sort
raise "no Claude commands found" if paths.empty?

allowed_keys = %w[name description argument-hint allowed-tools model disable-model-invocation]
allowed_tools = %w[Read Write Edit Glob Grep Bash AskUserQuestion Agent Skill WebFetch]
delegating_commands = %w[ci-fix cross-repo-audit implement plan-implement ship spec-verify]
read_only_commands = %w[bug-check cross-repo-audit github-pr-review pr-qa pr-review recap review sec-pr spec-verify verify-workflow]

paths.each do |path|
  content = File.read(path)
  match = content.match(/\A---\n(.*?)\n---\n/m)
  raise "#{path}: missing YAML frontmatter. Remediation: declare description and an explicit current-tool allowlist." unless match

  begin
    metadata = YAML.safe_load(match[1], aliases: false) || {}
  rescue Psych::SyntaxError => error
    raise "#{path}: invalid YAML frontmatter (#{error.problem}). Remediation: quote descriptions or hints containing ':' and nested punctuation."
  end
  unexpected = metadata.keys - allowed_keys
  raise "#{path}: unsupported frontmatter keys: #{unexpected.join(", ")}." unless unexpected.empty?

  description = metadata["description"].to_s.strip
  raise "#{path}: description is required." if description.empty?

  tools = metadata["allowed-tools"]
  raise "#{path}: allowed-tools must be an explicit non-empty array." unless tools.is_a?(Array) && !tools.empty?
  tool_names = tools.map(&:to_s)
  unknown_tools = tool_names - allowed_tools
  unless unknown_tools.empty?
    raise "#{path}: obsolete or unsupported tools: #{unknown_tools.join(", ")}. Remediation: use current Claude Code tool names (Agent, Edit) only."
  end

  command = File.basename(path, ".md")
  if delegating_commands.include?(command) && !tool_names.include?("Agent")
    raise "#{path}: command delegates work but does not allow Agent. Remediation: add Agent to allowed-tools."
  end
  if read_only_commands.include?(command) && !(tool_names & %w[Write Edit]).empty?
    raise "#{path}: read-only command exposes mutation tools."
  end

  body = content[match[0].length..] || ""
  if body.match?(/\bTask tool\b/) || body.match?(/\(Task tool\)/)
    raise "#{path}: stale Task-tool instruction. Remediation: use the current Agent tool name."
  end
  if body.lines.count > 140
    raise "#{path}: command body is #{body.lines.count} lines; limit is 140. Remediation: keep adapters thin and move reference detail to workflow/."
  end
end

commit_path = File.join(root, "claude/commands/commit.md")
commit_body = File.read(commit_path)
unless commit_body.match?(/do not push/i)
  raise "#{commit_path}: /commit must explicitly forbid push by default."
end
if commit_body.include?("gh pr create") || commit_body.match?(/force-with-lease|soft-reset|git reset/i)
  raise "#{commit_path}: /commit must not create PRs or rewrite history. Remediation: keep external write/history operations in separately authorized commands."
end

plan_implement = File.read(File.join(root, "claude/commands/plan-implement.md"))
unless plan_implement.include?("scout") && plan_implement.include?("worker") && plan_implement.include?("reviewer")
  raise "plan-implement must retain the bounded scout/worker/reviewer orchestration references."
end
RUBY

printf 'claude commands smoke test: ok\n'
