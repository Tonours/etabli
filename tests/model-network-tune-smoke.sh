#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/model-network-tune"
REAL_HOME="${HOME}"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

if [ ! -x "$SCRIPT" ]; then
  chmod +x "$SCRIPT"
fi

# Offline help/usage
out="$("$SCRIPT" help 2>&1 || true)"
printf '%s\n' "$out" | grep -Fq 'model-network-tune' || {
  printf 'help missing brand\n' >&2
  exit 1
}

# Apply against isolated HOME shell rc files (do not break asdf/node HOME).
export HOME="$TMP_HOME"
mkdir -p "$HOME"
touch "$HOME/.zshrc" "$HOME/.bashrc"
# Clear inherited options so apply is deterministic in the smoke.
unset NODE_OPTIONS || true

"$SCRIPT" apply >/dev/null

grep -Fq -- '--dns-result-order=ipv4first' "$HOME/.zshrc" || {
  printf 'zshrc missing ipv4first export\n' >&2
  exit 1
}
grep -Fq -- '--dns-result-order=ipv4first' "$HOME/.bashrc" || {
  printf 'bashrc missing ipv4first export\n' >&2
  exit 1
}

# Idempotent second apply
"$SCRIPT" apply >/dev/null
count="$(grep -c -- '--dns-result-order=ipv4first' "$HOME/.zshrc" || true)"
if [ "$count" -ne 1 ]; then
  printf 'zshrc not idempotent for ipv4first (count=%s)\n' "$count" >&2
  exit 1
fi

# status must run without crashing after apply
"$SCRIPT" status >/dev/null

# Source the line and confirm flag presence
# shellcheck disable=SC1091
source "$HOME/.zshrc"
case " ${NODE_OPTIONS:-} " in
  *" --dns-result-order=ipv4first "*) ;;
  *)
    printf 'sourced zshrc did not export NODE_OPTIONS flag\n' >&2
    exit 1
    ;;
esac

# Restore real HOME so asdf/node keep working; keep NODE_OPTIONS from sourced rc.
export HOME="$REAL_HOME"

# Node order when flag is set via NODE_OPTIONS (do not also pass the CLI flag —
# Node rejects the duplicate option and prints nothing).
if command -v node >/dev/null 2>&1; then
  order="$(node -e 'console.log(require("dns").getDefaultResultOrder())')"
  if [ "$order" != "ipv4first" ]; then
    printf 'expected node order ipv4first, got %s\n' "$order" >&2
    exit 1
  fi
fi

printf 'model-network-tune smoke test: ok\n'
