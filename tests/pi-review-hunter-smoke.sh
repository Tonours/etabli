#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HELPER="$ROOT_DIR/scripts/pi-review-hunter"

fail() {
  printf 'pi-review-hunter-smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$HELPER" ] || fail "scripts/pi-review-hunter must be executable. Remediation: chmod +x scripts/pi-review-hunter"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

PROMPT_FILE="$TMP_DIR/prompt.md"
PATCH_FILE="$TMP_DIR/patch.diff"
printf 'Axis: Logic\n' >"$PROMPT_FILE"
printf 'diff --git a/x b/x\n+ok\n' >"$PATCH_FILE"

# --print-argv must work without GNU timeout, pi, or a leaked timeout env var.
out="$(env -u PI_REVIEW_HUNTER_TIMEOUT PATH=/usr/bin:/bin "$HELPER" --print-argv --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --model 'cursor/claude-opus-5-5@300k')"

printf '%s\n' "$out" | grep -Fx -- '--no-session' >/dev/null || fail "expected --no-session in argv"
printf '%s\n' "$out" | grep -Fx -- '-p' >/dev/null || fail "expected -p in argv"
printf '%s\n' "$out" | grep -Fx -- '--append-system-prompt' >/dev/null || fail "expected --append-system-prompt in argv"
printf '%s\n' "$out" | grep -Fx -- "$PROMPT_FILE" >/dev/null || fail "expected prompt file in argv"
printf '%s\n' "$out" | grep -Fx -- '--no-skills' >/dev/null || fail "expected --no-skills in argv"
printf '%s\n' "$out" | grep -Fx -- '--no-extensions' >/dev/null || fail "expected --no-extensions in argv"
printf '%s\n' "$out" | grep -Fx -- '--no-context-files' >/dev/null || fail "expected --no-context-files in argv"
printf '%s\n' "$out" | grep -Fx -- 'read,grep' >/dev/null || fail "expected read,grep tools in argv"
printf '%s\n' "$out" | grep -Fq -- "@${PATCH_FILE}" || fail "expected @patch transport in argv"
printf '%s\n' "$out" | grep -Eq '^TIMEOUT=600$' || fail "expected TIMEOUT=600 header"
if printf '%s\n' "$out" | grep -Fq -- '--model'; then
  fail "cursor/ model must be omitted from argv"
fi

bad_timeout_rc=0
PATH=/usr/bin:/bin "$HELPER" --print-argv --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --timeout abc >/dev/null 2>"$TMP_DIR/bad-timeout.err" || bad_timeout_rc=$?
[ "$bad_timeout_rc" -eq 2 ] || fail "non-integer --timeout must exit 2"
grep -Fq 'timeout must be a positive integer' "$TMP_DIR/bad-timeout.err" || fail "non-integer --timeout must print a diagnostic"

empty_patch="$TMP_DIR/empty.diff"
: >"$empty_patch"
empty_rc=0
PATH=/usr/bin:/bin "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$empty_patch" >/dev/null 2>"$TMP_DIR/empty-patch.err" || empty_rc=$?
[ "$empty_rc" -eq 2 ] || fail "empty patch must exit 2"
grep -Fq 'empty patch is not a clean hunt' "$TMP_DIR/empty-patch.err" || fail "empty patch must print a diagnostic"

missing_pi_rc=0
PATH=/usr/bin:/bin "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" >/dev/null 2>"$TMP_DIR/missing-pi.err" || missing_pi_rc=$?
[ "$missing_pi_rc" -eq 2 ] || fail "missing pi must exit 2"
grep -Fq 'pi not on PATH' "$TMP_DIR/missing-pi.err" || fail "missing pi must print HUNTER_SPAWN_UNAVAILABLE"

out_model="$("$HELPER" --print-argv --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --model 'zai/glm-5.3')"
printf '%s\n' "$out_model" | grep -Fx -- '--model' >/dev/null || fail "non-cursor model must be passed"
printf '%s\n' "$out_model" | grep -Fx -- 'zai/glm-5.3' >/dev/null || fail "expected resolved model id"

# Real wrapper, fake pi: the final text reaches stdout; empty or slow runs fail.
mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/pi" <<'FAKE'
#!/usr/bin/env bash
case "${FAKE_PI:-ok}" in
  ok) printf 'GO\n' ;;
  empty) : ;;
  slow) sleep 5 ;;
  killwatch) pkill -KILL -f "^perl .* $$\$"; sleep 2; printf 'GO\n' ;;
esac
FAKE
chmod +x "$TMP_DIR/bin/pi"
ok_out="$(PATH="$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" 2>"$TMP_DIR/ok.err")"
[ "$ok_out" = "GO" ] || fail "final report must reach stdout"
[ ! -s "$TMP_DIR/ok.err" ] || fail "a finished run must keep stderr empty, got: $(cat "$TMP_DIR/ok.err")"
ignored_rc=0
ignored_out="$(trap '' TERM; PATH="$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --timeout 2)" || ignored_rc=$?
[ "$ignored_rc" -eq 0 ] && [ "$ignored_out" = "GO" ] || fail "a finished run under an ignored TERM must not time out, got $ignored_rc"
PATH="$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --timeout 7351 >/dev/null
sleep 0.2
if pgrep -f '(^| )7351( |$)' >/dev/null; then
  pkill -f '(^| )7351( |$)'
  fail "a finished run must not leave its watchdog sleep behind"
fi
empty_rc=0
FAKE_PI=empty PATH="$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" >/dev/null 2>&1 || empty_rc=$?
[ "$empty_rc" -eq 2 ] || fail "empty report must exit 2"
slow_rc=0
FAKE_PI=slow PATH="$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --timeout 1 >/dev/null 2>&1 || slow_rc=$?
[ "$slow_rc" -eq 3 ] || fail "timeout must exit 3, got $slow_rc"
mkdir -p "$TMP_DIR/broken-perl"
printf '#!/bin/sh\nexit 127\n' >"$TMP_DIR/broken-perl/perl"
chmod +x "$TMP_DIR/broken-perl/perl"
broken_rc=0
PATH="$TMP_DIR/broken-perl:$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" >/dev/null 2>&1 || broken_rc=$?
[ "$broken_rc" -eq 3 ] || fail "a failed watchdog must not accept the report, got $broken_rc"
killed_rc=0
FAKE_PI=killwatch PATH="$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --timeout 1 >/dev/null 2>&1 || killed_rc=$?
[ "$killed_rc" -eq 3 ] || fail "a watchdog killed by someone else must not accept the report, got $killed_rc"

printf 'pi-review-hunter smoke test: ok\n'
