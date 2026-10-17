#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

ruby - "$ROOT_DIR" <<'RUBY'
require "yaml"

root = ARGV.fetch(0)
paths = Dir.glob(File.join(root, "skills/*/*/SKILL.md")).sort
raise "no first-party skills found under skills/<scope>/" if paths.empty?

allowed_keys = %w[
  name
  description
  disable-model-invocation
  argument-hint
  allowed-tools
  model
  version
  author
  license
]
allowed_tools = %w[Read Write Edit Glob Grep Bash AskUserQuestion Agent Skill WebFetch]
skills_declaring_agent_preapproval = %w[implement plan-implement]
skills_without_mutation_preapproval = %w[bug-check review verify-workflow]

paths.each do |path|
  content = File.read(path)
  match = content.match(/\A---\n(.*?)\n---\n/m)
  raise "#{path}: missing YAML frontmatter" unless match

  begin
    metadata = YAML.safe_load(match[1], aliases: false) || {}
  rescue Psych::SyntaxError => error
    raise "#{path}: invalid YAML frontmatter (#{error.problem}). Remediation: quote descriptions or hints containing ':' and nested punctuation."
  end
  unexpected = metadata.keys - allowed_keys
  raise "#{path}: unexpected frontmatter keys: #{unexpected.join(", ")}" unless unexpected.empty?

  name = metadata["name"].to_s
  expected_name = File.basename(File.dirname(path))
  raise "#{path}: name must be #{expected_name.inspect}" unless name == expected_name
  raise "#{path}: name must use lowercase letters, digits, and hyphens" unless name.match?(/\A[a-z0-9-]+\z/)
  raise "#{path}: name must stay under 64 characters" if name.length >= 64

  description = metadata["description"].to_s.strip
  raise "#{path}: description is required" if description.empty?
  raise "#{path}: description must stay under 1024 characters" if description.length > 1024
  raise "#{path}: description must not start with 'Use' / 'Utiliser'" if description.match?(/\A(use|utiliser)\b/i)
  raise "#{path}: description must not include XML tags" if description.match?(/<[^>\n]+>/)

  if metadata.key?("allowed-tools")
    tools = metadata["allowed-tools"]
    raise "#{path}: allowed-tools must be an explicit non-empty array." unless tools.is_a?(Array) && !tools.empty?
    unknown_tools = tools.map(&:to_s) - allowed_tools
    unless unknown_tools.empty?
      raise "#{path}: obsolete or unsupported tools: #{unknown_tools.join(", ")}. Remediation: use current Claude Code tool names (Agent, Edit) only."
    end
  end
  tool_names = Array(metadata["allowed-tools"]).map(&:to_s)
  if skills_declaring_agent_preapproval.include?(name) && !tool_names.include?("Agent")
    raise "#{path}: delegating skill must declare the current Agent tool pre-approval."
  end
  if skills_without_mutation_preapproval.include?(name) && !(tool_names & %w[Write Edit Bash]).empty?
    raise "#{path}: source-read-only skill pre-approves a mutation-capable tool. Remediation: allowed-tools grants permission; it is not a sandbox."
  end

  body = content[match[0].length..] || ""
  if body.match?(/\bTask tool\b/) || body.match?(/\(Task tool\)/)
    raise "#{path}: stale Task-tool instruction. Remediation: use the current Agent tool name."
  end
  raise "#{path}: body should stay under 500 lines" if body.lines.count > 500

  Dir.glob(File.join(File.dirname(path), "*")).sort.each do |resource|
    next unless File.file?(resource)
    basename = File.basename(resource)
    next if basename == "SKILL.md"
    raise "#{path}: bundled resource #{basename} must be referenced from SKILL.md" unless body.include?(basename)
  end
end

implementation_loop = File.read(File.join(root, "workflow/skills/implementation-loop.md"))
unless implementation_loop.include?("scout") && implementation_loop.include?("worker") && implementation_loop.include?("reviewer")
  raise "workflow/skills/implementation-loop.md must retain the bounded scout/worker/reviewer orchestration references."
end
unless implementation_loop.match?(/foreground/i) && implementation_loop.match?(/wait\s+for\s+the\s+worker/i)
  raise "workflow/skills/implementation-loop.md must require a foreground-or-awaited worker before the parent writes again."
end
RUBY

printf 'claude skills smoke test: ok\n'
