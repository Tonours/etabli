#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
PATH_HELPER="$ROOT_DIR/scripts/lib/pi-paths.sh"

. "$PATH_HELPER"

if [ "$(pi_agent_npm_dir /tmp/example-home)" != "/tmp/example-home/.pi/agent/npm" ]; then
  printf 'unexpected Pi agent npm path\n' >&2
  exit 1
fi

if [ "$(pi_agent_node_modules_dir /tmp/example-home/)" != "/tmp/example-home/.pi/agent/npm/node_modules" ]; then
  printf 'unexpected Pi agent node_modules path\n' >&2
  exit 1
fi

if pi_agent_npm_dir "" >/dev/null 2>&1; then
  printf 'empty home directory must be rejected\n' >&2
  exit 1
fi

managed_scripts=(
  "$ROOT_DIR/scripts/lib/install-main.sh"
  "$ROOT_DIR/scripts/deploy-agent-workflow"
  "$ROOT_DIR/scripts/check-fix-symlinks.sh"
)

for managed_script in "${managed_scripts[@]}"; do
  grep -Fq 'pi-paths.sh' "$managed_script" || {
    printf 'missing shared Pi path helper in %s\n' "$managed_script" >&2
    exit 1
  }
done

if rg -n '\.pi/agent/npm' "${managed_scripts[@]}"; then
  printf 'managed scripts must not duplicate the Pi npm path\n' >&2
  exit 1
fi

printf 'Pi path smoke test: ok\n'
