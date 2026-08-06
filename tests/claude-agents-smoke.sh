#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

ruby - "$ROOT_DIR" <<'RUBY'
require "yaml"

root = ARGV.fetch(0)
agents_dir = File.join(root, "claude/agents")
expected_agents = %w[reviewer scout worker]
paths = Dir.glob(File.join(agents_dir, "*.md")).sort
names = paths.map { |path| File.basename(path, ".md") }
raise "Claude agents must be exactly #{expected_agents.join(", ")}; got #{names.join(", ")}. Remediation: keep the bounded scout/worker/reviewer role set." unless names == expected_agents

allowed_keys = %w[name description model effort color tools permissionMode maxTurns hooks]
allowed_models = %w[sonnet opus haiku fable inherit]
allowed_efforts = %w[low medium high xhigh max]
allowed_tools = %w[Read Grep Glob Bash Edit Write TodoWrite]
read_only_agents = %w[reviewer scout]
lenses = [
  "Precedence",
  "Degraded modes",
  "Impossible states",
  "Prose vs machine-readable",
  "Exhaustive reachability",
  "Asymmetry",
  "Boundary drift",
]

paths.each do |path|
  content = File.read(path)
  match = content.match(/\A---\n(.*?)\n---\n/m)
  raise "#{path}: missing YAML frontmatter. Remediation: add explicit name, description, model, effort, tools, maxTurns, and role controls." unless match

  metadata = YAML.safe_load(match[1], aliases: false) || {}
  unexpected = metadata.keys - allowed_keys
  raise "#{path}: unsupported frontmatter keys: #{unexpected.join(", ")}. Remediation: use current Claude Code subagent fields only." unless unexpected.empty?

  name = metadata["name"].to_s
  expected_name = File.basename(path, ".md")
  raise "#{path}: name must be #{expected_name.inspect}." unless name == expected_name

  description = metadata["description"].to_s.strip
  raise "#{path}: description is required and must state when to delegate." if description.empty?
  raise "#{path}: description exceeds 1024 characters." if description.length > 1024

  model = metadata["model"].to_s
  unless allowed_models.include?(model) || model.start_with?("claude-")
    raise "#{path}: unsupported model #{model.inspect}. Remediation: use a current alias or full Claude model ID."
  end
  effort = metadata["effort"].to_s
  raise "#{path}: unsupported effort #{effort.inspect}." unless allowed_efforts.include?(effort)

  max_turns = metadata["maxTurns"]
  unless max_turns.is_a?(Integer) && max_turns.between?(1, 60)
    raise "#{path}: maxTurns must be an integer from 1 to 60. Remediation: bound runaway delegated work."
  end

  tools = metadata["tools"]
  raise "#{path}: tools must be an explicit array." unless tools.is_a?(Array) && !tools.empty?
  unknown_tools = tools.map(&:to_s) - allowed_tools
  raise "#{path}: unsupported tools: #{unknown_tools.join(", ")}. Remediation: use current Claude Code tool names." unless unknown_tools.empty?
  raise "#{path}: nested Agent delegation is forbidden for bounded roles." if tools.map(&:to_s).include?("Agent")

  body = content[match[0].length..] || ""
  if body.include?("~/work/brain")
    raise "#{path}: stale ~/work/brain dependency. Remediation: follow workflow/skills/obvault-memory.md conditionally."
  end
  if body.lines.count > 120
    raise "#{path}: prompt is #{body.lines.count} lines; limit is 120. Remediation: keep procedures here and shared reference material in workflow/."
  end

  if read_only_agents.include?(name)
    expected_tools = %w[Bash Glob Grep Read]
    unless tools.map(&:to_s).sort == expected_tools
      raise "#{path}: read-only tools must be exactly #{expected_tools.join(", ")}."
    end
    unless metadata["permissionMode"] == "dontAsk"
      raise "#{path}: permissionMode must be dontAsk. Remediation: auto-deny shell calls outside Claude's read-only set."
    end
    hooks = metadata.dig("hooks", "PreToolUse")
    hook_text = hooks.inspect
    unless hooks.is_a?(Array) && hook_text.include?("Bash") && hook_text.include?("read-only-agent-guard.mjs")
      raise "#{path}: missing Bash PreToolUse read-only guard. Remediation: wire read-only-agent-guard.mjs in frontmatter."
    end
    unless body.include?("workflow/skills/obvault-memory.md")
      raise "#{path}: memory routing must point to workflow/skills/obvault-memory.md."
    end
  else
    %w[Read Edit Write Bash].each do |tool|
      raise "#{path}: worker requires #{tool}." unless tools.map(&:to_s).include?(tool)
    end
    raise "#{path}: worker must state that it handles one READY plan step." unless body.match?(/one .*READY.*plan step/i)
  end

  if name == "reviewer"
    if content.bytesize > 6_787
      raise "#{path}: #{content.bytesize} bytes exceeds the 6,787-byte token-efficiency ceiling. Remediation: defer duplicated explanations to workflow/review-rubric.md while preserving the output gate."
    end
    lenses.each do |lens|
      raise "#{path}: missing mandatory reviewer lens row #{lens.inspect}." unless body.include?("| #{lens} |")
    end
    raise "#{path}: reviewer must preserve the concrete-failure evidence bar." unless body.include?("concrete failure")
    raise "#{path}: reviewer must emit the exact three-value verdict contract." unless body.include?("GO WITH NOTES") && body.include?("BLOCK")
  end
end

install_main = File.read(File.join(root, "scripts/lib/install-main.sh"))
unless install_main.include?('"$REPO_DIR/claude/agents"/*.md') && install_main.include?("~/.claude/agents")
  raise "primary installer omits Claude agents. Remediation: link claude/agents/*.md into ~/.claude/agents/."
end

fix_links = File.read(File.join(root, "scripts/check-fix-symlinks.sh"))
unless fix_links.include?("check_claude_agent_links") && fix_links.include?('"$REPO_DIR/claude/agents"/*.md')
  raise "symlink repair omits Claude agents. Remediation: add and invoke check_claude_agent_links."
end

hook = File.join(root, "claude/hooks/read-only-agent-guard.mjs")
raise "missing #{hook}. Remediation: add the shared read-only Bash PreToolUse guard." unless File.file?(hook)
RUBY

printf 'claude agents smoke test: ok\n'
