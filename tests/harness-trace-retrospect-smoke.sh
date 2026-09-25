#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/scripts/harness-trace-retrospect"
FIX="$ROOT/tests/fixtures/harness-traces"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'harness-trace-retrospect-smoke: %s\n' "$1" >&2
  exit 1
}

pi="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.capability == "prototype_offline" and .adapter == "pi" and .binding == "explicit_unverified" and .completeness == "complete" and .signals.tool_calls == 1 and .signals.tool_errors == 1 and .signals.compactions == 1 and .signals.retries == null and .signals.unsupported_rows == 0 and .decision == {action:"recommendation",category:"validation_failure",target:"testing",causal_status:"unknown"} and .jev_state.candidate == "action=recommendation;category=validation_failure;target=testing"' <<<"$pi" >/dev/null

bound="$($CLI --adapter pi --trace-file "$FIX/pi/session-bound.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "native_correlated" and .completeness == "complete" and .reason_codes == [] and .signals.tool_calls == 1 and .signals.tool_errors == 0' <<<"$bound" >/dev/null

real_shape="$($CLI --adapter pi --trace-file "$FIX/pi/session-bound-real-shape.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "native_correlated" and .completeness == "complete" and .reason_codes == [] and .signals.unsupported_rows == 0' <<<"$real_shape" >/dev/null

sed 's/"schema_version":2/"schema_version":99/' "$FIX/pi/session-bound-real-shape.jsonl" >"$TMP/malformed-route-decision.jsonl"
malformed_route_decision="$($CLI --adapter pi --trace-file "$TMP/malformed-route-decision.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"]' <<<"$malformed_route_decision" >/dev/null

sed 's/"provider":"private","modelId"/"provider":"","modelId"/' "$FIX/pi/session-bound-real-shape.jsonl" >"$TMP/malformed-model-change.jsonl"
malformed_model_change="$($CLI --adapter pi --trace-file "$TMP/malformed-model-change.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"]' <<<"$malformed_model_change" >/dev/null

sed 's/"selected_decision":"plan-implement"/"selected_decision":"review"/' "$FIX/pi/session-bound-real-shape.jsonl" >"$TMP/conflicting-route-receipt.jsonl"
conflicting_route_receipt="$($CLI --adapter pi --trace-file "$TMP/conflicting-route-receipt.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_route_conflict"]' <<<"$conflicting_route_receipt" >/dev/null

sed 's/"route":"plan-implement"/"route":"review"/' "$FIX/pi/session-bound.jsonl" >"$TMP/native-route-mismatch.jsonl"
native_route_mismatch="$($CLI --adapter pi --trace-file "$TMP/native-route-mismatch.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "explicit_unverified" and .completeness == "unavailable" and .reason_codes == ["trace_route_mismatch"]' <<<"$native_route_mismatch" >/dev/null

sed 's/"isError":false/"isError":true/' "$FIX/pi/session-bound.jsonl" >"$TMP/post-terminal-error.jsonl"
post_terminal_error="$($CLI --adapter pi --trace-file "$TMP/post-terminal-error.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "native_correlated" and .completeness == "complete" and .signals.tool_calls == 1 and .signals.tool_errors == 1' <<<"$post_terminal_error" >/dev/null

tracked_terminal_error="$($CLI --adapter pi --trace-file "$FIX/pi/session-bound-terminal-error.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "native_correlated" and .completeness == "complete" and .signals.tool_calls == 1 and .signals.tool_errors == 1' <<<"$tracked_terminal_error" >/dev/null

sed -n '1p' "$FIX/pi/session-bound.jsonl" >"$TMP/reused-session.jsonl"
printf '%s\n' '{"type":"custom","id":"old-binding","parentId":null,"customType":"etabli.workflow-run-binding","timestamp":"2026-09-20T09:57:05Z","data":{"schema_version":1,"algorithm":"sha256","fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}' >>"$TMP/reused-session.jsonl"
sed -n '2,11p' "$FIX/pi/session-bound.jsonl" | sed '1s/"parentId":null/"parentId":"old-binding"/' >>"$TMP/reused-session.jsonl"
reused="$($CLI --adapter pi --trace-file "$TMP/reused-session.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "native_correlated" and .completeness == "complete" and .reason_codes == []' <<<"$reused" >/dev/null

{
  sed -n '1,3p' "$FIX/pi/session-bound.jsonl"
  printf '%s\n' '{"type":"custom","id":"old-binding","parentId":"route","customType":"etabli.workflow-run-binding","timestamp":"2026-09-20T09:57:45Z","data":{"schema_version":1,"algorithm":"sha256","fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}'
  sed -n '4,11p' "$FIX/pi/session-bound.jsonl" | sed '1s/"parentId":"route"/"parentId":"old-binding"/'
} >"$TMP/stale-route-session.jsonl"
stale_route="$($CLI --adapter pi --trace-file "$TMP/stale-route-session.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "explicit_unverified" and .completeness == "unavailable" and .reason_codes == ["trace_route_mismatch"]' <<<"$stale_route" >/dev/null

sed 's/"reason":"fixture"/"reason":"other genesis"/' "$FIX/pi/events.jsonl" >"$TMP/replayed-ledger.jsonl"
replayed="$($CLI --adapter pi --trace-file "$FIX/pi/session-bound.jsonl" --ledger "$TMP/replayed-ledger.jsonl" --run pi-run --json)"
jq -e '.binding == "explicit_unverified" and .completeness == "unavailable" and .reason_codes == ["trace_binding_mismatch"]' <<<"$replayed" >/dev/null

sed 's/"fingerprint":"[0-9a-f]*"/"fingerprint":"invalid-private-value"/' "$FIX/pi/session-bound.jsonl" >"$TMP/malformed-binding.jsonl"
malformed_binding="$($CLI --adapter pi --trace-file "$TMP/malformed-binding.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "explicit_unverified" and .completeness == "unavailable" and .reason_codes == ["trace_binding_mismatch"]' <<<"$malformed_binding" >/dev/null

sed -n '1,6p' "$FIX/pi/session-bound.jsonl" >"$TMP/duplicate-binding.jsonl"
sed -n '6p' "$FIX/pi/session-bound.jsonl" | sed 's/"id":"binding"/"id":"binding-2"/;s/"parentId":"early-result"/"parentId":"binding"/' >>"$TMP/duplicate-binding.jsonl"
sed -n '7,11p' "$FIX/pi/session-bound.jsonl" | sed '1s/"parentId":"binding"/"parentId":"binding-2"/' >>"$TMP/duplicate-binding.jsonl"
duplicate_binding="$($CLI --adapter pi --trace-file "$TMP/duplicate-binding.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.binding == "explicit_unverified" and .completeness == "unavailable" and .reason_codes == ["trace_binding_conflict"]' <<<"$duplicate_binding" >/dev/null

claude="$($CLI --adapter claude --trace-file "$FIX/claude/session.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.adapter == "claude" and .completeness == "complete" and .signals.tool_calls == 1 and .signals.tool_errors == 0 and .signals.compactions == null and .decision.action == "no_op"' <<<"$claude" >/dev/null

sed 's/"version":3/"version":999/' "$FIX/pi/session.jsonl" >"$TMP/unknown-version.jsonl"
unknown_version="$($CLI --adapter pi --trace-file "$TMP/unknown-version.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_identity_unknown"] and .decision == null' <<<"$unknown_version" >/dev/null

sed '/"version":3/s/,"version":3//' "$FIX/pi/session.jsonl" >"$TMP/missing-version.jsonl"
missing_version="$($CLI --adapter pi --trace-file "$TMP/missing-version.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_identity_unknown"] and .decision == null' <<<"$missing_version" >/dev/null

sed 's/2026-09-20T10:02:00Z/2026-09-20T10:00:45Z/' "$FIX/pi/session.jsonl" >"$TMP/non-monotonic-pi.jsonl"
non_monotonic_pi="$($CLI --adapter pi --trace-file "$TMP/non-monotonic-pi.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_time_conflict"] and .decision == null' <<<"$non_monotonic_pi" >/dev/null

sed 's/2026-09-20T11:02:00Z/2026-09-20T11:00:30Z/' "$FIX/claude/session.jsonl" >"$TMP/non-monotonic-claude.jsonl"
non_monotonic_claude="$($CLI --adapter claude --trace-file "$TMP/non-monotonic-claude.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_time_conflict"] and .decision == null' <<<"$non_monotonic_claude" >/dev/null

sed '1s/"type":"user"/"type":"user","isMeta":true/' "$FIX/claude/session.jsonl" >"$TMP/claude-meta.jsonl"
claude_meta="$($CLI --adapter claude --trace-file "$TMP/claude-meta.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_identity_unknown"] and .decision == null and .jev_state == null' <<<"$claude_meta" >/dev/null

cp "$FIX/pi/session.jsonl" "$TMP/invalid-usage.jsonl"
printf '%s\n' '{"type":"message","id":"usage-bad","parentId":"c","timestamp":"2026-09-20T10:03:30Z","message":{"role":"assistant","content":[],"usage":{"input":1,"output":1,"totalTokens":1}}}' >>"$TMP/invalid-usage.jsonl"
invalid_usage="$($CLI --adapter pi --trace-file "$TMP/invalid-usage.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete" and .usage == null' <<<"$invalid_usage" >/dev/null

sed 's/"input":100/"input":"100"/' "$FIX/pi/session.jsonl" >"$TMP/coerced-usage.jsonl"
coerced_usage="$($CLI --adapter pi --trace-file "$TMP/coerced-usage.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete" and .usage == null' <<<"$coerced_usage" >/dev/null

sed 's/"totalTokens":120/"totalTokens":"120"/' "$FIX/pi/session.jsonl" >"$TMP/coerced-total.jsonl"
coerced_total="$($CLI --adapter pi --trace-file "$TMP/coerced-total.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete" and .usage == null' <<<"$coerced_total" >/dev/null

for forbidden in 'private' '/private' 'secret command' 'session.jsonl' 'pi-private-session' 'claude-private-session' 'validation command' 'terminal summary' '926a4c832da5'; do
  if printf '%s\n%s\n%s\n' "$pi" "$bound" "$claude" | grep -F "$forbidden" >/dev/null; then
    fail "serialized private trace content"
  fi
done

if "$CLI" --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --capability diagnose_shadow --json >"$TMP/out" 2>"$TMP/err"; then
  fail "accepted unavailable capability"
fi
test ! -s "$TMP/out" || fail "capability failure wrote stdout"
test "$(cat "$TMP/err")" = 'harness-trace-retrospect:capability_not_available' || fail "capability error leaked detail"

ln -s "$FIX/pi/session.jsonl" "$TMP/session-link.jsonl"
symlink_input="$($CLI --adapter pi --trace-file "$TMP/session-link.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["input_symlink_rejected"] and .decision == null' <<<"$symlink_input" >/dev/null

mkfifo "$TMP/input.fifo"
special_input="$($CLI --adapter pi --trace-file "$TMP/input.fifo" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["input_not_regular"] and .decision == null' <<<"$special_input" >/dev/null

cp "$FIX/pi/session.jsonl" "$TMP/mutable.jsonl"
ROOT_FOR_NODE="$ROOT" MUTABLE_FOR_NODE="$TMP/mutable.jsonl" node --input-type=module <<'NODE'
import { appendFileSync } from "node:fs";
const { readBoundedRegularFile, TraceRetrospectError } = await import(`${process.env.ROOT_FOR_NODE}/scripts/lib/harness-trace-retrospect.mjs`);
try {
  readBoundedRegularFile(process.env.MUTABLE_FOR_NODE, { afterRead: () => appendFileSync(process.env.MUTABLE_FOR_NODE, " ") });
  process.exit(1);
} catch (error) {
  if (!(error instanceof TraceRetrospectError) || error.code !== "input_changed") process.exit(2);
}
NODE

cp "$FIX/pi/session.jsonl" "$TMP/unknown.jsonl"
printf '%s\n' '{"type":"future_private_shape","id":"unknown","parentId":"c","timestamp":"2026-09-20T10:03:30Z","payload":"must not leak"}' >>"$TMP/unknown.jsonl"
unknown="$($CLI --adapter pi --trace-file "$TMP/unknown.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"] and .decision == null and .jev_state == null' <<<"$unknown" >/dev/null
grep -F 'must not leak' <<<"$unknown" >/dev/null && fail "unknown row leaked"

cp "$FIX/pi/session.jsonl" "$TMP/partial.jsonl"
printf '%s\n' '{"type":"label_change","id":"label","parentId":"c","timestamp":"2026-09-20T10:03:30Z","label":"private"}' >>"$TMP/partial.jsonl"
partial="$($CLI --adapter pi --trace-file "$TMP/partial.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "partial" and .signals.unsupported_rows == 1 and .decision.action == "no_op" and .decision.category == "incomplete_evidence" and (.jev_state.evidence | contains("complete=false"))' <<<"$partial" >/dev/null

cp "$FIX/claude/session.jsonl" "$TMP/claude-partial.jsonl"
printf '%s\n' '{"type":"system","subtype":"init","uuid":"claude-system-1","parentUuid":"claude-tool-1","model":"private-model","sessionId":"claude-private-session","timestamp":"2026-09-20T11:03:00Z"}' >>"$TMP/claude-partial.jsonl"
claude_partial="$($CLI --adapter claude --trace-file "$TMP/claude-partial.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "partial" and .signals.unsupported_rows == 1 and .decision.action == "no_op"' <<<"$claude_partial" >/dev/null

sed 's/"route":"plan-implement"/"route":"review"/' "$FIX/pi/session.jsonl" >"$TMP/route-mismatch.jsonl"
route_mismatch="$($CLI --adapter pi --trace-file "$TMP/route-mismatch.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_route_mismatch"] and .decision == null' <<<"$route_mismatch" >/dev/null

sed 's/"route":"plan-implement"/"route":"implement"/' "$FIX/pi/session.jsonl" >"$TMP/route-continuation.jsonl"
route_continuation="$($CLI --adapter pi --trace-file "$TMP/route-continuation.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete" and .reason_codes == []' <<<"$route_continuation" >/dev/null

grep -v '"event":"plan_created"' "$FIX/pi/events.jsonl" >"$TMP/route-no-plan.jsonl"
route_no_plan="$($CLI --adapter pi --trace-file "$TMP/route-continuation.jsonl" --ledger "$TMP/route-no-plan.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_route_mismatch"]' <<<"$route_no_plan" >/dev/null

sed 's/"status":"READY"/"status":"DRAFT"/' "$FIX/pi/events.jsonl" >"$TMP/route-draft-plan.jsonl"
route_draft_plan="$($CLI --adapter pi --trace-file "$TMP/route-continuation.jsonl" --ledger "$TMP/route-draft-plan.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_route_mismatch"]' <<<"$route_draft_plan" >/dev/null

sed 's/"status":"READY"/"status":"CHALLENGED"/' "$FIX/pi/events.jsonl" >"$TMP/route-challenged-plan.jsonl"
route_challenged_plan="$($CLI --adapter pi --trace-file "$TMP/route-continuation.jsonl" --ledger "$TMP/route-challenged-plan.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_route_mismatch"]' <<<"$route_challenged_plan" >/dev/null

sed -E 's/"timestamp":"[^"]+"/"timestamp":0/g' "$FIX/pi/session.jsonl" >"$TMP/pi-numeric-time.jsonl"
pi_numeric_time="$($CLI --adapter pi --trace-file "$TMP/pi-numeric-time.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_window_mismatch"] and .decision == null' <<<"$pi_numeric_time" >/dev/null

sed -E 's/"timestamp":"[^"]+"/"timestamp":null/g' "$FIX/claude/session.jsonl" >"$TMP/claude-null-time.jsonl"
claude_null_time="$($CLI --adapter claude --trace-file "$TMP/claude-null-time.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_window_mismatch"] and .decision == null' <<<"$claude_null_time" >/dev/null

sed -E 's/"ts":"[^"]+"/"ts":0/g' "$FIX/pi/events.jsonl" >"$TMP/numeric-ledger-time.jsonl"
numeric_ledger_time="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/numeric-ledger-time.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_time_invalid"] and .decision == null' <<<"$numeric_ledger_time" >/dev/null

sed -E 's/2026-09-20/2026-02-30/g' "$FIX/pi/session.jsonl" >"$TMP/pi-impossible-day.jsonl"
pi_impossible_day="$($CLI --adapter pi --trace-file "$TMP/pi-impossible-day.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_window_mismatch"] and .decision == null' <<<"$pi_impossible_day" >/dev/null

sed -E 's/2026-09-20/2026-02-29/g' "$FIX/claude/session.jsonl" >"$TMP/claude-non-leap-day.jsonl"
claude_non_leap_day="$($CLI --adapter claude --trace-file "$TMP/claude-non-leap-day.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_window_mismatch"] and .decision == null' <<<"$claude_non_leap_day" >/dev/null

sed -E 's/2026-09-20/2026-09-31/g' "$FIX/pi/events.jsonl" >"$TMP/impossible-ledger-day.jsonl"
impossible_ledger_day="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/impossible-ledger-day.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_time_invalid"] and .decision == null' <<<"$impossible_ledger_day" >/dev/null

sed -n '1,3p' "$FIX/pi/events.jsonl" >"$TMP/non-terminal.jsonl"
non_terminal="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/non-terminal.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_not_terminal"] and .decision == null' <<<"$non_terminal" >/dev/null

sed -n '1,2p' "$FIX/pi/session.jsonl" >"$TMP/truncated-pi-prefix.jsonl"
truncated_pi="$($CLI --adapter pi --trace-file "$TMP/truncated-pi-prefix.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_primary_shape_missing"] and .decision == null' <<<"$truncated_pi" >/dev/null

sed -n '1p' "$FIX/claude/session.jsonl" >"$TMP/truncated-claude-prefix.jsonl"
truncated_claude="$($CLI --adapter claude --trace-file "$TMP/truncated-claude-prefix.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_primary_shape_missing"] and .decision == null' <<<"$truncated_claude" >/dev/null

cp "$FIX/pi/session.jsonl" "$TMP/window-mismatch.jsonl"
printf '%s\n' '{"type":"model_change","id":"late-model","parentId":"c","timestamp":"2026-09-20T10:06:00Z","provider":"private","modelId":"private"}' >>"$TMP/window-mismatch.jsonl"
window_mismatch="$($CLI --adapter pi --trace-file "$TMP/window-mismatch.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_window_mismatch"] and .decision == null' <<<"$window_mismatch" >/dev/null

cp "$FIX/pi/session.jsonl" "$TMP/fork.jsonl"
printf '%s\n' '{"type":"message","id":"fork","parentId":"a","timestamp":"2026-09-20T10:03:30Z","message":{"role":"user","content":"private branch"}}' >>"$TMP/fork.jsonl"
forked="$($CLI --adapter pi --trace-file "$TMP/fork.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_branch_ambiguous"]' <<<"$forked" >/dev/null

cp "$FIX/pi/session.jsonl" "$TMP/tool-conflict.jsonl"
printf '%s\n' '{"type":"message","id":"late","parentId":"c","timestamp":"2026-09-20T10:03:30Z","message":{"role":"toolResult","toolCallId":"missing","toolName":"bash","content":[],"isError":false}}' >>"$TMP/tool-conflict.jsonl"
conflict="$($CLI --adapter pi --trace-file "$TMP/tool-conflict.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_tool_conflict"]' <<<"$conflict" >/dev/null

sed 's/"toolName":"bash"/"toolName":"other"/' "$FIX/pi/session.jsonl" >"$TMP/tool-name-conflict.jsonl"
name_conflict="$($CLI --adapter pi --trace-file "$TMP/tool-name-conflict.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_tool_conflict"]' <<<"$name_conflict" >/dev/null

{
  sed -n '1p' "$FIX/claude/session.jsonl"
  sed -n '3p' "$FIX/claude/session.jsonl"
  sed -n '2p' "$FIX/claude/session.jsonl"
} >"$TMP/claude-reversed-tools.jsonl"
reversed_tools="$($CLI --adapter claude --trace-file "$TMP/claude-reversed-tools.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_branch_ambiguous"]' <<<"$reversed_tools" >/dev/null

cp "$FIX/claude/session.jsonl" "$TMP/claude-duplicate-row.jsonl"
sed -n '2p' "$FIX/claude/session.jsonl" >>"$TMP/claude-duplicate-row.jsonl"
duplicate_claude="$($CLI --adapter claude --trace-file "$TMP/claude-duplicate-row.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_identity_unknown"] and .decision == null' <<<"$duplicate_claude" >/dev/null

cp "$FIX/claude/session.jsonl" "$TMP/claude-fork.jsonl"
printf '%s\n' '{"type":"assistant","uuid":"claude-assistant-fork","parentUuid":"claude-user-1","sessionId":"claude-private-session","timestamp":"2026-09-20T11:01:30Z","message":{"role":"assistant","content":"private branch","usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}}' >>"$TMP/claude-fork.jsonl"
forked_claude="$($CLI --adapter claude --trace-file "$TMP/claude-fork.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_branch_ambiguous"] and .decision == null' <<<"$forked_claude" >/dev/null

sed '1s/"type":"user"/"type":"user","isSidechain":"true"/' "$FIX/claude/session.jsonl" >"$TMP/claude-invalid-sidechain.jsonl"
invalid_sidechain="$($CLI --adapter claude --trace-file "$TMP/claude-invalid-sidechain.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_identity_unknown"] and .decision == null' <<<"$invalid_sidechain" >/dev/null

sed '2s/"role":"assistant"/"role":"user"/' "$FIX/claude/session.jsonl" >"$TMP/claude-role-conflict.jsonl"
role_conflict="$($CLI --adapter claude --trace-file "$TMP/claude-role-conflict.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_primary_shape_missing"] and .decision == null' <<<"$role_conflict" >/dev/null

sed 's/"type":"text","text":"private prompt response"/"type":"future_tool","text":"private prompt response"/' "$FIX/pi/session.jsonl" >"$TMP/unknown-content.jsonl"
unknown_content="$($CLI --adapter pi --trace-file "$TMP/unknown-content.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"] and .decision == null' <<<"$unknown_content" >/dev/null

cp "$FIX/pi/session.jsonl" "$TMP/tool-incomplete.jsonl"
printf '%s\n' '{"type":"message","id":"unanswered","parentId":"c","timestamp":"2026-09-20T10:03:30Z","message":{"role":"assistant","content":[{"type":"toolCall","id":"tool-unanswered","name":"bash","arguments":{}}],"usage":{"input":1,"output":1,"totalTokens":2}}}' >>"$TMP/tool-incomplete.jsonl"
incomplete="$($CLI --adapter pi --trace-file "$TMP/tool-incomplete.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_tool_incomplete"] and .decision == null' <<<"$incomplete" >/dev/null

sed '2s/"sessionId":"claude-private-session",//' "$FIX/claude/session.jsonl" >"$TMP/claude-missing-session.jsonl"
missing_session="$($CLI --adapter claude --trace-file "$TMP/claude-missing-session.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_identity_unknown"] and .decision == null' <<<"$missing_session" >/dev/null

sed 's/"is_error":false/"is_error":"true"/' "$FIX/claude/session.jsonl" >"$TMP/claude-invalid-error.jsonl"
invalid_error="$($CLI --adapter claude --trace-file "$TMP/claude-invalid-error.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"] and .decision == null' <<<"$invalid_error" >/dev/null

cp "$FIX/pi/events.jsonl" "$TMP/unknown-ledger.jsonl"
printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:30Z","event":"future_decision_event","run":"pi-run","detail":{"value":"private"}}' >>"$TMP/unknown-ledger.jsonl"
unknown_ledger="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/unknown-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"] and .decision == null and .jev_state == null' <<<"$unknown_ledger" >/dev/null

{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:30Z","event":"outcome_metric","run":"pi-run","detail":{"unexpected":"private malformed shape"}}'
  sed -n '5p' "$FIX/pi/events.jsonl"
} >"$TMP/secondary-ledger-event.jsonl"
secondary_ledger="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/secondary-ledger-event.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"] and .decision == null and .jev_state == null' <<<"$secondary_ledger" >/dev/null
grep -F 'private malformed shape' <<<"$secondary_ledger" >/dev/null && fail "secondary ledger detail leaked"

{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:30Z","event":"review_completed","run":"pi-run","detail":{}}'
  sed -n '5p' "$FIX/pi/events.jsonl"
} >"$TMP/malformed-ledger-detail.jsonl"
malformed_detail="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/malformed-ledger-detail.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"] and .decision == null' <<<"$malformed_detail" >/dev/null

{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:30Z","event":"review_completed","run":"pi-run","detail":{"status":"GO","evidence":[{"private":"invalid"}]}}'
  sed -n '5p' "$FIX/pi/events.jsonl"
} >"$TMP/malformed-review-evidence.jsonl"
malformed_review="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/malformed-review-evidence.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"] and .decision == null' <<<"$malformed_review" >/dev/null

sed 's/"exit":0/"exit":0,"unexpected":"drift"/' "$FIX/pi/events.jsonl" >"$TMP/extra-ledger-detail.jsonl"
extra_ledger_detail="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/extra-ledger-detail.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"] and .decision == null' <<<"$extra_ledger_detail" >/dev/null

{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:05:00Z","event":"completed","run":"pi-run","detail":{}}'
} >"$TMP/incomplete-terminal-detail.jsonl"
incomplete_terminal="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/incomplete-terminal-detail.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"] and .decision == null' <<<"$incomplete_terminal" >/dev/null

{
  sed -n '1,2p' "$FIX/claude/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T11:04:00Z","event":"blocked","run":"claude-run","detail":{"reason":"fixture blocker","needed_input":"fixture input"}}'
} >"$TMP/blocked-ledger.jsonl"
blocked_episode="$($CLI --adapter claude --trace-file "$FIX/claude/session.jsonl" --ledger "$TMP/blocked-ledger.jsonl" --run claude-run --json)"
jq -e '.completeness == "complete" and .lifecycle == {terminal:true,outcome:"blocked"} and (.jev_state.evidence | contains("terminal=blocked"))' <<<"$blocked_episode" >/dev/null

sed 's/,"needed_input":"fixture input"//' "$TMP/blocked-ledger.jsonl" >"$TMP/incomplete-blocked-ledger.jsonl"
incomplete_blocked="$($CLI --adapter claude --trace-file "$FIX/claude/session.jsonl" --ledger "$TMP/incomplete-blocked-ledger.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"] and .decision == null' <<<"$incomplete_blocked" >/dev/null

{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:30Z","event":"validation_failed","run":"pi-run","detail":{"command":"private validation command","exit":1,"failure":"late failure"}}'
  sed -n '5p' "$FIX/pi/events.jsonl"
} >"$TMP/stale-verifier-ledger.jsonl"
stale_verifier="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/stale-verifier-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete" and .signals.verifier == false and (.jev_state.evidence | endswith("verifier=false"))' <<<"$stale_verifier" >/dev/null

{
  sed -n '1,2p' "$FIX/pi/events.jsonl"
  sed -n '2,5p' "$FIX/pi/events.jsonl"
} >"$TMP/duplicate-ledger-event.jsonl"
duplicate_ledger="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/duplicate-ledger-event.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_event_conflict"] and .decision == null and .jev_state == null' <<<"$duplicate_ledger" >/dev/null

{
  sed -n '2p' "$FIX/pi/events.jsonl"
  sed -n '1p;3,5p' "$FIX/pi/events.jsonl"
} >"$TMP/pre-route-ledger.jsonl"
# Route-second position is legal since tranche 3 (router appends to a seeded
# ledger); this fixture still fails, now honestly on its inverted clock.
pre_route="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/pre-route-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_time_conflict"] and .decision == null' <<<"$pre_route" >/dev/null

# Tranche 3: route_decided additive contract fields + later route changes.
jq -c '.detail += {contract_path:"/tmp/x/SKILL.md",contract_sha256:"f2a1",provenance:"repo"}' <<<"$(sed -n '1p' "$FIX/pi/events.jsonl")" >"$TMP/additive-route.jsonl"
sed -n '2,5p' "$FIX/pi/events.jsonl" >>"$TMP/additive-route.jsonl"
additive_route="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/additive-route.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete"' <<<"$additive_route" >/dev/null

{
  sed -n '1,2p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:01:00Z","event":"route_decided","run":"pi-run","detail":{"route":"implement","reason":"router change","contract_path":"/tmp/y/SKILL.md","contract_sha256":"b3c2","provenance":"repo"}}'
  sed -n '3,5p' "$FIX/pi/events.jsonl"
} >"$TMP/route-change-ledger.jsonl"
route_change="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/route-change-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete"' <<<"$route_change" >/dev/null

{
  sed -n '1,2p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:00:30Z","event":"route_decided","run":"pi-run","detail":{"route":"plan-implement","reason":"router rescan"}}'
  sed -n '3,5p' "$FIX/pi/events.jsonl"
} >"$TMP/duplicate-route-ledger.jsonl"
duplicate_route="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/duplicate-route-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete"' <<<"$duplicate_route" >/dev/null

# Same-second concurrent exact dupes (byte-identical route_decided lines) are
# valid and harmless per AC2: collapsed before the conflict check.
{
  sed -n '1p' "$FIX/pi/events.jsonl"
  sed -n '1p' "$FIX/pi/events.jsonl"
  sed -n '2,5p' "$FIX/pi/events.jsonl"
} >"$TMP/exact-dupe-ledger.jsonl"
exact_dupe="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/exact-dupe-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete"' <<<"$exact_dupe" >/dev/null

jq -c '.detail += {contract_path:"/tmp/x/SKILL.md",provenance:"bogus"}' <<<"$(sed -n '1p' "$FIX/pi/events.jsonl")" >"$TMP/bad-additive-route.jsonl"
sed -n '2,5p' "$FIX/pi/events.jsonl" >>"$TMP/bad-additive-route.jsonl"
bad_additive="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/bad-additive-route.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"]' <<<"$bad_additive" >/dev/null

# Tranche 4: quality_completed accepted (pass/unavailable), bad status rejected.
{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:30Z","event":"quality_completed","run":"pi-run","detail":{"status":"pass","evidence":"code-quality"}}'
  sed -n '5p' "$FIX/pi/events.jsonl"
} >"$TMP/quality-ledger.jsonl"
quality_ok="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/quality-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete"' <<<"$quality_ok" >/dev/null
{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:30Z","event":"quality_completed","run":"pi-run","detail":{"status":"clean","evidence":"x"}}'
  sed -n '5p' "$FIX/pi/events.jsonl"
} >"$TMP/quality-bad-ledger.jsonl"
quality_bad="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/quality-bad-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"]' <<<"$quality_bad" >/dev/null

# Tranche 4: adversary model_provenance complete accepted, partial rejected.
{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:45Z","event":"adversary_completed","run":"pi-run","detail":{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[],"model_provenance":{"requested":{"family":"openai","model":"gpt-6-astra","provider":"codex"},"effective":{"family":"openai","model":"gpt-6-astra","provider":"codex"},"runner":"codex-cli","run_id":"r1"}}}'
  sed -n '5p' "$FIX/pi/events.jsonl"
} >"$TMP/prov-ledger.jsonl"
prov_ok="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/prov-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete"' <<<"$prov_ok" >/dev/null
{
  sed -n '1,4p' "$FIX/pi/events.jsonl"
  printf '%s\n' '{"schema_version":2,"ts":"2026-09-20T10:04:45Z","event":"adversary_completed","run":"pi-run","detail":{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[],"model_provenance":{"requested":{"family":"openai","model":"gpt-6-astra","provider":"codex"},"runner":"codex-cli","run_id":"r1"}}}'
  sed -n '5p' "$FIX/pi/events.jsonl"
} >"$TMP/prov-bad-ledger.jsonl"
prov_bad="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/prov-bad-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"]' <<<"$prov_bad" >/dev/null

# Tranche 3 Codex MED1: first route row after a seeded line is complete.
{
  jq -c '.ts = "2026-09-20T09:58:00Z"' <<<"$(sed -n '2p' "$FIX/pi/events.jsonl")"
  sed -n '1p;3,5p' "$FIX/pi/events.jsonl"
} >"$TMP/route-second-ledger.jsonl"
route_second="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/route-second-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "complete"' <<<"$route_second" >/dev/null

# ...but a bad route detail still fails wherever the route row sits.
{
  jq -c '.ts = "2026-09-20T09:58:00Z"' <<<"$(sed -n '2p' "$FIX/pi/events.jsonl")"
  jq -c '.detail += {provenance:"bogus"}' <<<"$(sed -n '1p' "$FIX/pi/events.jsonl")"
  sed -n '3,5p' "$FIX/pi/events.jsonl"
} >"$TMP/bad-route-second-ledger.jsonl"
bad_route_second="$($CLI --adapter pi --trace-file "$FIX/pi/session.jsonl" --ledger "$TMP/bad-route-second-ledger.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["ledger_shape_unknown"]' <<<"$bad_route_second" >/dev/null

sed 's/,"firstKeptEntryId":"a"//' "$FIX/pi/session.jsonl" >"$TMP/malformed-compaction.jsonl"
malformed_compaction="$($CLI --adapter pi --trace-file "$TMP/malformed-compaction.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"] and .decision == null' <<<"$malformed_compaction" >/dev/null

sed 's/"firstKeptEntryId":"a"/"retainedTail":[]/' "$FIX/pi/session.jsonl" >"$TMP/empty-retained-tail.jsonl"
empty_retained_tail="$($CLI --adapter pi --trace-file "$TMP/empty-retained-tail.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"] and .decision == null' <<<"$empty_retained_tail" >/dev/null

sed 's/"firstKeptEntryId":"a"/"firstKeptEntryId":"missing"/' "$FIX/pi/session.jsonl" >"$TMP/dangling-compaction-id.jsonl"
dangling_compaction="$($CLI --adapter pi --trace-file "$TMP/dangling-compaction-id.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"] and .decision == null' <<<"$dangling_compaction" >/dev/null

sed 's/"firstKeptEntryId":"a"/"firstKeptEntryId":"pi-private-session"/' "$FIX/pi/session.jsonl" >"$TMP/session-header-compaction-id.jsonl"
header_compaction="$($CLI --adapter pi --trace-file "$TMP/session-header-compaction-id.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"] and .decision == null' <<<"$header_compaction" >/dev/null

sed 's/"content":"private output"/"content":[{"type":"image"}]/' "$FIX/claude/session.jsonl" >"$TMP/malformed-claude-image.jsonl"
malformed_image="$($CLI --adapter claude --trace-file "$TMP/malformed-claude-image.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["trace_shape_unknown"] and .decision == null' <<<"$malformed_image" >/dev/null

printf '%s\n' '{"type":"session","id":"x","timestamp":"2026-09-20T10:00:00Z"}' '{broken' >"$TMP/malformed.jsonl"
malformed="$($CLI --adapter pi --trace-file "$TMP/malformed.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["input_json_malformed"]' <<<"$malformed" >/dev/null

head -c 4194305 /dev/zero >"$TMP/oversized.jsonl"
oversized="$($CLI --adapter pi --trace-file "$TMP/oversized.jsonl" --ledger "$FIX/pi/events.jsonl" --run pi-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["input_too_large"] and .decision == null' <<<"$oversized" >/dev/null

ROW_CAP_PATH="$TMP/row-cap.jsonl" node --input-type=module <<'NODE'
import { writeFileSync } from "node:fs";
writeFileSync(process.env.ROW_CAP_PATH, `${'{"type":"system","sessionId":"x","timestamp":"2026-09-20T11:00:00Z"}\n'.repeat(20_001)}`);
NODE
row_cap="$($CLI --adapter claude --trace-file "$TMP/row-cap.jsonl" --ledger "$FIX/claude/events.jsonl" --run claude-run --json)"
jq -e '.completeness == "unavailable" and .reason_codes == ["input_row_cap"] and .decision == null' <<<"$row_cap" >/dev/null

PI_OUTPUT="$pi" ROOT_FOR_NODE="$ROOT" node --input-type=module <<'NODE'
const { prepareProfileRequest, loadSemanticProfilePolicy } = await import(`${process.env.ROOT_FOR_NODE}/pi/extensions/lib/semantic-profiles.mjs`);
const state = JSON.parse(process.env.PI_OUTPUT).jev_state;
const request = prepareProfileRequest("self-improvement-candidate", state, { policy: loadSemanticProfilePolicy() });
if (JSON.stringify(request.state) !== JSON.stringify(state)) process.exit(1);
NODE

printf 'harness-trace-retrospect-smoke: ok\n'
