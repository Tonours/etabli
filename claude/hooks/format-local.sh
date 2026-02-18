#!/bin/bash
# Use project-local formatter (Biome or Prettier) based on the file being edited
# Prefers Biome if biome.json exists, otherwise falls back to Prettier
# Note: We intentionally do NOT use set -e because formatter failures
# should not block file editing. All errors are silently ignored.

FILE_PATH="$1"

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Find project root by looking for package.json, biome.json, .prettierrc, or .git
find_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/package.json" ] || [ -f "$dir/biome.json" ] || [ -f "$dir/biome.jsonc" ] || [ -f "$dir/.prettierrc" ] || [ -f "$dir/.prettierrc.json" ] || [ -f "$dir/.prettierrc.js" ] || [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Get directory of the file being formatted
FILE_DIR="$(dirname "$FILE_PATH")"

# Find project root
PROJECT_ROOT="$(find_project_root "$FILE_DIR")"

if [ -z "$PROJECT_ROOT" ]; then
    exit 0
fi

# --- Biome: prefer if biome.json exists ---
if [ -f "$PROJECT_ROOT/biome.json" ] || [ -f "$PROJECT_ROOT/biome.jsonc" ]; then
    LOCAL_BIOME="$PROJECT_ROOT/node_modules/.bin/biome"

    if [ -x "$LOCAL_BIOME" ]; then
        "$LOCAL_BIOME" format --write "$FILE_PATH" 2>/dev/null && exit 0
        # Biome failed; fall through to try package manager runners
    fi

    # Try package manager runners
    cd "$PROJECT_ROOT" || exit 0
    if [ -f "yarn.lock" ] && command -v yarn &>/dev/null; then
        yarn biome format --write "$FILE_PATH" 2>/dev/null && exit 0
    elif [ -f "pnpm-lock.yaml" ] && command -v pnpm &>/dev/null; then
        pnpm biome format --write "$FILE_PATH" 2>/dev/null && exit 0
    elif [ -f "bun.lockb" ] && command -v bun &>/dev/null; then
        bun run biome format --write "$FILE_PATH" 2>/dev/null && exit 0
    fi

    # Fallback: npx biome
    npx @biomejs/biome format --write "$FILE_PATH" 2>/dev/null && exit 0
fi

# --- Prettier: fallback when no biome config ---
LOCAL_PRETTIER="$PROJECT_ROOT/node_modules/.bin/prettier"

if [ -x "$LOCAL_PRETTIER" ]; then
    cd "$PROJECT_ROOT" || exit 0
    "$LOCAL_PRETTIER" --check "$FILE_PATH" --ignore-unknown 2>/dev/null
    check_status=$?
    if [ "$check_status" -eq 0 ] || [ "$check_status" -eq 1 ]; then
        "$LOCAL_PRETTIER" --write "$FILE_PATH" --ignore-unknown 2>/dev/null
        exit 0
    fi
fi

# Try yarn/pnpm/bun for prettier
cd "$PROJECT_ROOT" || exit 0
if [ -f "yarn.lock" ] && command -v yarn &>/dev/null; then
    yarn prettier --write "$FILE_PATH" --ignore-unknown 2>/dev/null && exit 0
elif [ -f "pnpm-lock.yaml" ] && command -v pnpm &>/dev/null; then
    pnpm prettier --write "$FILE_PATH" --ignore-unknown 2>/dev/null && exit 0
elif [ -f "bun.lockb" ] && command -v bun &>/dev/null; then
    bun run prettier --write "$FILE_PATH" --ignore-unknown 2>/dev/null && exit 0
fi

# Last resort: npx prettier
npx prettier --write "$FILE_PATH" --ignore-unknown 2>/dev/null || true
