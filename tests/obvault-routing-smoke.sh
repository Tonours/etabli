#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
contract="$ROOT_DIR/workflow/skills/obvault-memory.md"

test -f "$contract"
for adapter in \
  "$ROOT_DIR/AGENTS.md" \
  "$ROOT_DIR/CLAUDE.md" \
  "$ROOT_DIR/codex/AGENTS.md" \
  "$ROOT_DIR/claude/CLAUDE.md" \
  "$ROOT_DIR/pi/AGENTS.md"; do
  grep -Fq 'workflow/skills/obvault-memory.md' "$adapter"
  grep -Fq '~/work/obvault' "$adapter"
done
grep -Fq 'Mandatory first check' "$contract"
grep -Fq 'do not wait for the user to mention the knowledge base' "$contract"
grep -Fq '~/work/obvault/AGENTS.md' "$contract"
grep -Fq '~/work/obvault/_meta/obvault context' "$contract"
grep -Fq 'Retrieve when' "$contract"
grep -Fq 'Topic-aware routing' "$contract"
grep -Fq 'raw prompt text must never be copied' "$contract"
grep -Fq '_meta/obvault route' "$contract"
grep -Fq 'argv-based resolver' "$contract"
grep -Fq 'Do not retrieve' "$contract"
grep -Fq 'untrusted data' "$contract"
grep -Fq 'distill --apply' "$contract"
grep -Fq 'hit`, `miss`, `stale`, or `wrong' "$contract"
node --input-type=module - "$ROOT_DIR" <<'NODE'
const root = process.argv[2];
const { classifyWorkflowRoute } = await import(`${root}/workflow/runtime/workflow-router-core.mjs`);
const saas = classifyWorkflowRoute("Je recherche des idées de SaaS rentables");
if (saas.route !== "research-plan") throw new Error(`unexpected route: ${saas.route}`);
if (JSON.stringify(saas.knowledgeContext?.topics) !== JSON.stringify(["saas"])) throw new Error("missing SaaS knowledge topic");
if (saas.knowledgeContext.command.includes("rentables")) throw new Error("raw prompt leaked into knowledge command");
if (!saas.knowledgeContext.command.includes("--max-tokens 2500")) throw new Error("unbounded knowledge command");
const unrelated = classifyWorkflowRoute("Bonjour, comment vas-tu ?");
if (unrelated.knowledgeContext) throw new Error("unrelated prompt received knowledge context");
NODE
printf 'obvault routing smoke test: ok\n'
