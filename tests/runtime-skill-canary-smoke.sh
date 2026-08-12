#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="$TMP_DIR/home"
mkdir -p "$HOME_DIR/.agents/skills" "$TMP_DIR/bin"
ln -s "$ROOT_DIR/pi/skills/runtime-skill-canary" "$HOME_DIR/.agents/skills/runtime-skill-canary"

"$ROOT_DIR/scripts/runtime-skill-canary" --repo "$ROOT_DIR" --home "$HOME_DIR" --json >"$TMP_DIR/offline.json"
jq -e '
  .status == "offline_passed" and
  .source_locked.passed == true and
  .source_locked.lock_declared == true and
  .source_locked.lock_matches == true and
  .source_locked.source_sha256 == .source_locked.expected_sha256 and
  (.source_locked.source_sha256 | test("^[0-9a-f]{64}$")) and
  .link_valid == {"passed":true,"state":"valid","surface":"agents_visible"} and
  ([.runtime_invoked[].state] | all(. == "skipped"))
' "$TMP_DIR/offline.json" >/dev/null

if "$ROOT_DIR/scripts/runtime-skill-canary" --repo "$ROOT_DIR" --home "$HOME_DIR" --live >"$TMP_DIR/no-opt-in.json"; then
  printf 'live canary without explicit opt-in should not pass\n' >&2
  exit 1
else
  [ "$?" -eq 3 ] || { printf 'live canary without opt-in should exit 3\n' >&2; exit 1; }
fi
jq -e '.status == "live_skipped" and ([.runtime_invoked[].state] | all(. == "skipped"))' "$TMP_DIR/no-opt-in.json" >/dev/null

cat >"$TMP_DIR/bin/pass" <<'SH'
#!/usr/bin/env sh
printf '%s\n' 'ETABLI_RUNTIME_SKILL_CANARY_V1_7F3C9A'
SH
cat >"$TMP_DIR/bin/fail" <<'SH'
#!/usr/bin/env sh
printf '%s\n' 'WRONG_CANARY'
SH
cat >"$TMP_DIR/bin/unknown" <<'SH'
#!/usr/bin/env sh
exit 42
SH
chmod +x "$TMP_DIR/bin/pass" "$TMP_DIR/bin/fail" "$TMP_DIR/bin/unknown"

ETABLI_CANARY_CODEX_BIN="$TMP_DIR/bin/pass" \
ETABLI_CANARY_PI_BIN="$TMP_DIR/bin/pass" \
ETABLI_CANARY_CLAUDE_BIN="$TMP_DIR/bin/pass" \
ETABLI_CANARY_GROK_BIN="$TMP_DIR/bin/pass" \
RUN_SKILL_RUNTIME_CANARY=1 \
  "$ROOT_DIR/scripts/runtime-skill-canary" --repo "$ROOT_DIR" --home "$HOME_DIR" --live >"$TMP_DIR/live-pass.json"
jq -e '.status == "live_passed" and ([.runtime_invoked[].state] | all(. == "passed"))' "$TMP_DIR/live-pass.json" >/dev/null

if ETABLI_CANARY_CODEX_BIN="$TMP_DIR/bin/pass" \
  ETABLI_CANARY_PI_BIN="$TMP_DIR/bin/pass" \
  ETABLI_CANARY_CLAUDE_BIN="$TMP_DIR/bin/pass" \
  ETABLI_CANARY_GROK_BIN="$TMP_DIR/bin/fail" \
  RUN_SKILL_RUNTIME_CANARY=1 \
    "$ROOT_DIR/scripts/runtime-skill-canary" --repo "$ROOT_DIR" --home "$HOME_DIR" --live >"$TMP_DIR/live-fail.json"; then
  printf 'wrong live canary response should fail\n' >&2
  exit 1
else
  [ "$?" -eq 1 ] || { printf 'wrong live canary response should exit 1\n' >&2; exit 1; }
fi
jq -e '.status == "live_failed" and .runtime_invoked.grok.state == "failed"' "$TMP_DIR/live-fail.json" >/dev/null

if ETABLI_CANARY_CODEX_BIN="$TMP_DIR/bin/pass" \
  ETABLI_CANARY_PI_BIN="$TMP_DIR/bin/pass" \
  ETABLI_CANARY_CLAUDE_BIN="$TMP_DIR/bin/pass" \
  ETABLI_CANARY_GROK_BIN="$TMP_DIR/bin/unknown" \
  RUN_SKILL_RUNTIME_CANARY=1 \
    "$ROOT_DIR/scripts/runtime-skill-canary" --repo "$ROOT_DIR" --home "$HOME_DIR" --live >"$TMP_DIR/live-unknown.json"; then
  printf 'unknown live runtime should not pass\n' >&2
  exit 1
else
  [ "$?" -eq 3 ] || { printf 'unknown live runtime should exit 3\n' >&2; exit 1; }
fi
jq -e '.status == "live_partial" and .runtime_invoked.grok == {"state":"unknown","reason":"exit_42"}' "$TMP_DIR/live-unknown.json" >/dev/null

LOCK_REPO="$TMP_DIR/lock-repo"
mkdir -p "$LOCK_REPO/workflow/runtime" "$LOCK_REPO/pi/skills"
cp "$ROOT_DIR/workflow/runtime/skill-surface.tsv" "$LOCK_REPO/workflow/runtime/skill-surface.tsv"
cp -R "$ROOT_DIR/pi/skills/runtime-skill-canary" "$LOCK_REPO/pi/skills/runtime-skill-canary"
jq '.skills["runtime-skill-canary"].computedHash = "0000000000000000000000000000000000000000000000000000000000000000"' \
  "$ROOT_DIR/skills-lock.json" >"$LOCK_REPO/skills-lock.json"
ln -sfn "$LOCK_REPO/pi/skills/runtime-skill-canary" "$HOME_DIR/.agents/skills/runtime-skill-canary"
if "$ROOT_DIR/scripts/runtime-skill-canary" --repo "$LOCK_REPO" --home "$HOME_DIR" >"$TMP_DIR/stale-lock.json"; then
  printf 'stale skill lock should fail source_locked proof\n' >&2
  exit 1
fi
jq -e '.status == "offline_failed" and .source_locked.passed == false and .source_locked.lock_matches == false' "$TMP_DIR/stale-lock.json" >/dev/null

ln -sfn "$ROOT_DIR/pi/skills/recurring-run" "$HOME_DIR/.agents/skills/runtime-skill-canary"
if "$ROOT_DIR/scripts/runtime-skill-canary" --repo "$ROOT_DIR" --home "$HOME_DIR" >"$TMP_DIR/wrong-link.json"; then
  printf 'wrong shared link should fail offline proof\n' >&2
  exit 1
fi
jq -e '.status == "offline_failed" and .link_valid == {"passed":false,"state":"wrong_target","surface":"agents_visible"}' "$TMP_DIR/wrong-link.json" >/dev/null

printf 'runtime skill canary smoke test: ok\n'
