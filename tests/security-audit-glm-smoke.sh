#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SKILL_DIR="$ROOT_DIR/vendor/cloudflare/skills/security-audit"
TMP_DIR="$(mktemp -d)"
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"
trap 'rm -rf "$TMP_DIR"' EXIT
NODE_DIR="$(dirname "$(node -p process.execPath)")"
export HOME="$TMP_DIR/home" SECURITY_AUDIT_GLM_HOME="$TMP_DIR/state"
unset SECURITY_AUDIT_GLM_TIMEOUT SECURITY_AUDIT_GLM_API_KEY SECURITY_AUDIT_GLM_BASE_URL SECURITY_AUDIT_GLM_MODEL SECURITY_AUDIT_GLM_EFFORT
mkdir -p "$HOME" "$TMP_DIR/bin" "$TMP_DIR/target" "$TMP_DIR/fixture" "$TMP_DIR/runs"

cat >"$TMP_DIR/bin/claude" <<'CLAUDE'
#!/bin/bash
{
  printf 'cwd=%s\n' "$PWD"
  printf 'token=%s api_key=%s headers=%s foundry=%s\n' "${ANTHROPIC_AUTH_TOKEN:-}" "${ANTHROPIC_API_KEY:-unset}" "${ANTHROPIC_CUSTOM_HEADERS:-unset}" "${CLAUDE_CODE_USE_FOUNDRY:-unset}"
  printf 'base=%s config=%s\n' "$ANTHROPIC_BASE_URL" "$CLAUDE_CONFIG_DIR"
  printf 'models=%s %s %s %s\n' "$ANTHROPIC_DEFAULT_OPUS_MODEL" "$ANTHROPIC_DEFAULT_SONNET_MODEL" "$ANTHROPIC_DEFAULT_HAIKU_MODEL" "$CLAUDE_CODE_SUBAGENT_MODEL"
  printf 'bg_wait=%s tool_search=%s\n' "${CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS:-unset}" "${ENABLE_TOOL_SEARCH:-unset}"
  printf 'args=%s\n' "$*"
} >"$FAKE_OUT"
echo "$$" >"$FAKE_DIR/leader.pid"
for prompt; do :; done
out="$(sed -n 's/.*output to `\([^`]*\)`.*/\1/p' <<<"$prompt")"
edit() { jq "$2" "$out/$1" >"$out/$1.tmp" && mv "$out/$1.tmp" "$out/$1"; }
if [ -n "${FAKE_REPORT:-}" ]; then
  cp "$FAKE_FIXTURE"/* "$out/"
  case "$FAKE_REPORT" in
  complete) ;;
  zero-findings) echo '[]' >"$out/findings.json"; edit coverage-ledger.json 'map(select(.status != "candidate"))' ;;
  incomplete) edit run-metadata.json '.run_status = "incomplete" | .incomplete_reason = "validation_budget_exhausted"' ;;
  early-stop)
    (cd "$out" && rm architecture.md coverage-ledger.json findings.json FINDINGS-DETAIL.md NEEDS-VALIDATION.md)
    edit run-metadata.json '.run_status = "incomplete" | .incomplete_reason = "budget_cannot_fund_reconnaissance_and_reserves"' ;;
  no-reason) edit run-metadata.json '.run_status = "incomplete"' ;;
  in-progress-status) edit run-metadata.json '.run_status = "in_progress"' ;;
  in-progress-unit) edit coverage-ledger.json '.[0] |= (.status = "in_progress" | .reviewed_paths = [] | .local_checks = [])' ;;
  empty-ledger) echo '[]' >"$out/coverage-ledger.json" ;;
  bad-findings) printf '{' >"$out/findings.json" ;;
  missing-file) rm "$out/NEEDS-VALIDATION.md" ;;
  undecided-candidate) echo '[]' >"$out/findings.json" ;;
  fifo-metadata) rm "$out/run-metadata.json"; mkfifo "$out/run-metadata.json" ;;
  esac
fi
case "${FAKE_CHILD:-}" in
ordinary) sleep 60 & ;;
trap) (trap 'touch "$FAKE_DIR/child.cleaned"; exit 0' TERM; sleep 60 & wait) & ;;
ignore) (trap '' TERM; exec sleep 60) & ;;
esac
[ -z "${FAKE_CHILD:-}" ] || echo "$!" >"$FAKE_DIR/child.pid"
[ -z "${FAKE_SLEEP:-}" ] || sleep "$FAKE_SLEEP"
exit "${FAKE_EXIT:-0}"
CLAUDE
chmod +x "$TMP_DIR/bin/claude"
cat >"$TMP_DIR/bin/docker" <<'DOCKER'
#!/bin/bash
[ -n "${FAKE_DOCKER_READY:-}" ]
DOCKER
chmod +x "$TMP_DIR/bin/docker"
export PATH="$TMP_DIR/bin:$NODE_DIR:$PATH" FAKE_OUT="$TMP_DIR/claude.out" FAKE_FIXTURE="$TMP_DIR/fixture" FAKE_DIR="$TMP_DIR"

cat >"$TMP_DIR/fixture.cjs" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const { canonicalCoverageId } = require(process.argv[2]);
const dir = process.argv[3];
const write = (name, value) => fs.writeFileSync(path.join(dir, name), typeof value === "string" ? value : `${JSON.stringify(value, null, 2)}\n`);
const check = (agent) => ({ agent_id: agent, reviewed_paths: ["src/app.js"], invariant: "The host stays one argument.", method: "source", result: "execFile receives the host as one argument.", artifact: null });
const unit = (attackClass, overrides) => {
  const refs = { surface: "src/app.js#GET /ping", boundary: "src/app.js#ping", subsystem: "app", attack_class: `ATTACK-CLASSES.md#${attackClass}` };
  return {
    coverage_id: canonicalCoverageId(refs), canonical_refs: refs, surface: "Ping route", boundary: "Ping handler", subsystem: "App",
    attack_class: attackClass, starting_paths: ["src/app.js"], ordinary_attack_class_block: refs.attack_class,
    selected_companion_blocks: [], excluded_blocks: [], prior_status: "new", attempts: [], wave: 1, status: "covered",
    agent_id: "hunter-1", reviewed_paths: ["src/app.js"], local_checks: [check("hunter-1")], result_fingerprints: [], unresolved: [],
    ...overrides,
  };
};
write("coverage-ledger.json", [
  unit("Access control", {}),
  unit("Injection", { agent_id: "hunter-2", local_checks: [check("hunter-2")], status: "candidate", result_fingerprints: ["src-app-ping-injection"] }),
].sort((a, b) => (a.coverage_id < b.coverage_id ? -1 : 1)));
write("findings.json", [{
  verdict: "rejected", fingerprint: "src-app-ping-injection", title: "Command injection in ping",
  description: "The candidate claimed the host parameter reaches a shell.",
  claimed_root_cause: "ping was claimed to interpolate the host into a shell command.",
  trace: [{ kind: "sink", file: "src/app.js", line: 3, scope: "ping", description: "The host reaches execFile." }],
  evidence: [{ file: "src/app.js", line: 3, description: "execFile passes the host as one argument." }],
  reason: "execFile does not spawn a shell.",
}]);
write("run-metadata.json", {
  run_id: "fixture", repo: "target", target: "/fixture", source_ref: "none", profile: "quick", scope_paths: [], budget: null,
  execution_policy: "sandboxed-source-and-local-only", run_status: "complete",
});
for (const name of ["architecture.md", "REPORT.md", "FINDINGS-DETAIL.md", "NEEDS-VALIDATION.md"]) write(name, `# ${name}\n\nFixture.\n`);
NODE
node "$TMP_DIR/fixture.cjs" "$SKILL_DIR/validate-coverage-ledger.cjs" "$TMP_DIR/fixture"

failures=0
check() {
  local label="$1"
  shift
  if "$@"; then printf 'ok   %s\n' "$label"; else printf 'FAIL %s\n' "$label"; failures=$((failures + 1)); fi
}
has() { grep -Fq -- "$1" "$FAKE_OUT"; }
said() { grep -Fq -- "$1" "$TMP_DIR/err"; }
audit() {
  local name="$1"
  shift
  rm -f "$FAKE_OUT" "$TMP_DIR/child.pid"
  RC=0
  ZAI_API_KEY=k perl -e 'alarm 60; exec @ARGV' "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --profile quick --print --timeout 30 \
    --out "$TMP_DIR/runs/$name" "$@" >/dev/null 2>"$TMP_DIR/err" || RC=$?
}
gone() { [ -s "$TMP_DIR/child.pid" ] && ! kill -0 "$(cat "$TMP_DIR/child.pid")" 2>/dev/null; }
appears() { for _ in $(seq 100); do [ -s "$1" ] && return 0; sleep 0.1; done; return 1; }
runs() { find "$HOME/security-audit-skill/target" -mindepth 1 -maxdepth 1 -name 'run-*' 2>/dev/null | wc -l | tr -d ' '; }
run_dir() { sed -n 's/.*output to `\([^`]*\)`.*/\1/p' "$1"; }

ZAI_API_KEY=zai-test ANTHROPIC_API_KEY=anthropic-test ANTHROPIC_CUSTOM_HEADERS='x-api-key: a' CLAUDE_CODE_USE_FOUNDRY=1 \
  "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --profile quick --print --timeout 30 2>/dev/null || true
check "runs in the target" has "cwd=$(cd "$TMP_DIR/target" && pwd)"
check "z.ai token, no anthropic credential or provider" has "token=zai-test api_key=unset headers=unset foundry=unset"
check "z.ai endpoint, own config dir" has "base=https://api.z.ai/api/anthropic config=$TMP_DIR/state"
check "every tier and subagent on glm" has "models=glm-5.3[1m] glm-5.3[1m] glm-5.3[1m] glm-5.3[1m]"
check "max effort, isolated settings" has "--model glm-5.3[1m] --effort max --permission-mode auto --setting-sources user --strict-mcp-config --add-dir $HOME/security-audit-skill --print --output-format text -- Run a full"
check "headless run waits for slow verifiers, no deferred tools" has "bg_wait=3600000 tool_search=false"
check "profile reaches the prompt" has 'profile `quick`'
check "headless prompt names a fresh default run directory" has "output to \`$HOME/security-audit-skill/target/run-1\`"
check "headless prompt states the deadline and the wrap-up" eval 'has "Hard deadline: " && has "If the audit cannot finish by " && has "set run_status \"incomplete\""'
check "skill linked into the config dir" [ -f "$TMP_DIR/state/skills/security-audit/SKILL.md" ]
check "web fetch preflight off" grep -q '"skipWebFetchPreflight":true' "$TMP_DIR/state/settings.json"

(cd "$TMP_DIR" && ZAI_API_KEY=k SECURITY_AUDIT_GLM_HOME=rel-state "$ROOT_DIR/scripts/security-audit-glm" target 2>/dev/null)
check "interactive: the prompt is not an --add-dir value" has "--add-dir $HOME/security-audit-skill -- Run a full"
check "interactive: no deadline, no run directory" eval '! has "Hard deadline" && ! has "output to"'
check "relative state dir resolves before cd" has "config=$TMP_DIR/rel-state"

check "no sandbox: source-only prompt" has "No OS-enforced sandbox is available on this host: do not execute target code."
WARNING="$(ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print --timeout 30 2>&1 >/dev/null || true)"
check "no sandbox: warns on stderr" grep -q "no sandbox (.*); the audit stays source-only" <<<"$WARNING"

FAKE_DOCKER_READY=1 ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print --timeout 30 2>/dev/null || true
check "sandbox ready: prompt names the wrapper and the target" has "\`$ROOT_DIR/scripts/security-audit-sandbox --scratch <physical output-dir>/agents/<agent-id>/scratch --target $TMP_DIR/target -- <command>\`"
check "sandbox ready: wrapper is the only execution path" has "It is the only allowed way to run target-controlled code"
check "sandbox ready: empty promotion allowlist" has "the promotion allowlist is empty"

rm -f "$FAKE_OUT"
check "refuses without ZAI_API_KEY" eval '! env -u ZAI_API_KEY "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" 2>/dev/null && [ ! -e "$FAKE_OUT" ]'
check "refuses an effort glm lacks" eval '! ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" --effort xhigh 2>/dev/null && [ ! -e "$FAKE_OUT" ]'
check "dry run keeps the key out" eval '! ZAI_API_KEY=secret-key "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --dry-run 2>&1 | grep -q secret-key'
preview="$(ZAI_API_KEY=zai-private SECURITY_AUDIT_GLM_API_KEY=provider-private SECURITY_AUDIT_GLM_BASE_URL=https://api.deepseek.com/anthropic \
  "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --dry-run 2>&1)"
check "custom-provider preview references the key variable" grep -Fq '\$SECURITY_AUDIT_GLM_API_KEY' <<<"$preview"
check "custom-provider preview prints neither key" eval '! grep -Eq "zai-private|provider-private" <<<"$preview"'
ZAI_API_KEY=zai-private SECURITY_AUDIT_GLM_API_KEY=provider-private SECURITY_AUDIT_GLM_BASE_URL=https://api.deepseek.com/anthropic \
  SECURITY_AUDIT_GLM_MODEL='deepseek-flash[1m]' "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" >/dev/null 2>&1
check "custom provider receives its own key, not Z.ai's" has "token=provider-private api_key=unset"
check "custom provider receives its endpoint" has "base=https://api.deepseek.com/anthropic"
check "custom provider overrides every model tier" has "models=deepseek-flash[1m] deepseek-flash[1m] deepseek-flash[1m] deepseek-flash[1m]"

check "fixture passes the upstream validators" eval 'node "$SKILL_DIR/validate-findings.cjs" "$TMP_DIR/fixture/findings.json" >/dev/null && node "$SKILL_DIR/validate-coverage-ledger.cjs" "$TMP_DIR/fixture/coverage-ledger.json" >/dev/null'
audit none
check "zero child exit without reports fails" eval '[ "$RC" = 4 ] && said "run-metadata.json is missing"'
FAKE_REPORT=complete audit complete
check "complete checked reports succeed" [ "$RC" = 0 ]
check "prompt names the exact --out run directory" has "output to \`$TMP_DIR/runs/complete\`"
FAKE_REPORT=zero-findings audit zero
check "zero findings succeed" [ "$RC" = 0 ]
FAKE_REPORT=incomplete audit incomplete
check "declared incomplete exits 3 with its reason" eval '[ "$RC" = 3 ] && said "validation_budget_exhausted"'
FAKE_REPORT=early-stop audit early
check "early incomplete stop needs only metadata and report" [ "$RC" = 3 ]
FAKE_REPORT=no-reason audit no-reason
check "incomplete without a reason is invalid" [ "$RC" = 4 ]
FAKE_REPORT=in-progress-status audit status
check "run_status in_progress is invalid" [ "$RC" = 4 ]
FAKE_REPORT=in-progress-unit audit unit
check "complete with an in_progress unit is invalid" eval '[ "$RC" = 4 ] && said "planned or in_progress"'
FAKE_REPORT=empty-ledger audit empty-ledger
check "complete with an empty ledger is invalid" eval '[ "$RC" = 4 ] && said "coverage ledger is empty"'
FAKE_REPORT=undecided-candidate audit undecided
check "a candidate without a final record is invalid" eval '[ "$RC" = 4 ] && said "has no final record"'
FAKE_REPORT=fifo-metadata audit fifo
check "non-regular metadata is invalid without blocking" eval '[ "$RC" = 4 ] && said "run-metadata.json is missing"'
FAKE_REPORT=bad-findings audit bad
check "malformed findings fail the validator" eval '[ "$RC" = 4 ] && said "validate-findings.cjs"'
FAKE_REPORT=missing-file audit missing
check "missing shared file is invalid" eval '[ "$RC" = 4 ] && said "NEEDS-VALIDATION.md"'
FAKE_REPORT=complete audit profile --profile standard
check "profile mismatch is invalid" eval '[ "$RC" = 4 ] && said "profile is not standard"'
FAKE_REPORT=complete FAKE_EXIT=3 audit child-fail
check "claude failure exits 5 even with valid reports" eval '[ "$RC" = 5 ] && said "claude exited 3"'

mkdir -p "$TMP_DIR/runs/used" && echo keep >"$TMP_DIR/runs/used/keep"
FAKE_REPORT=complete audit used
check "non-empty --out is refused untouched" eval '[ "$RC" = 2 ] && [ "$(ls -A "$TMP_DIR/runs/used")" = keep ] && [ "$(cat "$TMP_DIR/runs/used/keep")" = keep ] && [ ! -e "$FAKE_OUT" ]'
mkdir -p "$TMP_DIR/runs/empty"
FAKE_REPORT=complete audit empty
check "existing empty --out is refused" eval '[ "$RC" = 2 ] && said "already exists" && [ -z "$(ls -A "$TMP_DIR/runs/empty")" ]'
FAKE_REPORT=complete audit "with space/run"
check "paths with spaces work" [ "$RC" = 0 ]
BEFORE="$(runs)"
FAKE_OUT="$TMP_DIR/a.out" ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print --timeout 30 >/dev/null 2>&1 &
A=$!
FAKE_OUT="$TMP_DIR/b.out" ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print --timeout 30 >/dev/null 2>&1 &
B=$!
wait "$A" || true
wait "$B" || true
check "concurrent default runs get distinct directories" eval '[ "$(runs)" = $((BEFORE + 2)) ] && [ "$(run_dir "$TMP_DIR/a.out")" != "$(run_dir "$TMP_DIR/b.out")" ]'
BEFORE="$(runs)"
ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print --timeout 30 --dry-run >/dev/null 2>&1
check "dry run allocates no run directory" [ "$(runs)" = "$BEFORE" ]

rm -f "$FAKE_OUT"
refused() { RC=0; ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print "$@" 2>"$TMP_DIR/err" || RC=$?; [ "$RC" = 2 ] && said "--print needs --timeout" && [ ! -e "$FAKE_OUT" ]; }
check "--print without a budget is refused" refused
check "a zero budget is refused" refused --timeout 0
check "an oversized budget is refused" refused --timeout 123456789
RC=0
FAKE_REPORT=complete SECURITY_AUDIT_GLM_TIMEOUT=30 ZAI_API_KEY=k "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --profile quick --print \
  --out "$TMP_DIR/runs/env" >/dev/null 2>&1 || RC=$?
check "budget from the environment" [ "$RC" = 0 ]
FAKE_REPORT=complete SECURITY_AUDIT_GLM_TIMEOUT=bad audit flag-wins
check "--timeout wins over the environment" [ "$RC" = 0 ]
SECONDS=0
FAKE_REPORT=complete FAKE_CHILD=ordinary FAKE_SLEEP=60 audit deadline --timeout 1
check "deadline exits 124, keeps partial output, ends the group" eval '[ "$RC" = 124 ] && [ "$SECONDS" -lt 6 ] && [ -f "$TMP_DIR/runs/deadline/run-metadata.json" ] && gone'
FAKE_CHILD=trap FAKE_SLEEP=60 audit cleanup --timeout 1
check "a descendant's TERM cleanup runs" eval '[ "$RC" = 124 ] && [ -e "$TMP_DIR/child.cleaned" ] && gone'
SECONDS=0
FAKE_CHILD=ignore FAKE_SLEEP=60 audit kill --timeout 1
check "a descendant ignoring TERM is killed after the grace" eval '[ "$RC" = 124 ] && [ "$SECONDS" -ge 9 ] && [ "$SECONDS" -lt 15 ] && gone'
FAKE_REPORT=complete FAKE_CHILD=ordinary audit leftover
check "a descendant left after a clean exit is ended" eval '[ "$RC" = 0 ] && gone'
interrupt() {
  rm -f "$TMP_DIR/child.pid" "$TMP_DIR/leader.pid"
  FAKE_REPORT=complete ZAI_API_KEY=k perl -e 'setpgrp(0, 0); $SIG{INT} = "DEFAULT"; alarm 60; exec @ARGV' \
    "$ROOT_DIR/scripts/security-audit-glm" "$TMP_DIR/target" --print --timeout 30 --out "$TMP_DIR/runs/$1-$2" >/dev/null 2>&1 &
  local launcher=$!
  appears "$TMP_DIR/child.pid"
  if [ "$2" = group ]; then
    for _ in $(seq 100); do kill -0 "$(cat "$TMP_DIR/leader.pid")" 2>/dev/null || break; sleep 0.1; done
    SWEEP_START=$SECONDS
    if kill -0 "$(cat "$TMP_DIR/leader.pid")" 2>/dev/null; then SWEEP_START=leader-alive; fi
    kill "-$1" -- "-$launcher"
    sleep 4
    kill "-$1" -- "-$launcher" 2>/dev/null || true
    sleep 4
    kill "-$1" -- "-$launcher" 2>/dev/null || true
  else
    kill "-$1" "$launcher"
  fi
  RC=0
  wait "$launcher" || RC=$?
}
FAKE_CHILD=ordinary FAKE_SLEEP=60 interrupt TERM launcher
check "TERM interrupts with 143 and ends the group" eval '[ "$RC" = 143 ] && gone'
FAKE_CHILD=ordinary FAKE_SLEEP=60 interrupt HUP launcher
check "HUP interrupts with 129 and ends the group" eval '[ "$RC" = 129 ] && gone'
FAKE_CHILD=ordinary FAKE_SLEEP=60 interrupt INT launcher
check "INT interrupts with 130 and ends the group" eval '[ "$RC" = 130 ] && gone'
FAKE_CHILD=ignore interrupt TERM group
swept_in_grace() { [ "$RC" = 143 ] && [ "$SWEEP_START" != leader-alive ] && [ $((SECONDS - SWEEP_START)) -ge 9 ] && [ $((SECONDS - SWEEP_START)) -lt 14 ] && gone; }
check "repeated group TERMs during the final sweep keep its grace and kill a TERM-ignoring descendant" swept_in_grace

[ "$failures" -eq 0 ] || { printf 'security-audit-glm smoke test: %d failure(s)\n' "$failures"; exit 1; }
printf 'security-audit-glm smoke test: ok\n'
