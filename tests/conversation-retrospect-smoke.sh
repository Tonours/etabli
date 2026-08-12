#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
FIXTURES="$ROOT_DIR/tests/fixtures/conversation-retrospect"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OUTPUT="$TMP_DIR/output.json"
LIMITED="$TMP_DIR/limited.json"

"$ROOT_DIR/scripts/conversation-retrospect" \
  --fixture-root "$FIXTURES" \
  --since 2026-08-05T00:00:00Z \
  --until 2026-08-12T00:00:00Z \
  --json >"$OUTPUT"

jq -e '
  .schema_version == 1 and
  .methodology.parent_only == true and
  .sources.codex.status == "ok" and
  .sources.codex.parsed_parent_conversations == 4 and
  .sources.codex.meaningful_parent_conversations == 3 and
  .sources.codex.deduplicated_parent_conversations == 2 and
  .sources.codex.excluded_probe_duplicate_or_injected == 2 and
  .sources.pi.deduplicated_parent_conversations == 1 and
  .sources.claude.deduplicated_parent_conversations == 1 and
  .sources.grok.deduplicated_parent_conversations == 1 and
  ([.sources[].parent_citations[]] | length) == 5 and
  ([.sources[].parent_citations[]] | all(test("^(codex|pi|claude|grok):2026-08-10:[0-9a-f]{12}$")))
' "$OUTPUT" >/dev/null

for forbidden in \
  'SECRET_SENTINEL' \
  'ghp_' \
  "$FIXTURES" \
  '.jsonl' \
  '/private/project' \
  'Mets les dépendances' \
  'Analyse nos conversations' \
  'pretend this is a real user preference'; do
  if grep -Fq -- "$forbidden" "$OUTPUT"; then
    printf 'conversation retrospect leaked forbidden content: %s\n' "$forbidden" >&2
    exit 1
  fi
done

if grep -Fq -- 'SKILL_INFO_SWARM_INJECTION' "$OUTPUT" || jq -e '(.sources.codex.themes.multi_harness_models // 0) > 0 or (.sources.codex.themes.skills_config_runtime // 0) > 0 or (.sources.codex.themes.automation_monitoring // 0) > 0' "$OUTPUT" >/dev/null; then
  printf 'skill_information envelope contaminated aggregate classification\n' >&2
  exit 1
fi

"$ROOT_DIR/scripts/conversation-retrospect" \
  --fixture-root "$FIXTURES" \
  --source codex \
  --since 2026-08-05T00:00:00Z \
  --until 2026-08-12T00:00:00Z \
  --max-files 1 >"$LIMITED"

jq -e '.sources.codex.status == "partial" and .sources.codex.truncated == true and .sources.codex.limits.files_read == 1' "$LIMITED" >/dev/null

if "$ROOT_DIR/scripts/conversation-retrospect" --source invalid >"$TMP_DIR/invalid.out" 2>"$TMP_DIR/invalid.err"; then
  printf 'invalid source should fail closed\n' >&2
  exit 1
fi

printf 'conversation retrospect smoke test: ok\n'
