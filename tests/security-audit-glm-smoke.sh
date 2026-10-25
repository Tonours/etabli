#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR/home" SECURITY_AUDIT_GLM_HOME="$TMP_DIR/state"
mkdir -p "$HOME" "$TMP_DIR/bin" "$TMP_DIR/target"

cat >"$TMP_DIR/bin/claude" <<'CLAUDE'
#!/bin/bash
{
  printf 'cwd=%s\n' "$PWD"
  printf 'token=%s api_key=%s headers=%s foundry=%s\n' "${ANTHROPIC_AUTH_TOKEN:-}" "${ANTHROPIC_API_KEY:-unset}" "${ANTHROPIC_CUSTOM_HEADERS:-unset}" "${CLAUDE_CODE_USE_FOUNDRY:-unset}"
  printf 'base=%s config=%s\n' "$ANTHROPIC_BASE_URL" "$CLAUDE_CONFIG_DIR"
  printf 'models=%s %s %s %s\n' "$ANTHROPIC_DEFAULT_OPUS_MODEL" "$ANTHROPIC_DEFAULT_SONNET_MODEL" "$ANTHROPIC_DEFAULT_HAIKU_MODEL" "$CLAUDE_CODE_SUBAGENT_MODEL"
  printf 'bg_wait=%s\n' "${CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS:-unset}"
  printf 'args=%s\n' "$*"
} >"$FAKE_OUT"
CLAUDE
chmod +x "$TMP_DIR/bin/claude"
cat >"$TMP_DIR/bin/docker" <<'DOCKER'
#!/bin/bash
[ -n "${FAKE_DOCKER_READY:-}" ]
DOCKER
chmod +x "$TMP_DIR/bin/docker"
export PATH="$TMP_DIR/bin:$PATH" FAKE_OUT="$TMP_DIR/claude.out"

failures=0
check() {
  local label="$1"
  shift
  if "$@"; then printf 'ok   %s\n' "$label"; else printf 'FAIL %s\n' "$label"; failures=$((failures + 1)); fi
}
has() { grep -Fq -- "$1" "$FAKE_OUT"; }

ZAI_API_KEY=zai-test ANTHROPIC_API_KEY=anthropic-test ANTHROPIC_CUSTOM_HEADERS='x-api-key: a' CLAUDE_CODE_USE_FOUNDRY=1 \
  "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --profile quick --print 2>/dev/null
check "runs in the target" has "cwd=$(cd "$TMP_DIR/target" && pwd)"
check "z.ai token, no anthropic credential or provider" has "token=zai-test api_key=unset headers=unset foundry=unset"
check "z.ai endpoint, own config dir" has "base=https://api.z.ai/api/anthropic config=$TMP_DIR/state"
check "every tier and subagent on glm" has "models=glm-5.3[1m] glm-5.3[1m] glm-5.3[1m] glm-5.3[1m]"
check "max effort, isolated settings" has "--model glm-5.3[1m] --effort max --permission-mode auto --setting-sources user --strict-mcp-config --add-dir $HOME/security-audit-skill --print --output-format text -- Run a full"
check "headless run waits for slow verifiers" has "bg_wait=3600000"
check "profile reaches the prompt" has 'profile `quick`'
check "skill linked into the config dir" [ -f "$TMP_DIR/state/skills/security-audit/SKILL.md" ]
check "web fetch preflight off" grep -q '"skipWebFetchPreflight":true' "$TMP_DIR/state/settings.json"

(cd "$TMP_DIR" && ZAI_API_KEY=k SECURITY_AUDIT_GLM_HOME=rel-state "$ROOT_DIR/scripts/security-audit-glm" target 2>/dev/null)
check "interactive: the prompt is not an --add-dir value" has "--add-dir $HOME/security-audit-skill -- Run a full"
check "relative state dir resolves before cd" has "config=$TMP_DIR/rel-state"

check "no sandbox: source-only prompt" has "No OS-enforced sandbox is available on this host: do not execute target code."
WARNING="$(ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print 2>&1 >/dev/null)"
check "no sandbox: warns on stderr" grep -q "no sandbox (.*); the audit stays source-only" <<<"$WARNING"

FAKE_DOCKER_READY=1 ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print 2>/dev/null
check "sandbox ready: prompt names the wrapper and the target" has "\`$ROOT_DIR/scripts/security-audit-sandbox --scratch <physical output-dir>/agents/<agent-id>/scratch --target $TMP_DIR/target -- <command>\`"
check "sandbox ready: wrapper is the only execution path" has "It is the only allowed way to run target-controlled code"
check "sandbox ready: empty promotion allowlist" has "the promotion allowlist is empty"

rm -f "$FAKE_OUT"
check "refuses without ZAI_API_KEY" eval '! env -u ZAI_API_KEY "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" 2>/dev/null && [ ! -e "$FAKE_OUT" ]'
check "refuses an effort glm lacks" eval '! ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" --effort xhigh 2>/dev/null && [ ! -e "$FAKE_OUT" ]'
check "dry run keeps the key out" eval '! ZAI_API_KEY=secret-key "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --dry-run 2>&1 | grep -q secret-key'

[ "$failures" -eq 0 ] || { printf 'security-audit-glm smoke test: %d failure(s)\n' "$failures"; exit 1; }
printf 'security-audit-glm smoke test: ok\n'
