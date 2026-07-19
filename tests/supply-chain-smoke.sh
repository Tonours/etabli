#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/agentic-infra.yml"
DEPENDABOT="$ROOT_DIR/.github/dependabot.yml"
PACKAGE="$ROOT_DIR/pi/package.json"

fail() {
  printf 'supply chain smoke: %s\n' "$1" >&2
  exit 1
}

while IFS= read -r reference; do
  printf '%s\n' "$reference" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}$' ||
    fail "GitHub Action is not pinned to a full commit SHA: $reference"
done < <(sed -nE 's/^[[:space:]]*uses:[[:space:]]*([^[:space:]#]+).*/\1/p' "$WORKFLOW")

if grep -Eq 'uses:[[:space:]]+actions/cache@[0-9a-f]{40}[[:space:]]+# v[1-4]([.]|$)' "$WORKFLOW"; then
  fail "actions/cache must use a Node.js 24-compatible major version"
fi

grep -Fq 'npm install --global hunkdiff@0.17.3' "$WORKFLOW" ||
  fail "hunkdiff must be pinned to 0.17.3"

jq -e '
  .dependencies["@earendil-works/pi-coding-agent"] == "0.80.10" and
  .devDependencies.typescript == "7.0.2" and
  .devDependencies["@types/bun"] == "1.3.14" and
  .overrides == {
    "@protobufjs/utf8": "1.1.2",
    "brace-expansion": "5.0.7",
    "protobufjs": "7.6.5",
    "ws": "8.21.1"
  }
' "$PACKAGE" >/dev/null || fail "Pi dependency and security override pins drifted"

ruby -e '
  require "yaml"
  updates = YAML.load_file(ARGV.fetch(0)).fetch("updates")
  pairs = updates.map { |entry| [entry.fetch("package-ecosystem"), entry.fetch("directory")] }
  abort "missing github-actions Dependabot surface" unless pairs.include?(["github-actions", "/"])
  abort "missing Pi npm Dependabot surface" unless pairs.include?(["npm", "/pi"])
' "$DEPENDABOT" || fail "Dependabot configuration is incomplete"

printf 'supply chain smoke test: ok\n'
