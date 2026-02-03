#!/bin/bash
# Use project-local prettier based on the file being edited
# Falls back to npx prettier only if no local version exists

FILE_PATH="$1"

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Find project root by looking for package.json, .prettierrc, or .git
find_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/package.json" ] || [ -f "$dir/.prettierrc" ] || [ -f "$dir/.prettierrc.json" ] || [ -f "$dir/.prettierrc.js" ] || [ -d "$dir/.git" ]; then
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

if [ -n "$PROJECT_ROOT" ]; then
    # Try project-local prettier first
    LOCAL_PRETTIER="$PROJECT_ROOT/node_modules/.bin/prettier"

    if [ -x "$LOCAL_PRETTIER" ]; then
        # Check if file should be ignored by prettier
        cd "$PROJECT_ROOT"
        if "$LOCAL_PRETTIER" --check "$FILE_PATH" --ignore-unknown 2>/dev/null || [ $? -eq 1 ]; then
            "$LOCAL_PRETTIER" --write "$FILE_PATH" --ignore-unknown 2>/dev/null
            exit 0
        fi
    fi

    # Try yarn/pnpm/bun if available in project
    cd "$PROJECT_ROOT"
    if [ -f "yarn.lock" ] && command -v yarn &>/dev/null; then
        yarn prettier --write "$FILE_PATH" --ignore-unknown 2>/dev/null && exit 0
    elif [ -f "pnpm-lock.yaml" ] && command -v pnpm &>/dev/null; then
        pnpm prettier --write "$FILE_PATH" --ignore-unknown 2>/dev/null && exit 0
    elif [ -f "bun.lockb" ] && command -v bun &>/dev/null; then
        bun run prettier --write "$FILE_PATH" --ignore-unknown 2>/dev/null && exit 0
    fi
fi

# Last resort: npx (will use nearest prettier or download)
npx prettier --write "$FILE_PATH" --ignore-unknown 2>/dev/null || true
