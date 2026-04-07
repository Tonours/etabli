#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_DIR="$REPO_DIR/pi"
PATCH_DIR="$PI_DIR/patches"
PATCH_BIN="$PI_DIR/node_modules/.bin/patch-package"
WORKSPACE_BASE="$PI_DIR/.patch-apply"

if [ -x "$PATCH_BIN" ]; then
  PATCH_RUNNER=("$PATCH_BIN")
else
  PATCH_RUNNER=(npx --yes patch-package)
fi

if [ ! -d "$PATCH_DIR" ]; then
  echo "No patch directory found at $PATCH_DIR" >&2
  exit 1
fi

apply_patchset() {
  local label="$1"
  local package_root="$2"
  local package_dir="$package_root/mitsupi"
  local workspace="$WORKSPACE_BASE/$label"
  local version

  if [ ! -d "$package_dir" ]; then
    echo "skip $label: $package_dir not found"
    return 0
  fi

  version="$(node -p "require('$package_dir/package.json').version")"

  rm -rf "$workspace"
  mkdir -p "$workspace/node_modules"

  cat > "$workspace/package.json" <<JSON
{
  "name": "pi-package-patch-$label",
  "private": true,
  "version": "1.0.0"
}
JSON

  cat > "$workspace/package-lock.json" <<JSON
{
  "name": "pi-package-patch-$label",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "pi-package-patch-$label",
      "version": "1.0.0"
    },
    "node_modules/mitsupi": {
      "version": "$version"
    }
  }
}
JSON

  ln -s "$package_dir" "$workspace/node_modules/mitsupi"

  echo "apply $label ($package_dir)"
  (
    cd "$workspace"
    "${PATCH_RUNNER[@]}" --patch-dir ../../patches
  )
}

rm -rf "$WORKSPACE_BASE"
mkdir -p "$WORKSPACE_BASE"
trap 'rm -rf "$WORKSPACE_BASE"' EXIT

SEEN_TARGETS=""

apply_target_if_present() {
  local label="$1"
  local package_root="$2"
  local package_dir="$package_root/mitsupi"
  local real_dir
  local marker

  if [ ! -d "$package_dir" ]; then
    echo "skip $label: $package_dir not found"
    return 0
  fi

  real_dir="$(cd "$package_dir" && pwd -P)"
  marker="|$real_dir|"
  if [[ "$SEEN_TARGETS" == *"$marker"* ]]; then
    echo "skip $label: $real_dir already patched"
    return 0
  fi

  SEEN_TARGETS="$SEEN_TARGETS$marker"
  apply_patchset "$label" "$package_root"
}

GLOBAL_NODE_MODULES="$(npm root -g 2>/dev/null || true)"
if [ -n "$GLOBAL_NODE_MODULES" ]; then
  apply_target_if_present global "$GLOBAL_NODE_MODULES"
fi

if [ -d "$HOME/.pi/npm/node_modules" ]; then
  apply_target_if_present pi-local "$HOME/.pi/npm/node_modules"
fi
