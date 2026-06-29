#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

ruby - "$ROOT_DIR" <<'RUBY'
require "yaml"

root = ARGV.fetch(0)
allowed_keys = %w[
  name
  description
  disable-model-invocation
  argument-hint
  allowed-tools
]

Dir.glob(File.join(root, "claude/skills/*/SKILL.md")).sort.each do |path|
  content = File.read(path)
  match = content.match(/\A---\n(.*?)\n---\n/m)
  raise "#{path}: missing YAML frontmatter" unless match

  metadata = YAML.safe_load(match[1], aliases: false) || {}
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

  body = content[match[0].length..] || ""
  raise "#{path}: body should stay under 500 lines" if body.lines.count > 500

  Dir.glob(File.join(File.dirname(path), "*")).sort.each do |resource|
    next unless File.file?(resource)
    basename = File.basename(resource)
    next if basename == "SKILL.md"
    raise "#{path}: bundled resource #{basename} must be referenced from SKILL.md" unless body.include?(basename)
  end
end
RUBY

printf 'claude skills smoke test: ok\n'
