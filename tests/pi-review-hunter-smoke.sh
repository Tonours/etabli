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
printf '%s\n' "$out" | grep -Fx -- '--mode' >/dev/null || fail "expected --mode in argv"
printf '%s\n' "$out" | grep -Fx -- 'text' >/dev/null || fail "expected text mode in argv"
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

review_md="$ROOT_DIR/workflow/skills/review.md"
pi_review="$ROOT_DIR/pi/skills/review/SKILL.md"
for pin in --no-session --no-skills --no-extensions --no-context-files read,grep '--mode text'; do
  grep -Fq -- "$pin" "$review_md" || fail "workflow/skills/review.md missing argv pin $pin"
  grep -Fq -- "$pin" "$pi_review" || fail "pi/skills/review/SKILL.md missing argv pin $pin"
done

printf 'pi-review-hunter smoke test: ok\n'
