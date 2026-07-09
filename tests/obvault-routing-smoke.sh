#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
contract="$ROOT_DIR/workflow/skills/obvault-memory.md"

test -f "$contract"
for adapter in "$ROOT_DIR/codex/AGENTS.md" "$ROOT_DIR/claude/CLAUDE.md" "$ROOT_DIR/pi/AGENTS.md"; do
  grep -Fq 'workflow/skills/obvault-memory.md' "$adapter"
done
grep -Fq 'Retrieve when' "$contract"
grep -Fq 'Do not retrieve' "$contract"
grep -Fq 'untrusted data' "$contract"
grep -Fq 'distill --apply' "$contract"
grep -Fq 'hit`, `miss`, `stale`, or `wrong' "$contract"
printf 'obvault routing smoke test: ok\n'
