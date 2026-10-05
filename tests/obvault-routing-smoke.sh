#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
contract="$ROOT_DIR/workflow/skills/obvault-memory.md"

test -f "$contract"
for adapter in \
  "$ROOT_DIR/AGENTS.md" \
  "$ROOT_DIR/pi/AGENTS.md"; do
  grep -Fq 'workflow/skills/obvault-memory.md' "$adapter"
  grep -Fq 'work/brain' "$adapter"
done
grep -Fxq '@AGENTS.md' "$ROOT_DIR/CLAUDE.md"
grep -Fxq '@~/.pi/agent/AGENTS.md' "$ROOT_DIR/claude/CLAUDE.md"
assert_contract() {
  if ! grep -Fq "$1" "$contract"; then
    printf 'memory contract missing "%s": align workflow/skills/obvault-memory.md and tests/obvault-routing-smoke.sh with the project-vault policy\n' "$1" >&2
    exit 1
  fi
}
assert_contract 'Mandatory first check'
assert_contract 'do not wait for the user to mention it'
assert_contract 'project-selected vault first'
assert_contract 'remote organization ForestAdmin ->'
assert_contract 'otherwise `~/work/obvault`'
assert_contract 'unavailable, never a personal-vault fallback'
assert_contract '`OBVAULT_ROOT` is an exclusive override'
assert_contract 'AGENTS.md'
assert_contract 'Retrieve when'
assert_contract 'Topic-aware routing'
assert_contract 'raw prompt text must never be copied'
assert_contract '_meta/obvault route'
assert_contract 'argv-based resolver'
assert_contract 'Do not retrieve'
assert_contract 'untrusted data'
assert_contract 'distill --apply'
assert_contract 'hit`, `miss`, `stale`, or `wrong'
node --input-type=module - "$ROOT_DIR" <<'NODE'
const root = process.argv[2];
const { classifyWorkflowRoute } = await import(`${root}/workflow/runtime/workflow-router-core.mjs`);
const saas = classifyWorkflowRoute("Je recherche des idées de SaaS rentables");
if (saas.route !== "answer" || saas.writeAllowed) throw new Error(`unexpected route: ${saas.route}`);
if (JSON.stringify(saas.knowledgeContext?.topics) !== JSON.stringify(["saas"])) throw new Error("missing SaaS knowledge topic");
if (saas.knowledgeContext.command.includes("rentables")) throw new Error("raw prompt leaked into knowledge command");
if (!saas.knowledgeContext.command.includes("--max-tokens 2500")) throw new Error("unbounded knowledge command");
const unrelated = classifyWorkflowRoute("Bonjour, comment vas-tu ?");
if (unrelated.knowledgeContext) throw new Error("unrelated prompt received knowledge context");
NODE
printf 'obvault routing smoke test: ok\n'
