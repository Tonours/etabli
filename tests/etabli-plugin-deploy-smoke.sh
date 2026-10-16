#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DEPLOY_SCRIPT="$ROOT_DIR/scripts/deploy-agent-workflow"
MODS_DIR="$ROOT_DIR/claude/mods"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

command -v node >/dev/null 2>&1 || fail "node not on PATH"
NODE_DIR="$(dirname "$(node -e 'process.stdout.write(process.execPath)')")"

STUB_BIN="$TMP_DIR/bin"
STATE="$TMP_DIR/state"
FAKE_HOME="$TMP_DIR/home"
mkdir -p "$STUB_BIN" "$STATE" "$FAKE_HOME"

cat >"$STUB_BIN/claude" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
state="$STUB_STATE"
printf '%s\n' "$*" >>"$state/calls"
case "$*" in
  "plugin marketplace list --json")
    if [ -f "$state/marketplace" ]; then
      printf '[{"name":"etabli-local","source":"directory","path":"%s"}]' "$(cat "$state/marketplace")"
    else
      printf '[]'
    fi
    ;;
  "plugin list --json")
    [ "${STUB_FAIL_LIST:-0}" != 1 ] || exit 1
    if [ "${STUB_BAD_JSON:-0}" = 1 ]; then printf 'not json'; exit 0; fi
    if [ -f "$state/installed" ]; then
      printf '[{"id":"etabli@etabli-local","readFromFolder":"%s"}]' "$(cat "$state/installed")"
    else
      printf '[]'
    fi
    ;;
  "plugin marketplace remove etabli-local")
    rm -f "$state/marketplace" "$state/installed"
    ;;
  "plugin marketplace add "*" --scope user")
    printf '%s' "$4" >"$state/marketplace"
    ;;
  "plugin install etabli@etabli-local --scope user")
    printf '%s/etabli' "$(cat "$state/marketplace")" >"$state/installed"
    ;;
  *)
    printf 'unexpected claude call: %s\n' "$*" >&2
    exit 2
    ;;
esac
STUB
chmod +x "$STUB_BIN/claude"

run_step() {
  local dry_run="$1"
  shift
  : >"$STATE/calls"
  env -u CLAUDE_CONFIG_DIR -u ETABLI_SKIP_CLAUDE_PLUGIN -u ETABLI_INSTALL_HELPER_SMOKE \
    HOME="$FAKE_HOME" STUB_STATE="$STATE" PATH="$STUB_BIN:$NODE_DIR:/usr/bin:/bin" "$@" \
    bash -c 'script="$1" dry="$2"; set --; . "$script"; DRY_RUN="$dry"; deploy_etabli_plugin' _ "$DEPLOY_SCRIPT" "$dry_run" >"$TMP_DIR/out"
}

expect_line() {
  grep -Eq "^$1 +$2\$" "$TMP_DIR/out" || {
    cat "$TMP_DIR/out" >&2
    fail "missing $1 $2"
  }
}

expect_no_mutation() {
  if grep -Ev '^plugin (marketplace )?list --json$' "$STATE/calls" | grep -q .; then
    cat "$STATE/calls" >&2
    fail "$1"
  fi
}

run_step 1
expect_line WOULD_LINK "marketplace etabli-local -> $MODS_DIR"
expect_line WOULD_INSTALL "plugin etabli@etabli-local from $MODS_DIR/etabli"
expect_no_mutation "dry-run on an empty config called a mutating claude command"
[ ! -f "$STATE/marketplace" ] || fail "dry-run registered the marketplace"

run_step 0
expect_line LINK "marketplace etabli-local -> $MODS_DIR"
expect_line INSTALL "plugin etabli@etabli-local from $MODS_DIR/etabli"
[ "$(cat "$STATE/marketplace")" = "$MODS_DIR" ] || fail "marketplace not registered on the checkout"
[ "$(cat "$STATE/installed")" = "$MODS_DIR/etabli" ] || fail "plugin not installed from the checkout"

run_step 0
expect_line OK "marketplace etabli-local"
expect_line OK "plugin etabli@etabli-local"
expect_no_mutation "second apply was not a no-op"

printf '%s' "$TMP_DIR/old-worktree/claude/mods" >"$STATE/marketplace"
printf '%s' "$TMP_DIR/old-worktree/claude/mods/etabli" >"$STATE/installed"
run_step 1
expect_line WOULD_REMOVE "marketplace etabli-local at $TMP_DIR/old-worktree/claude/mods"
expect_line WOULD_LINK "marketplace etabli-local -> $MODS_DIR"
expect_no_mutation "dry-run on a stale marketplace called a mutating claude command"
run_step 0
grep -qx 'plugin marketplace remove etabli-local' "$STATE/calls" || fail "stale marketplace was not removed"
[ "$(cat "$STATE/installed")" = "$MODS_DIR/etabli" ] || fail "stale marketplace was not re-pointed and reinstalled"

run_step 0 ETABLI_SKIP_CLAUDE_PLUGIN=1
expect_line SKIP "etabli plugin \\(ETABLI_SKIP_CLAUDE_PLUGIN=1\\)"
[ ! -s "$STATE/calls" ] || fail "ETABLI_SKIP_CLAUDE_PLUGIN still called claude"

run_step 0 ETABLI_INSTALL_HELPER_SMOKE=1
expect_line SKIP "etabli plugin for isolated or non-default home"
[ ! -s "$STATE/calls" ] || fail "helper smoke mode still called claude"

mkdir -p "$TMP_DIR/outside-config"
run_step 0 CLAUDE_CONFIG_DIR="$TMP_DIR/outside-config"
expect_line SKIP "etabli plugin: CLAUDE_CONFIG_DIR is outside this home"
[ ! -s "$STATE/calls" ] || fail "an outside CLAUDE_CONFIG_DIR still called claude"

mkdir -p "$FAKE_HOME/.claude-alt"
run_step 0 CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude-alt"
expect_line OK "plugin etabli@etabli-local"

run_step 0 STUB_FAIL_LIST=1
expect_line WARN "etabli plugin: cannot list installed Claude plugins"

run_step 0 STUB_BAD_JSON=1
expect_line WARN "etabli plugin: cannot list installed Claude plugins"
expect_no_mutation "malformed plugin list triggered a mutating claude command"

rm "$STUB_BIN/claude"
run_step 0
expect_line SKIP "etabli plugin: claude CLI or Node.js unavailable"

printf 'etabli-plugin-deploy-smoke: ok\n'
